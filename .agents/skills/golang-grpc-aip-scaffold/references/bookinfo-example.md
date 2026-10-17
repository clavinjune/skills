# bookinfo: full worked example

Real code from `github.com/clavinjune/golang-scaffold`'s `book` domain (nested under `author`) —
use as ground truth if a template placeholder is ambiguous. Book is nested (`authors/{author}/
books/{book}`), so it also demonstrates the AIP-159 wildcard-parent and parent-name-reuse
patterns; Author is the top-level domain these both build on.

CLI excerpts below are adapted to this skill's `<binary>ctl` naming, resource aliases,
and get/create/edit/delete/explain conventions. The upstream example is the architectural
reference; `templates/cli/` supplies the current command constructors and shared helpers.
For bookinfo, use `authors`/`author`/`au` and `books`/`book`/`bo`. All three spellings work
under every verb; `get books` lists and `get books <full-resource-name>` gets one.

## pkg/author.go (name helpers + interfaces, real code)
```go
package pkg

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	bookinfov1 "github.com/clavinjune/golang-scaffold/pkg/bookinfo/v1"
	"github.com/clavinjune/golang-scaffold/pkg/sqlc"
)

const authorNamePrefix = "authors/"

// WildcardCollectionID is the AIP-159 wildcard collection id ("-"),
// usable as a parent id segment to mean "any parent" — e.g.
// "authors/-/books" lists Book across every Author instead of one.
const WildcardCollectionID = "-"

// FormatAuthorName builds the AIP resource name from a bare id:
// "authors/{author}". Also used to format a Book's parent resource name,
// since an Author name IS a Book's parent name.
func FormatAuthorName(id string) string {
	return authorNamePrefix + id
}

// ParseAuthorName extracts the bare id from "authors/{author}". Also used
// to parse a Book's parent resource name (same "authors/{author}" shape).
func ParseAuthorName(name string) (string, error) {
	id, ok := strings.CutPrefix(name, authorNamePrefix)
	if !ok || id == "" || strings.Contains(id, "/") {
		return "", fmt.Errorf("%w: invalid author name %q, expected format %q", ErrInvalidArgument, name, authorNamePrefix+"{author}")
	}
	return id, nil
}

type AuthorHandler interface {
	Register(mux *http.ServeMux)
}

// AuthorService implements the AIP standard verbs, server-side business
// logic (validation, sqlc<->proto mapping). Note the *Request proto types
// as parameters, not hand-rolled params — same shape used by AuthorClient
// below, mirroring gRPC's Server/Client interface split (same RPC names,
// same request/response types, different implementer).
type AuthorService interface {
	CreateAuthor(ctx context.Context, req *bookinfov1.CreateAuthorRequest) (*bookinfov1.Author, error)
	GetAuthor(ctx context.Context, req *bookinfov1.GetAuthorRequest) (*bookinfov1.Author, error)
	ListAuthors(ctx context.Context, req *bookinfov1.ListAuthorsRequest) (*bookinfov1.ListAuthorsResponse, error)
	UpdateAuthor(ctx context.Context, req *bookinfov1.UpdateAuthorRequest) (*bookinfov1.Author, error)
}

// AuthorClient is the network-calling counterpart to AuthorService — same
// method names/proto request-response shapes, implemented by pkg/client
// over HTTP instead of by server business logic. CLI commands depend on
// this interface, never on a concrete HTTP client — see the CLI section
// below.
type AuthorClient interface {
	CreateAuthor(ctx context.Context, req *bookinfov1.CreateAuthorRequest) (*bookinfov1.Author, error)
	GetAuthor(ctx context.Context, req *bookinfov1.GetAuthorRequest) (*bookinfov1.Author, error)
	ListAuthors(ctx context.Context, req *bookinfov1.ListAuthorsRequest) (*bookinfov1.ListAuthorsResponse, error)
	UpdateAuthor(ctx context.Context, req *bookinfov1.UpdateAuthorRequest) (*bookinfov1.Author, error)
}

type AuthorRepository interface {
	CreateAuthor(ctx context.Context, author *sqlc.Author) (*sqlc.Author, error)
	GetAuthor(ctx context.Context, id string) (*sqlc.Author, error)
	ListAuthors(ctx context.Context, pageSize int32, lastID string) ([]sqlc.Author, error)
	UpdateAuthor(ctx context.Context, author *sqlc.Author) (*sqlc.Author, error)
}

var MutableAuthorPaths = map[string]bool{
	"display_name": true,
}
```

