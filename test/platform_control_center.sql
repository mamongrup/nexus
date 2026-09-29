BEGIN;
DO $$
DECLARE v_owner uuid; v_tenant uuid; v_count int;
BEGIN
  SELECT u.id,u.tenant_id INTO v_owner,v_tenant
  FROM auth.users u JOIN core.organizations o ON o.id=u.tenant_id
  WHERE o.kind='nexus' AND u.role='owner' LIMIT 1;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'platform owner fixture missing'; END IF;
  PERFORM set_config('app.tenant_id',v_tenant::text,true);
  PERFORM set_config('app.actor_id',v_owner::text,true);
  SELECT count(*) INTO v_count FROM operations.platform_control_checks();
  IF v_count<>16 THEN RAISE EXCEPTION 'platform control count mismatch: %',v_count; END IF;
  IF NOT EXISTS(SELECT 1 FROM operations.platform_control_checks() c
      WHERE c.data[1]='Stoklu rezervasyonu olmayan bağlı kategoriler') THEN
    RAISE EXCEPTION 'connected category fulfillment control missing'; END IF;
  PERFORM set_config('app.actor_id',gen_random_uuid()::text,true);
  SELECT count(*) INTO v_count FROM operations.platform_control_checks();
  IF v_count<>0 THEN RAISE EXCEPTION 'unauthorized control data exposed'; END IF;
END $$;
ROLLBACK;
