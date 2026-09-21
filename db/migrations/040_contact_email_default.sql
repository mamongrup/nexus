INSERT INTO settings.values(tenant_id,key,value,version,updated_by)
SELECT o.id,'contact.email','info@nexustraveltech.com',1,u.id FROM core.organizations o
JOIN LATERAL(SELECT id FROM auth.users WHERE tenant_id=o.id AND role='owner' ORDER BY created_at,id LIMIT 1) u ON true
WHERE o.id=(SELECT id FROM core.organizations WHERE kind='nexus' ORDER BY created_at,id LIMIT 1)
ON CONFLICT(tenant_id,key) DO NOTHING;
UPDATE cms.pages SET body='İş ortaklığı, ürünlerimiz ve destek talepleriniz için bizimle iletişime geçin.',
published=CASE WHEN published->>'body'=body THEN jsonb_set(published,'{body}',to_jsonb('İş ortaklığı, ürünlerimiz ve destek talepleriniz için bizimle iletişime geçin.'::text)) ELSE published END,version=version+1
WHERE slug='iletisim' AND body LIKE 'E-posta: hello@nexustraveltech.com%';
