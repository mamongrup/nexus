ALTER FUNCTION operations.platform_control_checks()
  RENAME TO platform_control_checks_without_booking_failures;
REVOKE ALL ON FUNCTION operations.platform_control_checks_without_booking_failures()
  FROM PUBLIC,nexus_app;

CREATE FUNCTION operations.platform_control_checks()
RETURNS TABLE(data text[]) LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,operations,public AS $$
DECLARE v_failures bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE auth.workspace()='nexus'
      AND u.id=nullif(current_setting('app.actor_id',true),'')::uuid
      AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
      AND u.role='owner'
  ) THEN RETURN; END IF;
  RETURN QUERY SELECT * FROM operations.platform_control_checks_without_booking_failures();
  SELECT count(*) INTO v_failures FROM partners.agency_booking_failures
  WHERE last_at>=now()-interval '7 days';
  RETURN QUERY SELECT ARRAY['Acente rezervasyon retleri',
    CASE WHEN v_failures=0 THEN 'ok' ELSE 'attention' END,
    v_failures::text||' ret','/admin/reservations',
    'Son 7 günde stok, fiyat, süre veya kapsam nedeniyle reddedilen webhook anahtarları'];
END $$;

REVOKE ALL ON FUNCTION operations.platform_control_checks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION operations.platform_control_checks() TO nexus_app;
