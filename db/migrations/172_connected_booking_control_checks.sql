ALTER FUNCTION operations.platform_control_checks()
  RENAME TO platform_control_checks_base;
REVOKE ALL ON FUNCTION operations.platform_control_checks_base()
  FROM PUBLIC,nexus_app;

CREATE FUNCTION operations.platform_control_checks()
RETURNS TABLE(data text[]) LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,operations,public AS $$
DECLARE v_pending bigint; v_expiring bigint; v_failed bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE auth.workspace()='nexus'
      AND u.id=nullif(current_setting('app.actor_id',true),'')::uuid
      AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
      AND u.role='owner'
  ) THEN RETURN; END IF;

  RETURN QUERY SELECT * FROM operations.platform_control_checks_base();

  SELECT count(*),count(*) FILTER (WHERE l.expires_at<=now()+interval '10 minutes')
  INTO v_pending,v_expiring
  FROM partners.agency_booking_links l
  JOIN booking.reservations b ON b.id=l.booking_id
  WHERE b.status='confirmed' AND b.payment_status='unpaid';
  SELECT count(*) INTO v_failed FROM partners.agency_webhook_inbox
  WHERE status='failed' AND created_at>=now()-interval '7 days';

  RETURN QUERY SELECT ARRAY['Acente ödeme bekleyen rezervasyonları',
    'ok',v_pending::text||' bekliyor','/admin/reservations',
    'Merkezde ayrılmış, henüz ödenmemiş bağlı acente stoğu'];
  RETURN QUERY SELECT ARRAY['Süresi yaklaşan acente rezervasyonları',
    CASE WHEN v_expiring=0 THEN 'ok' ELSE 'attention' END,
    v_expiring::text||' yakın','/admin/reservations',
    'Son ödeme süresine 10 dakikadan az kalan kayıtlar'];
  RETURN QUERY SELECT ARRAY['Acente rezervasyon webhook hataları',
    CASE WHEN v_failed=0 THEN 'ok' ELSE 'attention' END,
    v_failed::text||' hata','/admin/reservations',
    'Son 7 günde merkezde reddedilen oluşturma veya durum olayları'];
END $$;

REVOKE ALL ON FUNCTION operations.platform_control_checks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION operations.platform_control_checks() TO nexus_app;
