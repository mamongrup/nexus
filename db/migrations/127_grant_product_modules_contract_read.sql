-- Contract checks and panel read endpoints need to inspect the active module
-- catalog through the application user.

GRANT SELECT ON onboarding.product_modules TO nexus_app;
