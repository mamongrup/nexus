-- Platform owner can inspect live, cross-tenant aggregate controls without
-- exposing customer, supplier, or integration secrets from individual tenants.
CREATE SCHEMA IF NOT EXISTS operations;

CREATE OR REPLACE FUNCTION operations.platform_control_checks()
RETURNS TABLE(data text[]) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH allowed AS (
    SELECT EXISTS (
      SELECT 1 FROM auth.users u
      WHERE auth.workspace()='nexus'
        AND u.id=nullif(current_setting('app.actor_id',true),'')::uuid
        AND u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
        AND u.role='owner'
    ) AS ok
  ), metrics AS (
    SELECT
      (SELECT count(*) FROM onboarding.categories WHERE active AND code IN ('hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus')) AS categories,
      (SELECT count(*) FROM onboarding.applications WHERE status IN ('identity_pending','documents_pending','review')) AS applications,
      (SELECT count(*) FROM onboarding.applications WHERE identity_status='manual_review' AND status NOT IN ('approved','rejected','deleted')) AS identity_reviews,
      (SELECT count(*) FROM onboarding.documents WHERE status='pending') AS documents,
      (SELECT count(*) FROM catalog.properties WHERE moderation_status='in_review') AS listing_reviews,
      (SELECT count(*) FROM catalog.properties WHERE status='published' AND (last_confirmed_at IS NULL OR last_confirmed_at<now()-interval '30 days')) AS stale_listings,
      (SELECT count(*) FROM partners.connection_requests WHERE status='pending') AS agency_connections,
      (SELECT count(*) FROM onboarding.syndication_events WHERE status='failed') AS syndication_failed,
      (SELECT count(*) FROM events.outbox WHERE published_at IS NULL AND created_at<now()-interval '15 minutes') AS outbox_stale,
      (SELECT count(*) FROM invoicing.e_invoices WHERE gib_status='Reddedildi') AS invoices_rejected
  )
  SELECT ARRAY[v.title,v.status,v.metric,v.href,v.detail]
  FROM allowed a CROSS JOIN metrics m
  CROSS JOIN LATERAL (VALUES
    ('Kategori sözleşmesi',CASE WHEN categories=17 THEN 'ok' ELSE 'attention' END,categories::text||'/17','/admin/category-fields','Etkin kanonik kategori sayısı'),
    ('Tedarikçi başvuruları',CASE WHEN applications=0 THEN 'ok' ELSE 'attention' END,applications::text||' bekliyor','/admin/applications','Kimlik, belge veya karar aşamasındaki başvurular'),
    ('Kimlik incelemesi',CASE WHEN identity_reviews=0 THEN 'ok' ELSE 'attention' END,identity_reviews::text||' inceleme','/admin/applications','Manuel kimlik kararı bekleyenler'),
    ('Belge incelemesi',CASE WHEN documents=0 THEN 'ok' ELSE 'attention' END,documents::text||' belge','/admin/applications','Tedarikçilerin gönderdiği belgeler'),
    ('İlan onayları',CASE WHEN listing_reviews=0 THEN 'ok' ELSE 'attention' END,listing_reviews::text||' ilan','/admin/listings','Moderasyon kuyruğu'),
    ('Güncelliğini yitiren ilanlar',CASE WHEN stale_listings=0 THEN 'ok' ELSE 'attention' END,stale_listings::text||' ilan','/admin/listings','30 günü aşan envanter onayı'),
    ('Acente bağlantıları',CASE WHEN agency_connections=0 THEN 'ok' ELSE 'attention' END,agency_connections::text||' talep','/admin/partners/connection-requests','Onay bekleyen acente bağlantıları'),
    ('Syndication iletimi',CASE WHEN syndication_failed=0 THEN 'ok' ELSE 'attention' END,syndication_failed::text||' hata','/admin/applications','Başarısız tedarikçi yayın olayları'),
    ('Olay kuyruğu',CASE WHEN outbox_stale=0 THEN 'ok' ELSE 'attention' END,outbox_stale::text||' gecikmiş','/admin/requests','15 dakikayı aşan yayınlanmamış olaylar'),
    ('E-fatura retleri',CASE WHEN invoices_rejected=0 THEN 'ok' ELSE 'attention' END,invoices_rejected::text||' ret','/admin/einvoice','GİB tarafından reddedilmiş kayıtlar')
  ) AS v(title,status,metric,href,detail)
  WHERE a.ok;
$$;

REVOKE ALL ON FUNCTION operations.platform_control_checks() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION operations.platform_control_checks() TO nexus_app;

-- A newly created electronic invoice must never appear accepted before a
-- real provider acknowledgement has been recorded.
ALTER TABLE invoicing.e_invoices ALTER COLUMN gib_status SET DEFAULT 'Kuyrukta';
ALTER TABLE invoicing.e_invoices ALTER COLUMN gib_status_code SET DEFAULT 0;
