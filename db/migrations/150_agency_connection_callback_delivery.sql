-- Track delivery of NEXUS -> agency connection approval callbacks.
-- Plaintext API keys are intentionally not stored here. If a callback must be
-- retried, the admin action issues a fresh agency key and sends that key.
CREATE TABLE IF NOT EXISTS partners.agency_connection_callbacks (
  request_id uuid PRIMARY KEY REFERENCES partners.connection_requests(id) ON DELETE CASCADE,
  agency_id uuid NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  agency_endpoint text NOT NULL DEFAULT '',
  event_type text NOT NULL DEFAULT 'connection.approved',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','failed')),
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_error text NOT NULL DEFAULT '',
  last_attempt_at timestamptz,
  next_attempt_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agency_connection_callbacks_status_idx
  ON partners.agency_connection_callbacks(status, next_attempt_at, updated_at DESC);

GRANT SELECT, INSERT, UPDATE ON partners.agency_connection_callbacks TO nexus_app;

CREATE OR REPLACE FUNCTION partners.connection_requests()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[
   r.id::text,r.agency_id::text,r.agency_name,r.agency_endpoint,r.status,
   coalesce((SELECT string_agg(value,',') FROM jsonb_array_elements_text(r.allowed_categories)), ''),
   r.listing_limit::text,r.created_at::text,r.review_note,
   coalesce(c.status, CASE WHEN r.status='approved' THEN 'pending' ELSE '' END),
   coalesce(c.last_error, '')
 ]
 FROM partners.connection_requests r
 LEFT JOIN partners.agency_connection_callbacks c ON c.request_id=r.id
 WHERE auth.workspace()='nexus'
 ORDER BY CASE r.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,r.updated_at DESC
 LIMIT 200
$$;

REVOKE ALL ON FUNCTION partners.connection_requests() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.connection_requests() TO nexus_app;
