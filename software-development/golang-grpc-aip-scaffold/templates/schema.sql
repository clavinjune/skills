-- Hand-maintained schema, no migration tool (per mulyani ADR-0001).
-- Edit in place; there is no migration history — the schema file itself
-- is the single source of truth for the current shape of the database.

CREATE TABLE IF NOT EXISTS <domains> (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL
);
