CREATE OR REPLACE FUNCTION inventory.calendar_admin(p_tenant uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT coalesce(p_actor=nullif(current_setting('app.actor_id',true),'')::uuid AND (
 (p_tenant=nullif(current_setting('app.tenant_id',true),'')::uuid AND EXISTS(
 SELECT 1 FROM auth.users u JOIN core.organizations o ON o.id=u.tenant_id
 WHERE u.tenant_id=p_tenant AND u.id=p_actor AND u.role IN ('owner','editor') AND o.kind IN ('supplier','nexus')))
 OR (onboarding.operator() AND EXISTS(SELECT 1 FROM core.organizations WHERE id=p_tenant AND kind IN ('supplier','nexus')))),false)
$$;
CREATE OR REPLACE FUNCTION inventory.calendar_target_scope(p_listing uuid,p_feed uuid) RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid;
BEGIN
 IF p_listing IS NOT NULL THEN SELECT tenant_id INTO t FROM catalog.properties WHERE id=p_listing;
 ELSE SELECT tenant_id INTO t FROM inventory.external_calendar_feeds WHERE id=p_feed; END IF;
 IF NOT inventory.calendar_admin(t,u) THEN RETURN NULL; END IF;
 RETURN t;
END $$;
REVOKE ALL ON FUNCTION inventory.calendar_target_scope(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.calendar_target_scope(uuid,uuid) TO nexus_app;

CREATE OR REPLACE FUNCTION inventory.commerce_operations_data(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE scopes uuid[];
BEGIN
 IF NOT inventory.calendar_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'operations_access_denied'; END IF;
 SELECT CASE WHEN onboarding.operator() THEN (SELECT array_agg(id) FROM core.organizations WHERE kind IN ('supplier','nexus')) ELSE ARRAY[p_tenant] END INTO scopes;
 RETURN jsonb_build_object(
 'contractVersion','1.0.0',
 'listings',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'category',p.category_code,'source','local','status',p.status) ORDER BY p.title)
 FROM catalog.properties p WHERE p.tenant_id=ANY(scopes)),'[]'::jsonb),
 'feeds',coalesce((SELECT jsonb_agg(jsonb_build_object('id',f.id,'listing',p.title,'label',f.label,
 'host',substring(f.url FROM '^https://([^/?#]+)'),'timezone',f.timezone,'active',f.active,
 'lastSync',f.last_synced_at,'nextSync',f.next_sync_at,'error',f.last_error,'events',f.event_count,'working',f.claim_id IS NOT NULL))
 FROM inventory.external_calendar_feeds f JOIN catalog.properties p ON p.id=f.listing_id AND p.tenant_id=f.tenant_id
 WHERE f.tenant_id=ANY(scopes)),'[]'::jsonb),
 'conflicts',coalesce((SELECT jsonb_agg(x) FROM (SELECT DISTINCT jsonb_build_object('reference',b.id,'listing',p.title,'arrival',h.check_in,'departure',h.check_out) x
 FROM booking.reservations b JOIN booking.holds h ON h.id=b.hold_id AND h.tenant_id=b.tenant_id
 JOIN inventory.resources r ON r.id=h.resource_id AND r.tenant_id=h.tenant_id
 JOIN catalog.properties p ON p.id=r.property_id AND p.tenant_id=r.tenant_id
 JOIN inventory.external_calendar_feeds f ON f.listing_id=p.id AND f.tenant_id=p.tenant_id AND f.active
 JOIN inventory.external_calendar_blocks cb ON cb.feed_id=f.id AND cb.starts_on<h.check_out AND cb.ends_on>h.check_in
 WHERE b.tenant_id=ANY(scopes) AND b.status='confirmed' AND h.check_out>=current_date LIMIT 100) c),'[]'::jsonb),
 'finance',jsonb_build_object('paymentProvider','ParamPOS','documentProvider','QNB eSolutions','paymentStatus','awaiting_credentials','documentStatus','awaiting_credentials'),
 'channels',coalesce((SELECT jsonb_agg(jsonb_build_object('name',o.legal_name,'mode',c.status,'lastSync',c.updated_at)) FROM partners.connections c
 JOIN core.organizations o ON o.id=c.agency_id WHERE c.supplier_id=ANY(scopes)),'[]'::jsonb),
 'channelQueue',coalesce((SELECT jsonb_object_agg(status,n) FROM (SELECT status,count(*) n FROM events.external_operations WHERE tenant_id=ANY(scopes) GROUP BY status) x),'{}'::jsonb),
 'nexusQueue',coalesce((SELECT jsonb_object_agg(status,n) FROM (SELECT i.status,count(*) n FROM partners.agency_webhook_inbox i JOIN partners.connections c ON c.agency_id::text=i.agency_id
 WHERE c.supplier_id=ANY(scopes) AND EXISTS(SELECT 1 FROM catalog.properties p WHERE p.id::text=i.listing_id AND p.tenant_id=ANY(scopes)) GROUP BY i.status) x),'{}'::jsonb),
 'languages','[]'::jsonb,
 'categories',coalesce((SELECT jsonb_agg(jsonb_build_object('code',c.code,'published',(SELECT count(*) FROM catalog.properties p WHERE p.tenant_id=ANY(scopes) AND p.category_code=c.code AND p.status='published'),'connectedInquiryOnly',
 CASE WHEN c.code IN ('hotel','holiday_home','yacht') THEN 0 ELSE (SELECT count(*) FROM catalog.properties p WHERE p.tenant_id=ANY(scopes) AND p.category_code=c.code AND p.status='published') END))
 FROM onboarding.categories c WHERE c.active),'[]'::jsonb),
 'metrics',coalesce((SELECT jsonb_agg(jsonb_build_object('currency',currency,'bookings',n,'cancelled',cancelled,'paidRevenueMinor',paid)) FROM (
 SELECT b.currency,count(*) n,count(*) FILTER(WHERE b.status='cancelled') cancelled,
 coalesce(sum(b.total_minor) FILTER(WHERE b.payment_status='paid' AND b.status IN ('confirmed','fulfilled')),0) paid
 FROM booking.reservations b WHERE b.tenant_id=ANY(scopes) AND b.created_at>=now()-interval '30 days' GROUP BY b.currency) x),'[]'::jsonb)
 );
