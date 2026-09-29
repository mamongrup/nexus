BEGIN;
DO $$
DECLARE v_owner uuid; v_tenant uuid; v_application uuid; v_document uuid; v_result text; v_count integer;
BEGIN
  SELECT u.id,u.tenant_id INTO v_owner,v_tenant
  FROM auth.users u JOIN core.organizations o ON o.id=u.tenant_id
  WHERE o.kind='nexus' AND u.role='owner' LIMIT 1;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'platform owner fixture missing'; END IF;
  PERFORM set_config('app.tenant_id',v_tenant::text,true);
  PERFORM set_config('app.actor_id',v_owner::text,true);
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
  VALUES(v_owner,v_tenant,'hotel','Expiry contract test','review','verified') RETURNING id INTO v_application;
  INSERT INTO onboarding.documents(application_id,requirement_id,storage_key,original_name,status,expires_on)
  SELECT v_application,r.id,'upload:abcdefghijklmnopqrstuvwx.pdf',r.code||'.pdf','accepted',current_date+30
  FROM onboarding.requirements r WHERE r.category_code='hotel' AND r.required;
  SELECT d.id INTO v_document FROM onboarding.documents d
  JOIN onboarding.requirements r ON r.id=d.requirement_id
  WHERE d.application_id=v_application AND r.kind='document' LIMIT 1;
  IF v_document IS NULL THEN RAISE EXCEPTION 'hotel document requirement missing'; END IF;
  UPDATE onboarding.documents SET expires_on=current_date-1 WHERE id=v_document;
  v_result:=onboarding.decide(v_application::text,'approved','');
  IF v_result<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'expired document allowed supplier approval: %',v_result;
  END IF;
  UPDATE onboarding.documents SET expires_on=current_date+30 WHERE id=v_document;
  v_result:=onboarding.decide(v_application::text,'approved','');
  IF v_result<>'ok' THEN RAISE EXCEPTION 'valid documents did not allow approval: %',v_result; END IF;
  UPDATE onboarding.documents SET expires_on=current_date-1 WHERE id=v_document;
  v_count:=onboarding.reopen_expired_applications();
  IF v_count<1
    OR (SELECT status FROM onboarding.applications WHERE id=v_application)<>'review' THEN
    RAISE EXCEPTION 'expired document did not reopen approved application';
  END IF;
  IF onboarding.reopen_expired_applications()<>0 THEN
    RAISE EXCEPTION 'expiry reopen was not idempotent';
  END IF;
END $$;
ROLLBACK;
