-- name: Create<Domain> :one
INSERT INTO <domains> (id, display_name)
VALUES (?, ?)
RETURNING *;

-- name: Get<Domain> :one
SELECT * FROM <domains> WHERE id = ?;

-- name: List<Domain>s :many
SELECT * FROM <domains> LIMIT ?;

-- name: Update<Domain> :one
UPDATE <domains> SET display_name = ? WHERE id = ?
RETURNING *;
