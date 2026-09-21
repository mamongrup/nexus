-- 054_pricing_and_integration_grants.sql
-- Grants permissions to nexus_app for pricing, integrations, finance, ai, and core extensions

GRANT USAGE ON SCHEMA pricing TO nexus_app;
GRANT SELECT, INSERT, UPDATE ON pricing.commercial_rules TO nexus_app;
GRANT SELECT, INSERT, UPDATE ON pricing.quote_snapshots TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pricing TO nexus_app;

GRANT USAGE ON SCHEMA integrations TO nexus_app;
GRANT SELECT ON integrations.adapters TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA integrations TO nexus_app;

GRANT SELECT ON core.fx_rates TO nexus_app;
GRANT SELECT, INSERT, UPDATE ON cms.slug_history TO nexus_app;
GRANT EXECUTE ON FUNCTION cms.record_slug_change(text, text, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION core.convert_currency(bigint, text, text) TO nexus_app;

GRANT USAGE ON SCHEMA finance TO nexus_app;
GRANT SELECT ON finance.accounts, finance.settlements TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA finance TO nexus_app;

GRANT USAGE ON SCHEMA ai TO nexus_app;
GRANT SELECT, INSERT, UPDATE ON ai.actions, ai.executive_insights, ai.workforce_roles TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ai TO nexus_app;

GRANT USAGE ON SCHEMA organization TO nexus_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA organization TO nexus_app;
