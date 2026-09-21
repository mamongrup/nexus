\getenv admin_email ADMIN_EMAIL
\getenv admin_password ADMIN_PASSWORD
BEGIN;
INSERT INTO core.currencies VALUES ('TRY',2),('EUR',2),('USD',2),('GBP',2),('CHF',2),('AED',2) ON CONFLICT DO NOTHING;
INSERT INTO core.locales VALUES ('tr','Türkçe','ltr'),('en','English','ltr'),('de','Deutsch','ltr'),('ru','Русский','ltr'),('ar','العربية','rtl'),('fr','Français','ltr') ON CONFLICT DO NOTHING;
INSERT INTO core.organizations(id,legal_name) VALUES('11111111-1111-4111-8111-111111111111','NEXUS TravelTech') ON CONFLICT DO NOTHING;
INSERT INTO auth.users(tenant_id,email,password_hash,display_name) VALUES('11111111-1111-4111-8111-111111111111',lower(:'admin_email'),crypt(:'admin_password',gen_salt('bf',12)),'NEXUS Yönetici') ON CONFLICT(email) DO NOTHING;
COMMIT;