## internal/author/service.go (real code — newID/toProto pattern)
```go
package author

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/clavinjune/golang-scaffold/internal/pagination"
	"github.com/clavinjune/golang-scaffold/pkg"
	bookinfov1 "github.com/clavinjune/golang-scaffold/pkg/bookinfo/v1"
	"github.com/clavinjune/golang-scaffold/pkg/sqlc"
)

var _ pkg.AuthorService = (*service)(nil)

type service struct {
	repository pkg.AuthorRepository
}

func (s *service) CreateAuthor(ctx context.Context, req *bookinfov1.CreateAuthorRequest) (*bookinfov1.Author, error) {
	item := req.GetAuthor()
	if item.GetDisplayName() == "" {
		return nil, fmt.Errorf("%w: display_name is required", pkg.ErrInvalidArgument)
	}
	row, err := s.repository.CreateAuthor(ctx, &sqlc.Author{
		ID:          newID(),
		DisplayName: item.GetDisplayName(),
	})
	if err != nil {
		return nil, err
	}
	return toProto(row), nil
}

// newID generates a UUIDv7 resource id. UUIDv7 embeds a millisecond
// timestamp in its leading bits, so plain string/byte ordering is also
// chronological — this is what makes `ORDER BY id` (keyset pagination)
// double as creation-order. Falls back to a random UUIDv4 only if the
// platform's crypto/rand read fails.
func newID() string {
	id, err := uuid.NewV7()
	if err != nil {
		return uuid.NewString()
	}
	return id.String()
}

// toProto maps an sqlc.Author to its proto representation.
func toProto(row *sqlc.Author) *bookinfov1.Author {
	return &bookinfov1.Author{
		Name:        pkg.FormatAuthorName(row.ID),
		DisplayName: row.DisplayName,
		CreateTime:  pkg.ParseTimestamp(row.CreatedAt),
		UpdateTime:  pkg.ParseTimestamp(row.UpdatedAt),
	}
}
```

## internal/book/repository.go (AIP-159 wildcard branch, real code)
```go
// ListBooks branches on the AIP-159 wildcard collection id: authorID == "-"
// means "any author" and queries across all books, otherwise it scopes to
// one author's books. Both paths are keyset-paginated on id.
func (r *repository) ListBooks(ctx context.Context, authorID string, pageSize int32, lastID string) ([]sqlc.Book, error) {
	limit := int64(pageSize)
	if limit <= 0 {
		limit = pkg.DefaultPageSize
	}
	if authorID == pkg.WildcardCollectionID {
		rows, err := r.queries.ListAllBooks(ctx, sqlc.ListAllBooksParams{ID: lastID, Limit: limit})
		if err != nil {
			return nil, err
		}
		return rows, nil
	}
	rows, err := r.queries.ListBooks(ctx, sqlc.ListBooksParams{AuthorID: authorID, ID: lastID, Limit: limit})
	if err != nil {
		return nil, err
	}
	return rows, nil
}
```

## blueprint/proto/bookinfo/v1/book.proto (nested resource, AIP-142 timestamps, real code)
```proto
syntax = "proto3";

// Book is nested under Author: authors/{author}/books/{book}.
//
// NOTE: this proto defines message types (the contract) only. There is no
// gRPC service — the transport is plain net/http; see internal/book/handler.go.
package bookinfo.v1;

import "google/api/field_behavior.proto";
import "google/api/resource.proto";
import "google/protobuf/field_mask.proto";
import "google/protobuf/timestamp.proto";

option go_package = "github.com/clavinjune/golang-scaffold/pkg/bookinfo/v1;bookinfov1";

message Book {
  option (google.api.resource) = {
    type: "bookinfo.clavinjune.dev/Book"
    pattern: "authors/{author}/books/{book}"
    singular: "book"
    plural: "books"
  };

  // Format: authors/{author}/books/{book}
  string name = 1 [(google.api.field_behavior) = IDENTIFIER];

  // The book title.
  string display_name = 2 [(google.api.field_behavior) = REQUIRED];

  string isbn = 3 [(google.api.field_behavior) = OPTIONAL];

  int32 year_published = 4 [(google.api.field_behavior) = OPTIONAL];

  // AIP-142.
  google.protobuf.Timestamp create_time = 5 [(google.api.field_behavior) = OUTPUT_ONLY];
  google.protobuf.Timestamp update_time = 6 [(google.api.field_behavior) = OUTPUT_ONLY];
}

// AIP-133
message CreateBookRequest {
  // The parent author, format: authors/{author}
  string parent = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference).child_type = "bookinfo.clavinjune.dev/Book"
  ];
  Book book = 2 [(google.api.field_behavior) = REQUIRED];
}

// AIP-131
message GetBookRequest {
  string name = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference).type = "bookinfo.clavinjune.dev/Book"
  ];
}

// AIP-132
message ListBooksRequest {
  // The parent author, format: authors/{author}, or "authors/-" (AIP-159
  // wildcard) to list across every author.
  string parent = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference).child_type = "bookinfo.clavinjune.dev/Book"
  ];
  int32 page_size = 2;
  string page_token = 3;
}

message ListBooksResponse {
  repeated Book books = 1;
  string next_page_token = 2;
}

// AIP-134
message UpdateBookRequest {
  Book book = 1 [(google.api.field_behavior) = REQUIRED];
  google.protobuf.FieldMask update_mask = 2 [(google.api.field_behavior) = OPTIONAL];
}
```

