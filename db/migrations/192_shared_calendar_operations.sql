-- Implements channel-operations.v1.json against the central resource model.
CREATE OR REPLACE FUNCTION inventory.calendar_admin(p_tenant uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT p_tenant=nullif(current_setting('app.tenant_id',true),'')::uuid
 AND p_actor=nullif(current_setting('app.actor_id',true),'')::uuid
 AND EXISTS(SELECT 1 FROM auth.users u JOIN core.organizations o ON o.id=u.tenant_id
 WHERE u.tenant_id=p_tenant AND u.id=p_actor AND u.role IN ('owner','editor')
 AND o.kind IN ('supplier','nexus'))
$$;
CREATE TABLE IF NOT EXISTS inventory.external_calendar_feeds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
 listing_id uuid NOT NULL, label text NOT NULL CHECK(length(label) BETWEEN 1 AND 100),
 url text NOT NULL CHECK(url ~ '^https://[^/[:space:]@]+/'),
 active boolean NOT NULL DEFAULT true, timezone text NOT NULL DEFAULT 'Europe/Istanbul',
 next_sync_at timestamptz NOT NULL DEFAULT now(), last_synced_at timestamptz,
 last_error text NOT NULL DEFAULT '', failure_count int NOT NULL DEFAULT 0,
 claimed_at timestamptz, claim_id uuid, event_count int NOT NULL DEFAULT 0,
 FOREIGN KEY(tenant_id,listing_id) REFERENCES catalog.properties(tenant_id,id) ON DELETE CASCADE,
 UNIQUE(tenant_id,listing_id,label)
);
CREATE TABLE IF NOT EXISTS inventory.external_calendar_blocks (
 feed_id uuid NOT NULL REFERENCES inventory.external_calendar_feeds(id) ON DELETE CASCADE,
 event_key text NOT NULL, starts_on date NOT NULL, ends_on date NOT NULL CHECK(ends_on>starts_on),
 PRIMARY KEY(feed_id,event_key)
);
CREATE TABLE IF NOT EXISTS inventory.calendar_export_keys (
 tenant_id uuid NOT NULL, listing_id uuid NOT NULL, token_hash text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,listing_id),
 FOREIGN KEY(tenant_id,listing_id) REFERENCES catalog.properties(tenant_id,id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS external_calendar_due ON inventory.external_calendar_feeds(next_sync_at) WHERE active;
CREATE INDEX IF NOT EXISTS external_calendar_dates ON inventory.external_calendar_blocks(starts_on,ends_on);

CREATE OR REPLACE FUNCTION inventory.save_external_calendar(p_tenant uuid,p_actor uuid,p_listing uuid,p_label text,p_url text,p_timezone text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
 IF NOT inventory.calendar_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF NOT EXISTS(SELECT 1 FROM catalog.properties WHERE tenant_id=p_tenant AND id=p_listing
   AND category_code IN ('holiday_home','yacht')) THEN RAISE EXCEPTION 'calendar_listing_unavailable'; END IF;
 IF p_url !~ '^https://[^/[:space:]@]+/' OR length(p_url)>2048
  OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'calendar_invalid_input'; END IF;
 IF (SELECT count(*) FROM inventory.external_calendar_feeds WHERE tenant_id=p_tenant AND listing_id=p_listing AND active)>=8
  AND NOT EXISTS(SELECT 1 FROM inventory.external_calendar_feeds WHERE tenant_id=p_tenant AND listing_id=p_listing AND label=p_label) THEN RAISE EXCEPTION 'calendar_feed_limit'; END IF;
 INSERT INTO inventory.external_calendar_feeds(tenant_id,listing_id,label,url,timezone)
 VALUES(p_tenant,p_listing,p_label,p_url,p_timezone)
 ON CONFLICT(tenant_id,listing_id,label) DO UPDATE SET url=excluded.url,timezone=excluded.timezone,
 active=true,next_sync_at=now(),claim_id=NULL,claimed_at=NULL,last_error='' RETURNING id INTO v_id;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION inventory.external_calendar_action(p_tenant uuid,p_actor uuid,p_feed uuid,p_action text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT inventory.calendar_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF p_action='sync' THEN
  UPDATE inventory.external_calendar_feeds SET next_sync_at=now() WHERE tenant_id=p_tenant AND id=p_feed AND active;
 ELSIF p_action='remove' THEN
  UPDATE inventory.external_calendar_feeds SET active=false,claim_id=NULL,claimed_at=NULL WHERE tenant_id=p_tenant AND id=p_feed;
 ELSE RAISE EXCEPTION 'calendar_invalid_action'; END IF;
 RETURN FOUND;
END $$;

CREATE OR REPLACE FUNCTION inventory.claim_external_calendars() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH due AS (SELECT id FROM inventory.external_calendar_feeds WHERE active AND next_sync_at<=now()
  AND (claimed_at IS NULL OR claimed_at<now()-interval '5 minutes') ORDER BY next_sync_at LIMIT 10 FOR UPDATE SKIP LOCKED),
 claimed AS (UPDATE inventory.external_calendar_feeds f SET claimed_at=now(),claim_id=gen_random_uuid()
 FROM due WHERE f.id=due.id RETURNING f.*)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'tenant_id',tenant_id,'url',url,'timezone',timezone,'claim',claim_id)), '[]'::jsonb) FROM claimed
