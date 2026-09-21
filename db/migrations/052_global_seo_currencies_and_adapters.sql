CREATE TABLE IF NOT EXISTS cms.slug_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  old_slug text NOT NULL UNIQUE,
  target_slug text NOT NULL,
  locale text NOT NULL DEFAULT 'tr',
  http_status int NOT NULL DEFAULT 301,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.fx_rates (
  base_currency character(3) NOT NULL REFERENCES core.currencies(code),
  target_currency character(3) NOT NULL REFERENCES core.currencies(code),
  rate_multiplier numeric(18, 6) NOT NULL CHECK(rate_multiplier > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(base_currency, target_currency)
);

INSERT INTO core.fx_rates(base_currency, target_currency, rate_multiplier) VALUES
  ('TRY', 'TRY', 1.000000),
  ('EUR', 'EUR', 1.000000),
  ('USD', 'USD', 1.000000),
  ('GBP', 'GBP', 1.000000),
  ('CHF', 'CHF', 1.000000),
  ('AED', 'AED', 1.000000),
  ('EUR', 'TRY', 38.500000),
  ('USD', 'TRY', 35.200000),
  ('GBP', 'TRY', 45.100000),
  ('CHF', 'TRY', 39.800000),
  ('AED', 'TRY', 9.580000),
  ('TRY', 'EUR', 0.025974),
  ('TRY', 'USD', 0.028409),
  ('TRY', 'GBP', 0.022173),
  ('USD', 'EUR', 0.914286),
  ('EUR', 'USD', 1.093750)
ON CONFLICT (base_currency, target_currency) DO UPDATE SET
  rate_multiplier = EXCLUDED.rate_multiplier,
  updated_at = now();

CREATE SCHEMA IF NOT EXISTS integrations;

CREATE TABLE IF NOT EXISTS integrations.adapters (
  adapter_code text PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL CHECK(category IN ('gds_flight', 'hotel_bed', 'payment_psp', 'messaging', 'einvoice')),
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','standby','circuit_open','maintenance')),
  circuit_breaker_failures int NOT NULL DEFAULT 0,
  latency_ms int NOT NULL DEFAULT 120,
  supported_operations text[] NOT NULL DEFAULT ARRAY['search','quote','availability','createBooking','cancel'],
  endpoint_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO integrations.adapters(adapter_code, name, category, status, supported_operations, endpoint_url) VALUES
  ('param_pos', 'Param POS / TurkPOS Gateway', 'payment_psp', 'active', ARRAY['payment','refund','preauth','inquiry'], 'https://posws.param.com.tr/turkpos.ws/service_turkpos_prod.asmx'),
  ('amadeus', 'Amadeus Travel Platform', 'gds_flight', 'standby', ARRAY['search','quote','availability','createBooking','cancel'], 'https://api.amadeus.com/v1'),
  ('duffel', 'Duffel Flights API', 'gds_flight', 'standby', ARRAY['search','quote','createBooking','cancel'], 'https://api.duffel.com'),
  ('hotelbeds', 'Hotelbeds Connectivity', 'hotel_bed', 'standby', ARRAY['search','quote','availability','createBooking','cancel'], 'https://api.hotelbeds.com')
ON CONFLICT (adapter_code) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  supported_operations = EXCLUDED.supported_operations;

CREATE OR REPLACE FUNCTION core.convert_currency(
  p_amount_minor bigint,
  p_from text,
  p_to text
) RETURNS bigint LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT CASE
    WHEN p_from = p_to THEN p_amount_minor
    ELSE round(p_amount_minor * coalesce((
      SELECT rate_multiplier FROM core.fx_rates
      WHERE base_currency = p_from AND target_currency = p_to
    ), 1.0))::bigint
  END;
$$;

CREATE OR REPLACE FUNCTION cms.record_slug_change(
  p_old text,
  p_new text,
  p_locale text DEFAULT 'tr'
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF p_old = p_new OR p_old IS NULL OR p_new IS NULL THEN RETURN 'unchanged'; END IF;
  INSERT INTO cms.slug_history(old_slug, target_slug, locale, http_status)
  VALUES (p_old, p_new, coalesce(p_locale, 'tr'), 301)
  ON CONFLICT (old_slug) DO UPDATE SET target_slug = EXCLUDED.target_slug, created_at = now();
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION integrations.adapter_directory()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.adapter_code,
    a.name,
    a.category,
    a.status,
    a.latency_ms::text || ' ms',
    array_to_string(a.supported_operations, ', ')
  ]
  FROM integrations.adapters a
  ORDER BY a.category, a.name;
$$;