## sqlc.yaml
```yaml
version: "2"
sql:
  - engine: "sqlite"
    schema: "blueprint/sqlc/schema.sql"
    queries: "blueprint/sqlc/query.sql"
    gen:
      go:
        package: "sqlc"
        out: "pkg/sqlc"
        emit_json_tags: true
        emit_interface: true
        emit_empty_slices: true
```

## buf.gen.yaml
```yaml
version: v2
managed:
  enabled: true
plugins:
  - remote: buf.build/protocolbuffers/go
    out: pkg
    opt: paths=source_relative
```

## CLI: cmd/bookinfoctl/cmd/root.go (adapted example — lazy-client wiring)
```go
// Package cmd is the top-level bookinfoctl command tree: the shared
// output-format flag, get/create/edit/delete/explain commands, and wire-based
// assembly of each domain's subcommands (cmd/bookinfoctl/cmd/author,
// cmd/bookinfoctl/cmd/book) against a single shared pkg/client.Client.
package cmd

import (
	"context"
	"net/http"

	"github.com/spf13/cobra"

	"github.com/clavinjune/golang-scaffold/internal/cliutil"
	"github.com/clavinjune/golang-scaffold/pkg/client"
)

// NewRootCmd builds the full command tree. httpClient is nil in
// production (defaults to http.DefaultClient inside pkg/client); tests
// inject an httptest.Server's client.
//
// Subcommands must exist in the tree before cobra parses args (it routes
// "get book ..." by walking already-added children), but --addr isn't
// known until flags are parsed. So the shared client is built once,
// eagerly, with a mutable BaseURL that PersistentPreRunE fills in from
// the parsed --addr flag before any subcommand's RunE fires.
func NewRootCmd(httpClient *http.Client) *cobra.Command {
	var (
		addr   string
		output string
	)
	root := &cobra.Command{
		Use:   "bookinfoctl",
		Short: "kubectl-style CLI for bookinfo-server",
	}
	root.PersistentFlags().StringVar(&addr, "addr", "http://localhost:8080", "bookinfo-server base URL")
	root.PersistentFlags().StringVarP(&output, "output", "o", "table", "output format: table|wide|json|yaml|name")

	format := func() cliutil.OutputFormat { return cliutil.OutputFormat(output) }

	getCmd := &cobra.Command{Use: "get", Short: "Get or list a resource"}
	createCmd := &cobra.Command{Use: "create", Short: "Create a resource"}
	editCmd := &cobra.Command{Use: "edit", Short: "Edit a resource in YAML using your editor"}
	deleteCmd := &cobra.Command{Use: "delete", Short: "Delete a resource by name"}

	client := newLazyClient(httpClient)
	editor := cliutil.Editor(func(ctx context.Context, data []byte) ([]byte, error) {
		return cliutil.OpenEditor(ctx, data, root.InOrStdin(), root.OutOrStdout(), root.ErrOrStderr())
	})
	dep := Wire(client, format, editor)
	dep.Author.Register(getCmd, createCmd, editCmd, deleteCmd)
	dep.Book.Register(getCmd, createCmd, editCmd, deleteCmd)
	resources := []cliutil.Resource{dep.Author.Resource, dep.Book.Resource}
	root.AddCommand(getCmd, createCmd, editCmd, deleteCmd, cliutil.NewExplainCmd(resources...))

	root.PersistentPreRunE = func(cmd *cobra.Command, _ []string) error {
		client.BaseURL = addr
		return cliutil.ValidateResources(resources)
	}
	return root
}

func newLazyClient(httpClient *http.Client) *client.Client {
	return client.New(httpClient, "")
}
```

