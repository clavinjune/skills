-- name: Create<Domain> :one
INSERT INTO <domains> (id, display_name)
VALUES (?, ?)
RETURNING *;

-- name: Get<Domain> :one
SELECT * FROM <domains> WHERE id = ?;

-- name: List<Plural> :many
SELECT * FROM <domains> LIMIT ?;

-- name: Update<Domain> :one
UPDATE <domains> SET display_name = ? WHERE id = ?
RETURNING *;

-- name: Delete<Domain> :execrows
DELETE FROM <domains> WHERE id = ?;
