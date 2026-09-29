BEGIN;
DO $$
DECLARE v_property uuid; v_tenant uuid; v_category text; v_count integer; v_blocked boolean:=false;
BEGIN
  SELECT p.id,p.tenant_id,p.category_code INTO v_property,v_tenant,v_category
  FROM catalog.properties p JOIN core.organizations o ON o.id=p.tenant_id
  WHERE p.status='published' AND o.kind='supplier'
    AND EXISTS(SELECT 1 FROM onboarding.applications a
      WHERE a.tenant_id=p.tenant_id AND a.category_code=p.category_code AND a.status='approved')
  LIMIT 1;
  IF v_property IS NULL THEN RAISE EXCEPTION 'published supplier property fixture missing'; END IF;
  UPDATE onboarding.applications SET status='review'
  WHERE tenant_id=v_tenant AND category_code=v_category AND status='approved';
  SELECT count(*) INTO v_count FROM onboarding.applications
  WHERE tenant_id=v_tenant AND category_code=v_category AND status='approved';
  IF v_count<>0 OR (SELECT status FROM catalog.properties WHERE id=v_property)<>'draft'
    OR (SELECT moderation_status FROM catalog.properties WHERE id=v_property)<>'suspended' THEN
    RAISE EXCEPTION 'supplier property stayed public after approval loss';
  END IF;
  BEGIN
    UPDATE catalog.properties SET status='published' WHERE id=v_property;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'supplier property republished without approval'; END IF;
END $$;
ROLLBACK;