## CLI: cmd/bookinfoctl/cmd/provider.go (real code — top-level CLI wire aggregation)
```go
package cmd

import (
	"github.com/google/wire"

	"github.com/clavinjune/golang-scaffold/cmd/bookinfoctl/cmd/author"
	"github.com/clavinjune/golang-scaffold/cmd/bookinfoctl/cmd/book"
	"github.com/clavinjune/golang-scaffold/pkg"
	"github.com/clavinjune/golang-scaffold/pkg/client"
)

// Dependency aggregates every domain's built Commands — add one field +
// one ProviderSet entry per new domain (see the skill's domain-creation
// checklist, step 10).
type Dependency struct {
	Author *author.Commands
	Book   *book.Commands
}

var ProviderSet = wire.NewSet(
	ProvideDependency,
	author.ProviderSet,
	book.ProviderSet,
	provideAuthorClient,
	provideBookClient,
)

// provideAuthorClient/provideBookClient bind the shared *client.Client to
// each domain's <Domain>Client interface. wire.Bind alone can't resolve a
// pass-through injector argument's concrete type to an interface, so
// these small identity functions stand in as the providers wire.Bind
// normally generates.
func provideAuthorClient(c *client.Client) pkg.AuthorClient { return c }
func provideBookClient(c *client.Client) pkg.BookClient     { return c }

func ProvideDependency(authorCommands *author.Commands, bookCommands *book.Commands) *Dependency {
	return &Dependency{Author: authorCommands, Book: bookCommands}
}
```

## CLI: cmd/bookinfoctl/cmd/author/commands.go (adapted example — RunE takes the interface, testable)
```go
// newGetCmd handles both "get author" (list all) and "get author <name>"
// (get one), kubectl-style. c is pkg.AuthorClient, the INTERFACE — never
// a concrete *client.Client — which is exactly what lets a test hand in
// a fakeClient and call cmd.Execute() with no server, no HTTP, no wire.
func newGetCmd(c pkg.AuthorClient, format func() cliutil.OutputFormat) *cobra.Command {
	return &cobra.Command{
		Use:   resource.Plural + " [name]", // authors
		Aliases: resource.CommandAliases(), // singular author + short alias au
		Short: "Get an author by resource name, or list all authors if name is omitted",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()
			if len(args) == 1 {
				resp, err := c.GetAuthor(ctx, &bookinfov1.GetAuthorRequest{Name: args[0]})
				if err != nil {
					return err
				}
				return cliutil.PrintResult(cmd.OutOrStdout(), format(), resp, table{resp}, table{resp})
			}
			authors, err := listAll(ctx, c)
			if err != nil {
				return err
			}
			resp := &bookinfov1.ListAuthorsResponse{Authors: authors}
			return cliutil.PrintResult(cmd.OutOrStdout(), format(), resp, listTable{authors}, listTable{authors})
		},
	}
}
```

## CLI: cmd/bookinfoctl/cmd/author/commands_test.go (adapted example — RunE unit test, no server)
```go
// package author_test — external test package convention, driving
// through the exported author.ProvideCommands(...) entry point, never the
// unexported newGetCmd directly.
package author_test

import (
	"bytes"
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/clavinjune/golang-scaffold/cmd/bookinfoctl/cmd/author"
	"github.com/clavinjune/golang-scaffold/internal/cliutil"
	bookinfov1 "github.com/clavinjune/golang-scaffold/pkg/bookinfo/v1"
)

func tableFormat() cliutil.OutputFormat { return cliutil.OutputTable }

// fakeClient is a real, deterministic in-memory pkg.AuthorClient — no
// mocking framework, matching the project's "no mocks" testing
// convention. Each field is a plain closure a test wires up per case.
type fakeClient struct {
	getFn func(context.Context, *bookinfov1.GetAuthorRequest) (*bookinfov1.Author, error)
	// createFn/listFn/updateFn/deleteFn omitted here for brevity — see
	// templates/cli/domain_commands_test.go.tmpl for the complete fake.
}

func (f *fakeClient) GetAuthor(ctx context.Context, req *bookinfov1.GetAuthorRequest) (*bookinfov1.Author, error) {
	return f.getFn(ctx, req)
}

func TestGetCmd_ByName(t *testing.T) {
	t.Parallel()
	c := &fakeClient{
		getFn: func(_ context.Context, req *bookinfov1.GetAuthorRequest) (*bookinfov1.Author, error) {
			require.Equal(t, "authors/1", req.GetName())
			return &bookinfov1.Author{Name: "authors/1", DisplayName: "Jane"}, nil
		},
	}
	editor := func(_ context.Context, data []byte) ([]byte, error) { return data, nil }
	cmds := author.ProvideCommands(c, tableFormat, editor)
	out := &bytes.Buffer{}
	cmds.Get.SetOut(out)
	cmds.Get.SetArgs([]string{"authors/1"})
	require.NoError(t, cmds.Get.Execute())
	require.Contains(t, out.String(), "Jane")
}
```
