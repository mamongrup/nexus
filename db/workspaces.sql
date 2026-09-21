\getenv supplier_password SUPPLIER_PASSWORD
\getenv agency_password AGENCY_PASSWORD
BEGIN;
INSERT INTO core.organizations(id,legal_name,kind) VALUES
('33333333-3333-4333-8333-333333333333','Örnek Tedarikçi','supplier'),
('44444444-4444-4444-8444-444444444444','Örnek Acente','agency') ON CONFLICT DO NOTHING;
INSERT INTO auth.users(tenant_id,email,password_hash,display_name) VALUES
('33333333-3333-4333-8333-333333333333','supplier@nexus.local',crypt(:'supplier_password',gen_salt('bf',12)),'Tedarikçi Yönetici'),
('44444444-4444-4444-8444-444444444444','agency@nexus.local',crypt(:'agency_password',gen_salt('bf',12)),'Acente Yönetici')
ON CONFLICT(email) DO UPDATE SET password_hash=EXCLUDED.password_hash;
COMMIT;
