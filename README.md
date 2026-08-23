# skills

A collection of general-purpose agent skills — reusable procedural knowledge (`SKILL.md` +
supporting templates/references) for recurring task types. Laid out under `.agents/skills/`, the
emerging convention some agent runtimes scan automatically. Framework-agnostic: each skill is a
plain `SKILL.md` with YAML frontmatter (`name`, `description`) plus optional
`templates/`/`references/` subdirectories — works with Claude Code, OpenCode, Hermes Agent, or a
custom harness.

## Skills

| Skill | Description |
|---|---|
| [`golang-grpc-aip-scaffold`](.agents/skills/golang-grpc-aip-scaffold) | Scaffold a Go backend service using gRPC/AIP resource conventions, sqlc, and `google/wire` compile-time DI — including a full Cobra CLI client with an HTTP client abstraction, per-domain wiring, and testable command logic. |
| [`grilling`](.agents/skills/grilling) | Interview the user relentlessly about a plan/decision/idea until reaching a shared understanding, then optionally document the outcome as an ADR. Adapted from [mattpocock/skills](https://github.com/mattpocock/skills). |
| [`meta-cognitive-reasoner`](.agents/skills/meta-cognitive-reasoner) | A structured 5-step reasoning framework (decompose → solve with confidence → verify → synthesize → reflect) for complex, multi-step, or ambiguous problems. |

## Usage

Some agent runtimes will discover skills automatically if you drop this repo's `.agents/skills/`
into your project root (or symlink it). Otherwise, copy an individual skill directory into your
agent's own skills path, e.g.:

```
~/.claude/skills/<skill-name>/            # Claude Code
<project>/.opencode/skills/<skill-name>/  # OpenCode (project-local)
~/.hermes/skills/<category>/<skill-name>/ # Hermes Agent
```

See each skill's `SKILL.md` frontmatter (`name`, `description`) — the description's trigger
condition determines when an agent should load it.

## Contributing

Skills here are intentionally scrubbed of anything project- or person-specific: no real
credentials, hostnames, personal file paths, or private repository references. If you fork/adapt
one of these for your own environment, keep the same discipline — a skill is meant to be shared.

## License

MIT
