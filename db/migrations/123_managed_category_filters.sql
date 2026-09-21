-- Admin-managed category filters and sub-type presentation for NEXUS.
-- Contract fields validate listings; this layer controls storefront/admin
-- filter grouping, labels and translatable display options.

CREATE TABLE IF NOT EXISTS onboarding.category_filter_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_code text NOT NULL REFERENCES onboarding.categories(code),
  group_key text NOT NULL CHECK (group_key ~ '^[a-z][a-z0-9_]{1,60}$'),
  source_locale text NOT NULL DEFAULT 'tr' REFERENCES core.locales(code),
  title text NOT NULL,
  help_text text NOT NULL DEFAULT '',
  display_type text NOT NULL DEFAULT 'checkbox'
    CHECK (display_type IN ('checkbox','radio','select','chips','range','boolean')),
  multiple boolean NOT NULL DEFAULT true,
  active boolean NOT NULL DEFAULT true,
  position int NOT NULL DEFAULT 10,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(category_code, group_key)
);

CREATE TABLE IF NOT EXISTS onboarding.category_filter_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES onboarding.category_filter_groups(id) ON DELETE CASCADE,
  item_key text NOT NULL CHECK (item_key ~ '^[a-z][a-z0-9_]{1,80}$'),
  source_locale text NOT NULL DEFAULT 'tr' REFERENCES core.locales(code),
  title text NOT NULL,
  help_text text NOT NULL DEFAULT '',
  contract_field_code text NOT NULL DEFAULT '',
  contract_value text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  position int NOT NULL DEFAULT 10,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, item_key)
);

CREATE TABLE IF NOT EXISTS onboarding.category_filter_translations (
  entity_type text NOT NULL CHECK (entity_type IN ('group','item')),
  entity_id uuid NOT NULL,
  locale text NOT NULL REFERENCES core.locales(code),
  title text NOT NULL DEFAULT '',
  help_text text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','translated','approved','published','failed')),
  provider text NOT NULL DEFAULT 'ai_pending',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(entity_type, entity_id, locale)
);

CREATE INDEX IF NOT EXISTS onboarding_category_filter_groups_lookup_idx
  ON onboarding.category_filter_groups(category_code, active, position);
CREATE INDEX IF NOT EXISTS onboarding_category_filter_items_lookup_idx
  ON onboarding.category_filter_items(group_id, active, position);

CREATE OR REPLACE FUNCTION onboarding.queue_category_filter_translations(p_entity_type text, p_entity_id uuid, p_source_locale text DEFAULT 'tr')
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE lang record;
BEGIN
  IF p_entity_type NOT IN ('group','item') THEN
    RETURN 'invalid_entity_type';
  END IF;

  FOR lang IN
    SELECT code FROM core.locales WHERE code <> coalesce(p_source_locale,'tr')
  LOOP
    INSERT INTO onboarding.category_filter_translations(entity_type, entity_id, locale, status)
    VALUES(p_entity_type, p_entity_id, lang.code, 'queued')
    ON CONFLICT(entity_type, entity_id, locale)
    DO UPDATE SET status='queued', provider='ai_pending', updated_at=now()
    WHERE onboarding.category_filter_translations.status IN ('failed','queued');
  END LOOP;

  RETURN 'queued';
END $$;

CREATE OR REPLACE FUNCTION onboarding.category_filter_groups_for(p_category text, p_locale text DEFAULT 'tr')
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    g.id::text,
    g.category_code,
    g.group_key,
    coalesce(nullif(t.title,''), g.title),
    coalesce(nullif(t.help_text,''), g.help_text),
    g.display_type,
    g.multiple::text,
    g.active::text,
    g.position::text
  ]
  FROM onboarding.category_filter_groups g
  LEFT JOIN onboarding.category_filter_translations t
    ON t.entity_type='group' AND t.entity_id=g.id AND t.locale=coalesce(p_locale,'tr')
       AND t.status IN ('translated','approved','published')
  WHERE g.category_code=p_category AND g.active
  ORDER BY g.position, g.title;
$$;

CREATE OR REPLACE FUNCTION onboarding.category_filter_items_for(p_group uuid, p_locale text DEFAULT 'tr')
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    i.id::text,
    i.item_key,
    coalesce(nullif(t.title,''), i.title),
    coalesce(nullif(t.help_text,''), i.help_text),
    i.contract_field_code,
    i.contract_value,
    i.active::text,
    i.position::text
  ]
  FROM onboarding.category_filter_items i
  LEFT JOIN onboarding.category_filter_translations t
    ON t.entity_type='item' AND t.entity_id=i.id AND t.locale=coalesce(p_locale,'tr')
       AND t.status IN ('translated','approved','published')
  WHERE i.group_id=p_group AND i.active
  ORDER BY i.position, i.title;
$$;

GRANT SELECT,INSERT,UPDATE,DELETE ON onboarding.category_filter_groups,onboarding.category_filter_items,onboarding.category_filter_translations TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.queue_category_filter_translations(text,uuid,text),onboarding.category_filter_groups_for(text,text),onboarding.category_filter_items_for(uuid,text) TO nexus_app;

WITH groups AS (
  INSERT INTO onboarding.category_filter_groups(category_code, group_key, title, help_text, display_type, multiple, position)
  VALUES
    ('holiday_home','property_type','Tatil evi tipi','Villa, apart, bungalov, daire ve residence tiplerini yönetin.','chips',true,10),
    ('yacht','yacht_type','Yat / tekne tipi','Gulet, motoryat, yelkenli, katamaran ve tekne tiplerini yönetin.','chips',true,10)
  ON CONFLICT(category_code, group_key) DO UPDATE
  SET title=excluded.title, help_text=excluded.help_text, display_type=excluded.display_type, multiple=excluded.multiple, updated_at=now()
  RETURNING id
)
SELECT onboarding.queue_category_filter_translations('group', id, 'tr') FROM groups;

WITH target_groups AS (
  SELECT id, category_code, group_key
  FROM onboarding.category_filter_groups
  WHERE (category_code='holiday_home' AND group_key='property_type')
     OR (category_code='yacht' AND group_key='yacht_type')
), seed_items(group_id, item_key, title, contract_field_code, contract_value, position) AS (
  SELECT g.id, v.item_key, v.title, 'property_type', v.title, v.position
  FROM target_groups g
  CROSS JOIN (VALUES
    ('villa','Villa',10),
    ('apart','Apart',20),
    ('bungalov','Bungalov',30),
    ('daire','Daire',40),
    ('residence','Residence',50)
  ) v(item_key,title,position)
  WHERE g.category_code='holiday_home'
  UNION ALL
  SELECT g.id, v.item_key, v.title, 'yacht_type', v.title, v.position
  FROM target_groups g
  CROSS JOIN (VALUES
    ('gulet','Gulet',10),
    ('motoryat','Motoryat',20),
    ('yelkenli','Yelkenli',30),
    ('katamaran','Katamaran',40),
    ('tekne','Tekne',50)
  ) v(item_key,title,position)
  WHERE g.category_code='yacht'
), inserted AS (
  INSERT INTO onboarding.category_filter_items(group_id, item_key, title, contract_field_code, contract_value, position)
  SELECT group_id, item_key, title, contract_field_code, contract_value, position
  FROM seed_items
  ON CONFLICT(group_id, item_key) DO UPDATE
  SET title=excluded.title,
      contract_field_code=excluded.contract_field_code,
      contract_value=excluded.contract_value,
      position=excluded.position,
      updated_at=now()
  RETURNING id
)
SELECT onboarding.queue_category_filter_translations('item', id, 'tr') FROM inserted;