$$;

CREATE OR REPLACE FUNCTION inventory.complete_external_calendar(p_tenant uuid,p_feed uuid,p_claim uuid,p_events jsonb,p_error text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE f inventory.external_calendar_feeds%ROWTYPE;
BEGIN
 SELECT * INTO f FROM inventory.external_calendar_feeds WHERE id=p_feed AND tenant_id=p_tenant
  AND active AND claim_id=p_claim FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF coalesce(p_error,'')<>'' THEN
  UPDATE inventory.external_calendar_feeds SET last_error=left(p_error,300),failure_count=least(failure_count+1,10),
   next_sync_at=now()+least(interval '6 hours',interval '5 minutes'*power(2,least(failure_count,6))),
   claim_id=NULL,claimed_at=NULL WHERE id=f.id;
  RETURN true; -- Keep the last valid blocks on network/parser failure.
 END IF;
 IF jsonb_typeof(p_events)<>'array' OR jsonb_array_length(p_events)>5000 THEN RAISE EXCEPTION 'calendar_invalid_events'; END IF;
 PERFORM 1 FROM catalog.properties WHERE id=f.listing_id AND tenant_id=p_tenant FOR UPDATE;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_events) e WHERE length(e->>'key') NOT BETWEEN 1 AND 300
  OR (e->>'start')::date IS NULL OR (e->>'end')::date IS NULL
  OR (e->>'end')::date<=(e->>'start')::date OR (e->>'end')::date-(e->>'start')::date>730) THEN RAISE EXCEPTION 'calendar_invalid_events'; END IF;
 DELETE FROM inventory.external_calendar_blocks WHERE feed_id=f.id;
 INSERT INTO inventory.external_calendar_blocks SELECT f.id,e->>'key',(e->>'start')::date,(e->>'end')::date
 FROM jsonb_array_elements(p_events) e;
 UPDATE inventory.external_calendar_feeds SET last_synced_at=now(),next_sync_at=now()+interval '15 minutes',
  last_error='',failure_count=0,event_count=jsonb_array_length(p_events),claim_id=NULL,claimed_at=NULL WHERE id=f.id;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION inventory.rotate_calendar_export(p_tenant uuid,p_actor uuid,p_listing uuid,p_token text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT inventory.calendar_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF p_token !~ '^[a-f0-9]{64}$' OR NOT EXISTS(SELECT 1 FROM catalog.properties WHERE tenant_id=p_tenant
  AND id=p_listing AND category_code IN ('holiday_home','yacht')) THEN RETURN false; END IF;
 INSERT INTO inventory.calendar_export_keys(tenant_id,listing_id,token_hash)
 VALUES(p_tenant,p_listing,encode(public.digest(p_token,'sha256'),'hex'))
 ON CONFLICT(tenant_id,listing_id) DO UPDATE SET token_hash=excluded.token_hash,created_at=now();
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION inventory.external_calendar_blocked(p_tenant uuid,p_resource uuid,p_day date)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM inventory.resources r
 JOIN inventory.external_calendar_feeds f ON f.listing_id=r.property_id AND f.tenant_id=r.tenant_id
 JOIN inventory.external_calendar_blocks b ON b.feed_id=f.id
 WHERE r.tenant_id=p_tenant AND r.id=p_resource AND f.active
 AND b.starts_on<=p_day AND b.ends_on>p_day)
$$;

CREATE OR REPLACE FUNCTION inventory.guard_external_calendar_allocation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p uuid;
BEGIN
 SELECT property_id INTO p FROM inventory.resources WHERE tenant_id=NEW.tenant_id AND id=NEW.resource_id;
 PERFORM 1 FROM catalog.properties WHERE tenant_id=NEW.tenant_id AND id=p FOR UPDATE;
 IF inventory.external_calendar_blocked(NEW.tenant_id,NEW.resource_id,NEW.service_date)
 THEN RAISE EXCEPTION 'external_calendar_unavailable'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS external_calendar_allocation_guard ON inventory.allocations;
