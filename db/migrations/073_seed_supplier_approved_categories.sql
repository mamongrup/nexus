-- 073_seed_supplier_approved_categories.sql
-- Seed approved onboarding applications for the default supplier across all active categories

DO $$
DECLARE
  v_user_id uuid;
  v_tenant_id uuid := '33333333-3333-4333-8333-333333333333';
  v_cat text;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'supplier@nexus.local';
  IF v_user_id IS NOT NULL THEN
    FOR v_cat IN SELECT code FROM onboarding.categories WHERE active LOOP
      IF NOT EXISTS (
        SELECT 1 FROM onboarding.applications
        WHERE tenant_id = v_tenant_id AND owner_user_id = v_user_id AND category_code = v_cat
      ) THEN
        INSERT INTO onboarding.applications (
          owner_user_id, tenant_id, category_code, legal_name, status, identity_status
        ) VALUES (
          v_user_id, v_tenant_id, v_cat, 'Örnek Tedarikçi Turizm A.Ş.', 'approved', 'verified'
        );
      ELSE
        UPDATE onboarding.applications
        SET status = 'approved', identity_status = 'verified'
        WHERE tenant_id = v_tenant_id AND owner_user_id = v_user_id AND category_code = v_cat;
      END IF;
    END LOOP;
  END IF;
END $$;
