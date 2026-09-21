-- Acente -> NEXUS bağlantı onayı ve acente başına katalog kapsamı.
CREATE TABLE IF NOT EXISTS partners.connection_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  agency_name text NOT NULL,
  agency_endpoint text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  allowed_categories jsonb NOT NULL DEFAULT '[]'::jsonb,
  listing_limit int NOT NULL DEFAULT 100 CHECK (listing_limit BETWEEN 1 AND 10000),
  review_note text NOT NULL DEFAULT '',
  approved_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(agency_id)
);

CREATE TABLE IF NOT EXISTS partners.connection_policies (
  agency_id uuid PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  allowed_categories jsonb NOT NULL DEFAULT '[]'::jsonb,
  listing_limit int NOT NULL DEFAULT 100 CHECK (listing_limit BETWEEN 1 AND 10000),
  active boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS partners_connection_requests_status_idx
  ON partners.connection_requests(status, updated_at DESC);

CREATE OR REPLACE FUNCTION partners.receive_connection_request(
  p_agency_id text,
  p_agency_name text,
  p_agency_endpoint text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE agency_uuid uuid; request_uuid uuid;
BEGIN
  IF p_agency_id !~ '^[0-9a-fA-F-]{36}$' OR length(trim(coalesce(p_agency_name,''))) NOT BETWEEN 2 AND 180 THEN
    RETURN 'invalid_request';
  END IF;
  agency_uuid := p_agency_id::uuid;
  IF EXISTS (SELECT 1 FROM core.organizations WHERE id=agency_uuid AND kind<>'agency') THEN
    RETURN 'agency_conflict';
  END IF;
  INSERT INTO core.organizations(id,legal_name,kind)
  VALUES (agency_uuid,trim(p_agency_name),'agency')
  ON CONFLICT(id) DO UPDATE SET legal_name=excluded.legal_name;
  INSERT INTO partners.connection_requests(agency_id,agency_name,agency_endpoint,status,updated_at)
  VALUES (agency_uuid,trim(p_agency_name),coalesce(trim(p_agency_endpoint),''),'pending',now())
  ON CONFLICT(agency_id) DO UPDATE SET
    agency_name=excluded.agency_name,
    agency_endpoint=excluded.agency_endpoint,
    status=CASE WHEN partners.connection_requests.status='approved' THEN 'approved' ELSE 'pending' END,
    updated_at=now()
  RETURNING id INTO request_uuid;
  RETURN request_uuid::text;
END $$;

CREATE OR REPLACE FUNCTION partners.connection_requests()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[
   r.id::text,r.agency_id::text,r.agency_name,r.agency_endpoint,r.status,
   coalesce((SELECT string_agg(value,',') FROM jsonb_array_elements_text(r.allowed_categories)),''),
   r.listing_limit::text,r.created_at::text,r.review_note
 ]
 FROM partners.connection_requests r
 WHERE auth.workspace()='nexus'
 ORDER BY CASE r.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 ELSE 2 END,r.updated_at DESC
 LIMIT 200
$$;

CREATE OR REPLACE FUNCTION partners.decide_connection_request(
  p_request text,
  p_decision text,
  p_categories text,
  p_listing_limit int,
  p_note text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE r partners.connection_requests%ROWTYPE; categories jsonb; actor uuid;
BEGIN
  actor := nullif(current_setting('app.actor_id',true),'')::uuid;
  IF auth.workspace()<>'nexus' OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=actor AND role='owner') THEN RETURN 'forbidden'; END IF;
  SELECT * INTO r FROM partners.connection_requests WHERE id::text=p_request FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  IF p_decision NOT IN ('approved','rejected') THEN RETURN 'invalid_decision'; END IF;
  IF p_decision='approved' AND (p_listing_limit IS NULL OR p_listing_limit NOT BETWEEN 1 AND 10000) THEN RETURN 'invalid_limit'; END IF;
  categories := coalesce((SELECT jsonb_agg(trim(value)) FROM unnest(string_to_array(coalesce(p_categories,''),',')) value WHERE trim(value)<>''),'[]'::jsonb);
  IF p_decision='rejected' THEN
    UPDATE partners.connection_requests SET status='rejected',review_note=coalesce(p_note,''),approved_by=actor,updated_at=now() WHERE id=r.id;
    INSERT INTO partners.connection_policies(agency_id,allowed_categories,listing_limit,active,updated_at)
    VALUES(r.agency_id,'[]'::jsonb,100,false,now())
    ON CONFLICT(agency_id) DO UPDATE SET active=false,updated_at=now();
    UPDATE partners.connections SET status='paused',updated_at=now() WHERE agency_id=r.agency_id;
    RETURN 'ok';
  END IF;
  UPDATE partners.connection_requests SET status='approved',allowed_categories=categories,listing_limit=p_listing_limit,review_note=coalesce(p_note,''),approved_by=actor,updated_at=now() WHERE id=r.id;
  INSERT INTO partners.connection_policies(agency_id,allowed_categories,listing_limit,active,updated_at)
  VALUES(r.agency_id,categories,p_listing_limit,true,now())
  ON CONFLICT(agency_id) DO UPDATE SET allowed_categories=excluded.allowed_categories,listing_limit=excluded.listing_limit,active=true,updated_at=now();
  INSERT INTO partners.connections(supplier_id,agency_id,status)
  SELECT id,r.agency_id,'active' FROM core.organizations WHERE kind='supplier'
  ON CONFLICT(supplier_id,agency_id) DO UPDATE SET status='active',updated_at=now();
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION catalog.marketplace_listings_for_agency(p_agency text)
RETURNS TABLE(id text,title text,locality text,category text,capacity text,price text,currency text,description text,images jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH policy AS (
   SELECT agency_id,allowed_categories,listing_limit
   FROM partners.connection_policies
   WHERE agency_id=p_agency::uuid AND active
 )
 SELECT p.id::text,p.title,p.locality,p.category_code,p.capacity::text,p.nightly_minor::text,
   p.currency::text,p.description,coalesce(p.media,'[]'::jsonb)
 FROM catalog.properties p CROSS JOIN policy x
 WHERE p.status='published'
   AND (jsonb_array_length(x.allowed_categories)=0 OR p.category_code IN (SELECT value FROM jsonb_array_elements_text(x.allowed_categories)))
 ORDER BY p.created_at DESC
 LIMIT (SELECT listing_limit FROM policy)
$$;

REVOKE ALL ON FUNCTION partners.receive_connection_request(text,text,text),partners.connection_requests(),partners.decide_connection_request(text,text,text,int,text),catalog.marketplace_listings_for_agency(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.receive_connection_request(text,text,text),partners.connection_requests(),partners.decide_connection_request(text,text,text,int,text),catalog.marketplace_listings_for_agency(text) TO nexus_app;
