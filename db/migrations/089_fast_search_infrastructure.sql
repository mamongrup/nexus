-- 089_fast_search_infrastructure.sql
-- Fast search infrastructure for marketplace listings

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS properties_title_trgm_idx
  ON catalog.properties USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS properties_locality_trgm_idx
  ON catalog.properties USING gin (locality gin_trgm_ops);
