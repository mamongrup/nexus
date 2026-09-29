ALTER FUNCTION operations.platform_control_checks()
  RENAME TO platform_control_checks_without_category_fulfillment;
REVOKE ALL ON FUNCTION operations.platform_control_checks_without_category_fulfillment()
  FROM PUBLIC,nexus_app;

CREATE FUNCTION operations.platform_control_checks()
RETURNS TABLE(data text[]) LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,operations,public AS $$
DECLARE v_unsupported bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE auth.workspace()='nexus'
      AND u.id=nullif(current_setting('app.actor_id',true),'')::uuid
      AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
      AND u.role='owner'
  ) THEN RETURN; END IF;
  RETURN QUERY SELECT * FROM operations.platform_control_checks_without_category_fulfillment();

  SELECT count(DISTINCT p.id) INTO v_unsupported
  FROM catalog.properties p
  JOIN partners.connections c ON c.supplier_id=p.tenant_id AND c.status='active'
  JOIN partners.connection_policies cp ON cp.agency_id=c.agency_id AND cp.active
  WHERE p.status='published'
    AND p.category_code NOT IN ('hotel','holiday_home','yacht')
    AND (jsonb_array_length(cp.allowed_categories)=0 OR p.category_code IN (
      SELECT value FROM jsonb_array_elements_text(cp.allowed_categories)));
  RETURN QUERY SELECT ARRAY['Stoklu rezervasyonu olmayan bağlı kategoriler',
    CASE WHEN v_unsupported=0 THEN 'ok' ELSE 'attention' END,
    v_unsupported::text||' ilan','/admin/listings',
    'Bu ilanlar acente beslemesinde bulunabilir; merkezi stoklu ödeme akışı henüz desteklenmez'];
END $$;

REVOKE ALL ON FUNCTION operations.platform_control_checks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION operations.platform_control_checks() TO nexus_app;
