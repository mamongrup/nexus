-- Bounded application-security telemetry for the platform DB.
-- Mirrors the agency-side contract (agency.security_events + record_security_event,
-- db/migrations/139) adapted to the platform schema naming. The table records CSP
-- violation reports and (future) rate-limit observations. Rows are appended only
-- through the SECURITY DEFINER function; direct INSERT stays with the owner for
-- admin queries. Log-like data: no UPDATE/DELETE grants to nexus_app.

CREATE TABLE IF NOT EXISTS events.security_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  request_id varchar(128) NOT NULL,
  client_id varchar(128),
  method varchar(16) NOT NULL,
  route varchar(512) NOT NULL,
  event_type varchar(64) NOT NULL,
  severity varchar(16) NOT NULL DEFAULT 'warning'
    CHECK (severity IN ('info', 'warning', 'critical')),
  decision varchar(32) NOT NULL
    CHECK (decision IN ('observed', 'rate_limited', 'temporarily_quarantined')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS events_security_events_occurred_idx
  ON events.security_events(occurred_at DESC);

CREATE INDEX IF NOT EXISTS events_security_events_type_idx
  ON events.security_events(event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS events_security_events_client_idx
  ON events.security_events(client_id, occurred_at DESC)
  WHERE client_id IS NOT NULL;

CREATE OR REPLACE FUNCTION events.record_security_event(
  p_request_id text,
  p_client_id text,
  p_method text,
  p_route text,
  p_event_type text,
  p_severity text,
  p_decision text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, events
AS $$
DECLARE
  v_id bigint;
BEGIN
  IF coalesce(p_request_id, '') = '' OR coalesce(p_event_type, '') = '' THEN
    RAISE EXCEPTION 'request_id and event_type are required';
  END IF;

  INSERT INTO events.security_events(
    request_id, client_id, method, route, event_type, severity, decision, metadata
  ) VALUES (
    left(p_request_id, 128),
    nullif(left(coalesce(p_client_id, ''), 128), ''),
    left(upper(coalesce(p_method, 'UNKNOWN')), 16),
    left(coalesce(p_route, '/'), 512),
    left(p_event_type, 64),
    p_severity,
    p_decision,
    CASE WHEN jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
      THEN coalesce(p_metadata, '{}'::jsonb)
      ELSE '{}'::jsonb
    END
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION events.record_security_event(text, text, text, text, text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION events.record_security_event(text, text, text, text, text, text, text, jsonb) TO nexus_app;
GRANT SELECT ON events.security_events TO nexus_app;