CREATE TRIGGER external_calendar_allocation_guard BEFORE INSERT OR UPDATE OF tenant_id,resource_id,service_date
ON inventory.allocations FOR EACH ROW EXECUTE FUNCTION inventory.guard_external_calendar_allocation();

CREATE OR REPLACE FUNCTION inventory.calendar_export_data(p_token text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('listing',k.listing_id,'events',coalesce((SELECT jsonb_agg(e) FROM (
 SELECT jsonb_build_object('key',b.id,'start',h.check_in,'end',h.check_out) e
 FROM booking.reservations b JOIN booking.holds h ON h.id=b.hold_id AND h.tenant_id=b.tenant_id
 JOIN inventory.resources r ON r.id=h.resource_id AND r.tenant_id=h.tenant_id
 WHERE b.tenant_id=k.tenant_id AND r.property_id=k.listing_id AND b.status IN ('confirmed','fulfilled')
 AND h.check_out>=current_date AND h.check_out>h.check_in
 UNION ALL
 SELECT jsonb_build_object('key',h.id,'start',h.check_in,'end',h.check_out)
 FROM booking.holds h JOIN inventory.resources r ON r.id=h.resource_id AND r.tenant_id=h.tenant_id
 WHERE h.tenant_id=k.tenant_id AND r.property_id=k.listing_id AND h.status='active'
 AND h.expires_at>clock_timestamp() AND h.check_out>=current_date AND h.check_out>h.check_in
 ) x),'[]'::jsonb)) FROM inventory.calendar_export_keys k
 WHERE k.token_hash=encode(public.digest(p_token,'sha256'),'hex') AND p_token ~ '^[a-f0-9]{64}$'
$$;

CREATE OR REPLACE FUNCTION inventory.agency_inventory_feed(p_agency text,p_listing text)
RETURNS TABLE(service_date text,status text,price_minor int)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT d.service_date::text,
 CASE WHEN d.blocked+d.held+d.sold>=d.capacity OR inventory.external_calendar_blocked(d.tenant_id,d.resource_id,d.service_date)
 THEN 'unavailable' ELSE 'available' END,coalesce(d.nightly_minor,p.nightly_minor)::int
 FROM inventory.days d JOIN inventory.resources r ON r.id=d.resource_id AND r.tenant_id=d.tenant_id
 JOIN catalog.properties p ON p.id=r.property_id AND p.tenant_id=r.tenant_id
 JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.agency_id=p_agency::uuid AND c.status='active'
 JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
 WHERE p.id=p_listing::uuid AND catalog.is_publishable(p.id::text)
 AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)))
 ORDER BY d.service_date LIMIT 365
$$;

ALTER TABLE inventory.external_calendar_feeds ENABLE ROW LEVEL SECURITY;
CREATE POLICY calendar_tenant ON inventory.external_calendar_feeds
 USING(tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid);
ALTER TABLE inventory.external_calendar_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY calendar_tenant ON inventory.external_calendar_blocks
 USING(EXISTS(SELECT 1 FROM inventory.external_calendar_feeds f WHERE f.id=feed_id AND f.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid));
ALTER TABLE inventory.calendar_export_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY calendar_tenant ON inventory.calendar_export_keys
 USING(tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid);
REVOKE ALL ON inventory.external_calendar_feeds,inventory.external_calendar_blocks,inventory.calendar_export_keys FROM PUBLIC;
GRANT SELECT ON inventory.external_calendar_feeds,inventory.external_calendar_blocks,inventory.calendar_export_keys TO nexus_app;
REVOKE ALL ON FUNCTION inventory.calendar_admin(uuid,uuid),inventory.external_calendar_blocked(uuid,uuid,date),inventory.guard_external_calendar_allocation(),inventory.save_external_calendar(uuid,uuid,uuid,text,text,text),inventory.external_calendar_action(uuid,uuid,uuid,text),inventory.claim_external_calendars(),inventory.complete_external_calendar(uuid,uuid,uuid,jsonb,text),inventory.rotate_calendar_export(uuid,uuid,uuid,text),inventory.calendar_export_data(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.calendar_admin(uuid,uuid),inventory.external_calendar_blocked(uuid,uuid,date),inventory.save_external_calendar(uuid,uuid,uuid,text,text,text),inventory.external_calendar_action(uuid,uuid,uuid,text),inventory.claim_external_calendars(),inventory.complete_external_calendar(uuid,uuid,uuid,jsonb,text),inventory.rotate_calendar_export(uuid,uuid,uuid,text),inventory.calendar_export_data(text) TO nexus_app;

