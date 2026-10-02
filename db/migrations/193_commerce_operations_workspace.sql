CREATE OR REPLACE FUNCTION inventory.commerce_operations_data(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT inventory.calendar_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'operations_access_denied'; END IF;
 RETURN jsonb_build_object(
 'contractVersion','1.0.0',
 'listings',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'category',p.category_code,'source','local','status',p.status) ORDER BY p.title)
 FROM catalog.properties p WHERE p.tenant_id=p_tenant),'[]'::jsonb),
 'feeds',coalesce((SELECT jsonb_agg(jsonb_build_object('id',f.id,'listing',p.title,'label',f.label,
 'host',substring(f.url FROM '^https://([^/?#]+)'),'timezone',f.timezone,'active',f.active,
 'lastSync',f.last_synced_at,'nextSync',f.next_sync_at,'error',f.last_error,'events',f.event_count,'working',f.claim_id IS NOT NULL))
 FROM inventory.external_calendar_feeds f JOIN catalog.properties p ON p.id=f.listing_id AND p.tenant_id=f.tenant_id
 WHERE f.tenant_id=p_tenant),'[]'::jsonb),
 'conflicts',coalesce((SELECT jsonb_agg(x) FROM (SELECT DISTINCT jsonb_build_object('reference',b.id,'listing',p.title,'arrival',h.check_in,'departure',h.check_out) x
 FROM booking.reservations b JOIN booking.holds h ON h.id=b.hold_id AND h.tenant_id=b.tenant_id
 JOIN inventory.resources r ON r.id=h.resource_id AND r.tenant_id=h.tenant_id
 JOIN catalog.properties p ON p.id=r.property_id AND p.tenant_id=r.tenant_id
 JOIN inventory.external_calendar_feeds f ON f.listing_id=p.id AND f.tenant_id=p.tenant_id AND f.active
 JOIN inventory.external_calendar_blocks cb ON cb.feed_id=f.id AND cb.starts_on<h.check_out AND cb.ends_on>h.check_in
 WHERE b.tenant_id=p_tenant AND b.status='confirmed' AND h.check_out>=current_date LIMIT 100) c),'[]'::jsonb),
 'finance',jsonb_build_object('paymentProvider','ParamPOS','documentProvider','QNB eSolutions','paymentStatus','awaiting_credentials','documentStatus','awaiting_credentials'),
 'channels',coalesce((SELECT jsonb_agg(jsonb_build_object('name',o.legal_name,'mode',c.status,'lastSync',c.updated_at)) FROM partners.connections c
 JOIN core.organizations o ON o.id=c.agency_id WHERE c.supplier_id=p_tenant),'[]'::jsonb),
 'channelQueue',coalesce((SELECT jsonb_object_agg(status,n) FROM (SELECT status,count(*) n FROM events.external_operations WHERE tenant_id=p_tenant GROUP BY status) x),'{}'::jsonb),
 'nexusQueue',coalesce((SELECT jsonb_object_agg(status,n) FROM (SELECT i.status,count(*) n FROM partners.agency_webhook_inbox i JOIN partners.connections c ON c.agency_id::text=i.agency_id
 WHERE c.supplier_id=p_tenant AND EXISTS(SELECT 1 FROM catalog.properties p WHERE p.id::text=i.listing_id AND p.tenant_id=p_tenant) GROUP BY i.status) x),'{}'::jsonb),
 'languages','[]'::jsonb,
 'categories',coalesce((SELECT jsonb_agg(jsonb_build_object('code',c.code,'published',(SELECT count(*) FROM catalog.properties p WHERE p.tenant_id=p_tenant AND p.category_code=c.code AND p.status='published'),'connectedInquiryOnly',
 CASE WHEN c.code IN ('hotel','holiday_home','yacht') THEN 0 ELSE (SELECT count(*) FROM catalog.properties p WHERE p.tenant_id=p_tenant AND p.category_code=c.code AND p.status='published') END))
 FROM onboarding.categories c WHERE c.active),'[]'::jsonb),
 'metrics',coalesce((SELECT jsonb_agg(jsonb_build_object('currency',currency,'bookings',n,'cancelled',cancelled,'paidRevenueMinor',paid)) FROM (
 SELECT b.currency,count(*) n,count(*) FILTER(WHERE b.status='cancelled') cancelled,
 coalesce(sum(b.total_minor) FILTER(WHERE b.payment_status='paid' AND b.status IN ('confirmed','fulfilled')),0) paid
 FROM booking.reservations b WHERE b.tenant_id=p_tenant AND b.created_at>=now()-interval '30 days' GROUP BY b.currency) x),'[]'::jsonb)
 );
END $$;
REVOKE ALL ON FUNCTION inventory.commerce_operations_data(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION inventory.commerce_operations_data(uuid,uuid) TO nexus_app;
