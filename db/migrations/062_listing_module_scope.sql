CREATE FUNCTION catalog.can_access_module(p_property uuid,p_module text DEFAULT NULL)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT coalesce(onboarding.operator() OR EXISTS(
 SELECT FROM catalog.properties p JOIN auth.users u ON u.tenant_id=p.tenant_id
 WHERE p.id=p_property AND u.id=nullif(current_setting('app.actor_id',true),'')::uuid
 AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
 AND u.role IN ('owner','editor') AND auth.workspace()='supplier'
 AND EXISTS(SELECT FROM onboarding.supplier_modules sm JOIN onboarding.product_modules m ON m.code=sm.module_code
 WHERE sm.supplier_id=p.tenant_id AND sm.status='enabled' AND m.active
 AND (p_module IS NULL OR sm.module_code=p_module))),false)
$$;
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['property_units','property_kbs_records','property_ota_channels','property_whatsapp_messages','property_invoices','property_extra_charges'] LOOP
 EXECUTE format('ALTER TABLE catalog.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('CREATE POLICY supplier_module_scope ON catalog.%I FOR SELECT TO nexus_app USING (catalog.can_access_module(property_id))',t);
 EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON catalog.%I FROM nexus_app',t);
 END LOOP;
END $$;

ALTER FUNCTION catalog.listing_pms_units(uuid) RENAME TO listing_pms_units_internal;
REVOKE ALL ON FUNCTION catalog.listing_pms_units_internal(uuid) FROM PUBLIC,nexus_app;
CREATE FUNCTION catalog.listing_pms_units(p_property_id uuid) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT * FROM catalog.listing_pms_units_internal(p_property_id) WHERE catalog.can_access_module(p_property_id,'pms')
$$;
ALTER FUNCTION catalog.listing_modules_cockpit(uuid) RENAME TO listing_modules_cockpit_internal;
REVOKE ALL ON FUNCTION catalog.listing_modules_cockpit_internal(uuid) FROM PUBLIC,nexus_app;
CREATE FUNCTION catalog.listing_modules_cockpit(p_property_id uuid) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT * FROM catalog.listing_modules_cockpit_internal(p_property_id) WHERE catalog.can_access_module(p_property_id)
$$;
ALTER FUNCTION catalog.update_unit_status(uuid,text,text) RENAME TO update_unit_status_internal;
REVOKE ALL ON FUNCTION catalog.update_unit_status_internal(uuid,text,text) FROM PUBLIC,nexus_app;
CREATE FUNCTION catalog.update_unit_status(p_unit_id uuid,p_occupancy text,p_housekeeping text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE p uuid;
BEGIN
 SELECT property_id INTO p FROM catalog.property_units WHERE id=p_unit_id;
 IF NOT catalog.can_access_module(p,'pms') THEN RAISE EXCEPTION 'Module access denied' USING ERRCODE='42501'; END IF;
 RETURN catalog.update_unit_status_internal(p_unit_id,p_occupancy,p_housekeeping);
END $$;
REVOKE ALL ON FUNCTION catalog.can_access_module(uuid,text),catalog.listing_pms_units(uuid),catalog.listing_modules_cockpit(uuid),catalog.update_unit_status(uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION catalog.can_access_module(uuid,text),catalog.listing_pms_units(uuid),catalog.listing_modules_cockpit(uuid),catalog.update_unit_status(uuid,text,text) TO nexus_app;
