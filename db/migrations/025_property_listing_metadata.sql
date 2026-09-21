ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS category_code text NOT NULL DEFAULT 'villa' REFERENCES onboarding.categories(code);
ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS seo_title text NOT NULL DEFAULT '' CHECK(length(seo_title)<=160);
ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS seo_description text NOT NULL DEFAULT '' CHECK(length(seo_description)<=320);
ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS amenities jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS media jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE catalog.properties ADD COLUMN IF NOT EXISTS ai_drafts jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE INDEX IF NOT EXISTS properties_category_status ON catalog.properties(tenant_id,category_code,status,created_at DESC);