END $$;
REVOKE ALL ON FUNCTION inventory.commerce_operations_data(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.commerce_operations_data(uuid,uuid) TO nexus_app;
CREATE OR REPLACE FUNCTION operations.listing_review_source(p_listing uuid) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid;
BEGIN
 t:=inventory.calendar_target_scope(p_listing,NULL);
 IF t IS NULL OR NOT inventory.calendar_admin(t,u) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 RETURN (SELECT jsonb_build_object('title',title,'description',description,'category',category_code,'locality',locality,'contract_fields',attributes)::text
 FROM catalog.properties WHERE id=p_listing AND tenant_id=t);
END $$;
CREATE OR REPLACE FUNCTION operations.save_listing_review(p_listing uuid,p_source text,p_review jsonb,p_provider text,p_model text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t uuid:=nullif(current_setting('app.tenant_id',true),'')::uuid; u uuid:=nullif(current_setting('app.actor_id',true),'')::uuid;
BEGIN
 t:=inventory.calendar_target_scope(p_listing,NULL);
 IF t IS NULL OR NOT inventory.calendar_admin(t,u) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 PERFORM 1 FROM catalog.properties WHERE id=p_listing AND tenant_id=t FOR UPDATE;
 IF NOT FOUND OR operations.listing_review_source(p_listing) IS DISTINCT FROM p_source THEN RETURN 'stale_source'; END IF;
 IF length(p_source)>12000 OR jsonb_typeof(p_review)<>'object' THEN RETURN 'invalid_review'; END IF;
 INSERT INTO operations.listing_content_reviews(tenant_id,listing_id,actor_id,source_text,review,provider,model)
 VALUES(t,p_listing,u,p_source,p_review,p_provider,p_model);
 RETURN 'saved';
END $$;

