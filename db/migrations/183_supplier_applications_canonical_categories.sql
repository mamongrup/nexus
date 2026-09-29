-- 183: Tedarikçi kategori başvuruları kanonik 17 ile hizalanır
--
-- AGENTS.md kanonik ana kategori listesinde 'visa' yer alıyor ancak demo tedarikçi
-- başvurusunda eksikti; buna karşılık 'spa' ve 'package' onaylıydı. Bu iki kod
-- onboarding.categories içinde pasif durumda ve AGENTS.md'ye göre bağımsız ana
-- kategori değiller ('spa' ilgili kategorilerin alt türü, 'package' ise bir modül).
-- Onaylı oldukları için tedarikçi yayın koruması bu kodları da kabul ediyordu.
--
-- Düzeltme:
--   * 'visa' onaylı başvuru olarak eklenir.
--   * 'spa' ve 'package' başvuruları 'deleted' durumuna alınır. Silinmezler;
--     başvuru geçmişi denetim izi olarak korunur.
--
-- Kanonik olmayan başka kategori kodu onaylı değildir, bu migration yalnızca
-- demo tedarikçi kiracısını hizalar.

-- Kanonik listede bulunmayan onaylı başvuruları kapat.
UPDATE onboarding.applications a
SET status = 'deleted',
    rejection_reason = coalesce(rejection_reason, 'Kategori kanonik 17 listesinde değil'),
    updated_at = now()
FROM onboarding.categories c
WHERE a.category_code = c.code
  AND NOT c.active
  AND a.status = 'approved'
  AND c.code NOT IN ('villa');

-- Kanonik 17 kategoriden onaylı olmayanları onayla.
INSERT INTO onboarding.applications(owner_user_id, tenant_id, category_code, legal_name, status, identity_status)
SELECT u.id,
       u.tenant_id,
       c.code,
       o.legal_name,
       'approved',
       'verified'
FROM auth.users u
JOIN core.organizations o ON o.id = u.tenant_id
CROSS JOIN onboarding.categories c
WHERE u.email = 'supplier@nexus.local'
  AND c.active
  AND NOT EXISTS (
    SELECT 1 FROM onboarding.applications a
    WHERE a.tenant_id = u.tenant_id
      AND a.owner_user_id = u.id
      AND a.category_code = c.code
      AND a.status = 'approved'
  );

-- Son durumu raporla.
DO $$
DECLARE
  v_tenant uuid;
  v_missing text;
  v_legacy  text;
BEGIN
  SELECT tenant_id INTO v_tenant FROM auth.users WHERE email = 'supplier@nexus.local';

  SELECT string_agg(c.code, ', ' ORDER BY c.code) INTO v_missing
  FROM onboarding.categories c
  WHERE c.active
    AND NOT EXISTS (
      SELECT 1 FROM onboarding.applications a
      WHERE a.tenant_id = v_tenant AND a.category_code = c.code AND a.status = 'approved'
    );

  SELECT string_agg(a.category_code, ', ' ORDER BY a.category_code) INTO v_legacy
  FROM onboarding.applications a
  JOIN onboarding.categories c ON c.code = a.category_code
  WHERE a.tenant_id = v_tenant
    AND a.status = 'approved'
    AND NOT c.active;

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'Supplier is still missing approved categories: %', v_missing;
  END IF;
  IF v_legacy IS NOT NULL THEN
    RAISE EXCEPTION 'Supplier still holds approved non canonical categories: %', v_legacy;
  END IF;

  RAISE NOTICE '183: supplier applications aligned with the canonical 17 categories';
END $$;
