-- 097_platform_operator_scope_enhancement.sql
-- onboarding.operator() fonksiyonunun platform süper yönetici alt rollerini tanıması

CREATE OR REPLACE FUNCTION onboarding.operator()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog AS $$
  SELECT coalesce(
    auth.workspace() = 'nexus'
    AND EXISTS (
      SELECT FROM auth.users
      WHERE id = nullif(current_setting('app.actor_id', true), '')::uuid
        AND tenant_id = nullif(current_setting('app.tenant_id', true), '')::uuid
        AND role IN (
          'owner',
          'operations_director',
          'content_moderator',
          'finance_manager',
          'onboarding_specialist',
          'ai_pricing_specialist',
          'support_specialist',
          'editor'
        )
    ),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION onboarding.operator() TO nexus_app;
