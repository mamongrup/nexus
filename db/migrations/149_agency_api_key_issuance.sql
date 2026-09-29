-- Issue a one-time agency API key after an owner approves a connection.
-- Only the SHA-256 hash is persisted; the plaintext token is returned once.
CREATE OR REPLACE FUNCTION partners.issue_agency_api_key(
  p_agency_id uuid,
  p_label text DEFAULT 'default'
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,partners,core,public
AS $$
DECLARE
  actor uuid;
  token text;
BEGIN
  actor := nullif(current_setting('app.actor_id',true),'')::uuid;
  IF auth.workspace()<>'nexus'
     OR NOT EXISTS(
       SELECT 1 FROM auth.users
        WHERE id=actor AND role='owner'
     ) THEN
    RETURN 'forbidden';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM core.organizations
     WHERE id=p_agency_id AND kind='agency'
  ) THEN
    RETURN 'agency_not_found';
  END IF;
  IF trim(coalesce(p_label,''))='' THEN
    RETURN 'invalid_label';
  END IF;

  token := 'nx_' || encode(gen_random_bytes(24),'hex');
  INSERT INTO partners.agency_api_keys(agency_id,label,key_hash,active,updated_at)
  VALUES(
    p_agency_id,
    trim(p_label),
    encode(public.digest(token,'sha256'),'hex'),
    true,
    now()
  )
  ON CONFLICT(agency_id,label) DO UPDATE SET
    key_hash=excluded.key_hash,
    active=true,
    updated_at=now(),
    last_used_at=NULL;
  RETURN token;
END
$$;

CREATE OR REPLACE FUNCTION partners.decide_connection_request(
  p_request text,
  p_decision text,
  p_categories text,
  p_listing_limit int,
  p_note text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,partners,core,auth,public AS $$
DECLARE
  r partners.connection_requests%ROWTYPE;
  categories jsonb;
  actor uuid;
  issued_key text;
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
  issued_key := partners.issue_agency_api_key(r.agency_id,'default');
  IF issued_key IN ('forbidden','agency_not_found','invalid_label') THEN
    RETURN issued_key;
  END IF;
  RETURN 'agency_api_key:' || issued_key;
END
$$;

REVOKE ALL ON FUNCTION partners.issue_agency_api_key(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.issue_agency_api_key(uuid,text) TO nexus_app;
REVOKE ALL ON FUNCTION partners.decide_connection_request(text,text,text,int,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION partners.decide_connection_request(text,text,text,int,text) TO nexus_app;
