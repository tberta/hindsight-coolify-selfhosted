-- Runs once, the first time the postgres data volume is initialized.
-- Hindsight needs a vector extension for similarity search; pg_trgm backs the
-- default trigram entity lookup. Migrations are idempotent, so re-enabling here
-- is safe and guarantees the extensions exist before the API connects.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
