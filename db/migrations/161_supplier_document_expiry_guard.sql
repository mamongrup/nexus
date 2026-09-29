-- Expired supplier documents do not satisfy the shared approval contract.
CREATE OR REPLACE FUNCTION onboarding.decide(p_application text,p_decision text,p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a onboarding.applications%ROWTYPE;
BEGIN
  IF NOT onboarding.operator() OR p_decision NOT IN ('approved','rejected','deleted') THEN RETURN 'forbidden'; END IF;
  SELECT * INTO a FROM onboarding.applications WHERE id::text=p_application FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  IF p_decision='approved' AND (
    a.identity_status<>'verified' OR EXISTS(
      SELECT 1 FROM onboarding.requirements r
      WHERE r.category_code=a.category_code AND r.required
        AND NOT EXISTS(
          SELECT 1 FROM onboarding.documents d
          WHERE d.application_id=a.id AND d.requirement_id=r.id
            AND d.status='accepted'
            AND (d.expires_on IS NULL OR d.expires_on>=current_date)
        )
    )
  ) THEN RETURN 'requirements_incomplete'; END IF;
  UPDATE onboarding.applications SET status=p_decision,
    rejection_reason=CASE WHEN p_decision='rejected' THEN p_reason ELSE NULL END,
    updated_at=now() WHERE id=a.id;
  IF p_decision='approved' THEN
    INSERT INTO onboarding.syndication_events(application_id,target_id)
    SELECT a.id,id FROM onboarding.syndication_targets WHERE active ON CONFLICT DO NOTHING;
  END IF;
  INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
  VALUES(a.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,
    'onboarding.'||p_decision,a.id,jsonb_build_object('reason',p_reason));
  RETURN 'ok';
END $$;

-- The platform owner sees documents requiring renewal across organizations.
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
      (SELECT count(*) FROM onboarding.documents d JOIN onboarding.applications a ON a.id=d.application_id
        JOIN onboarding.requirements r ON r.id=d.requirement_id
        WHERE a.status='approved' AND r.required AND d.status='accepted' AND d.expires_on<current_date) AS expired_documents,
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
    ('Süresi dolan belgeler',CASE WHEN expired_documents=0 THEN 'ok' ELSE 'attention' END,expired_documents::text||' belge','/admin/applications','Onaylı tedarikçilerde yenileme gereken belgeler'),
    ('İlan onayları',CASE WHEN listing_reviews=0 THEN 'ok' ELSE 'attention' END,listing_reviews::text||' ilan','/admin/listings','Moderasyon kuyruğu'),
    ('Güncelliğini yitiren ilanlar',CASE WHEN stale_listings=0 THEN 'ok' ELSE 'attention' END,stale_listings::text||' ilan','/admin/listings','30 günü aşan envanter onayı'),
    ('Acente bağlantıları',CASE WHEN agency_connections=0 THEN 'ok' ELSE 'attention' END,agency_connections::text||' talep','/admin/partners/connection-requests','Onay bekleyen acente bağlantıları'),
    ('Syndication iletimi',CASE WHEN syndication_failed=0 THEN 'ok' ELSE 'attention' END,syndication_failed::text||' hata','/admin/applications','Başarısız tedarikçi yayın olayları'),
    ('Olay kuyruğu',CASE WHEN outbox_stale=0 THEN 'ok' ELSE 'attention' END,outbox_stale::text||' gecikmiş','/admin/requests','15 dakikayı aşan yayınlanmamış olaylar'),
    ('E-fatura retleri',CASE WHEN invoices_rejected=0 THEN 'ok' ELSE 'attention' END,invoices_rejected::text||' ret','/admin/einvoice','GİB tarafından reddedilmiş kayıtlar')
  ) AS v(title,status,metric,href,detail)
  WHERE a.ok;
$$;
