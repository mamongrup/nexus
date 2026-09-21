-- 088 · AI Pricing Research & Competitor Analysis Engine
-- ──────────────────────────────────────────────────────
-- İlan bazında emsal fiyat araştırması, karşılaştırma ve AI öneri motoru.

-- ─── 1. Fiyat Analiz Sonuçları Tablosu ──────────────────
CREATE TABLE IF NOT EXISTS catalog.pricing_analyses (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  listing_id    uuid        NOT NULL,
  tenant_id     uuid        NOT NULL,
  -- Hedef ilan bilgileri
  target_category   text    NOT NULL DEFAULT '',
  target_locality   text    NOT NULL DEFAULT '',
  target_capacity   int     NOT NULL DEFAULT 0,
  target_price      int     NOT NULL DEFAULT 0,
  target_currency   text    NOT NULL DEFAULT 'TRY',
  -- Emsal analiz sonuçları
  comparable_count  int     NOT NULL DEFAULT 0,
  avg_price         int     NOT NULL DEFAULT 0,
  min_price         int     NOT NULL DEFAULT 0,
  max_price         int     NOT NULL DEFAULT 0,
  median_price      int     NOT NULL DEFAULT 0,
  -- AI önerisi
  recommended_min   int     NOT NULL DEFAULT 0,
  recommended_max   int     NOT NULL DEFAULT 0,
  optimal_price     int     NOT NULL DEFAULT 0,
  confidence_pct    int     NOT NULL DEFAULT 0,   -- 0-100
  verdict           text    NOT NULL DEFAULT '',   -- underpriced / overpriced / competitive / optimal
  reasoning         text    NOT NULL DEFAULT '',
  -- Emsal ilanların JSON snapshot'ı
  comparables_json  text    NOT NULL DEFAULT '[]',
  created_at        timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pricing_analyses_listing
  ON catalog.pricing_analyses(listing_id, created_at DESC);

-- ─── 2. Emsal İlanları Bulan Fonksiyon ──────────────────
-- Aynı kategori + benzer kapasite (±%50) + aynı para birimi
-- aktif (published/approved) ilanlardan çeker
CREATE OR REPLACE FUNCTION catalog.find_comparable_listings(
  p_listing_id   uuid,
  p_limit        int DEFAULT 20
)
RETURNS TABLE(
  id           uuid,
  title        text,
  locality     text,
  capacity     int,
  nightly_minor int,
  currency     text,
  category     text,
  status       text
) LANGUAGE sql STABLE AS $$
  WITH target AS (
    SELECT
      p.id,
      p.title,
      p.locality,
      p.capacity,
      p.nightly_minor,
      p.currency,
      COALESCE(p.category_code, 'general') AS category
    FROM catalog.properties p
    WHERE p.id = p_listing_id
    LIMIT 1
  )
  SELECT
    p.id,
    p.title,
    p.locality,
    p.capacity,
    p.nightly_minor,
    p.currency,
    COALESCE(p.category_code, 'general') AS category,
    p.status
  FROM catalog.properties p, target t
  WHERE p.id != t.id
    AND p.currency = t.currency
    AND p.nightly_minor > 0
    AND p.status IN ('published', 'approved', 'draft')
    AND p.capacity BETWEEN GREATEST(1, (t.capacity * 0.5)::int) AND (t.capacity * 1.5)::int
  ORDER BY
    -- Konum benzerliği (aynı il/ilçe tercihi)
    CASE WHEN lower(p.locality) = lower(t.locality) THEN 0 ELSE 1 END,
    -- Kapasite yakınlığı
    abs(p.capacity - t.capacity),
    -- Fiyat yakınlığı
    abs(p.nightly_minor - t.nightly_minor)
  LIMIT p_limit;
$$;

-- ─── 3. Fiyat İstatistiklerini Hesaplayan Fonksiyon ─────
CREATE OR REPLACE FUNCTION catalog.compute_price_stats(
  p_listing_id uuid
)
RETURNS TABLE(
  comparable_count int,
  avg_price        int,
  min_price        int,
  max_price        int,
  median_price     int
) LANGUAGE sql STABLE AS $$
  WITH comps AS (
    SELECT c.nightly_minor AS price
    FROM catalog.find_comparable_listings(p_listing_id, 50) c
    WHERE c.nightly_minor > 0
  ),
  stats AS (
    SELECT
      count(*)::int AS cnt,
      COALESCE(avg(price)::int, 0) AS avg_p,
      COALESCE(min(price)::int, 0) AS min_p,
      COALESCE(max(price)::int, 0) AS max_p
    FROM comps
  ),
  med AS (
    SELECT COALESCE(
      percentile_cont(0.5) WITHIN GROUP (ORDER BY price)::int, 0
    ) AS median_p
    FROM comps
  )
  SELECT s.cnt, s.avg_p, s.min_p, s.max_p, m.median_p
  FROM stats s, med m;
$$;

-- ─── 4. Analiz Kaydetme Fonksiyonu ─────────────────────
CREATE OR REPLACE FUNCTION catalog.save_pricing_analysis(
  p_listing_id       uuid,
  p_tenant_id        uuid,
  p_target_category  text,
  p_target_locality  text,
  p_target_capacity  int,
  p_target_price     int,
  p_target_currency  text,
  p_comparable_count int,
  p_avg_price        int,
  p_min_price        int,
  p_max_price        int,
  p_median_price     int,
  p_recommended_min  int,
  p_recommended_max  int,
  p_optimal_price    int,
  p_confidence_pct   int,
  p_verdict          text,
  p_reasoning        text,
  p_comparables_json text
)
RETURNS uuid LANGUAGE sql AS $$
  INSERT INTO catalog.pricing_analyses (
    listing_id, tenant_id,
    target_category, target_locality, target_capacity, target_price, target_currency,
    comparable_count, avg_price, min_price, max_price, median_price,
    recommended_min, recommended_max, optimal_price, confidence_pct,
    verdict, reasoning, comparables_json
  ) VALUES (
    p_listing_id, p_tenant_id,
    p_target_category, p_target_locality, p_target_capacity, p_target_price, p_target_currency,
    p_comparable_count, p_avg_price, p_min_price, p_max_price, p_median_price,
    p_recommended_min, p_recommended_max, p_optimal_price, p_confidence_pct,
    p_verdict, p_reasoning, p_comparables_json
  )
  RETURNING id;
$$;

-- ─── 5. Geçmiş Analizler ───────────────────────────────
CREATE OR REPLACE FUNCTION catalog.pricing_analysis_history(
  p_listing_id uuid,
  p_limit      int DEFAULT 10
)
RETURNS TABLE(
  id               text,
  comparable_count text,
  avg_price        text,
  min_price        text,
  max_price        text,
  median_price     text,
  recommended_min  text,
  recommended_max  text,
  optimal_price    text,
  confidence_pct   text,
  verdict          text,
  reasoning        text,
  created_at       text
) LANGUAGE sql STABLE AS $$
  SELECT
    pa.id::text,
    pa.comparable_count::text,
    pa.avg_price::text,
    pa.min_price::text,
    pa.max_price::text,
    pa.median_price::text,
    pa.recommended_min::text,
    pa.recommended_max::text,
    pa.optimal_price::text,
    pa.confidence_pct::text,
    pa.verdict,
    pa.reasoning,
    to_char(pa.created_at, 'DD.MM.YYYY HH24:MI') AS created_at
  FROM catalog.pricing_analyses pa
  WHERE pa.listing_id = p_listing_id
  ORDER BY pa.created_at DESC
  LIMIT p_limit;
$$;

-- ─── 6. Emsal İlanları Text Formatında Döndürme ────────
CREATE OR REPLACE FUNCTION catalog.comparable_listings_for_display(
  p_listing_id uuid,
  p_limit      int DEFAULT 15
)
RETURNS TABLE(
  id          text,
  title       text,
  locality    text,
  capacity    text,
  price       text,
  currency    text,
  category    text,
  status      text
) LANGUAGE sql STABLE AS $$
  SELECT
    c.id::text,
    c.title,
    c.locality,
    c.capacity::text,
    c.nightly_minor::text,
    c.currency,
    c.category,
    c.status
  FROM catalog.find_comparable_listings(p_listing_id, p_limit) c;
$$;
