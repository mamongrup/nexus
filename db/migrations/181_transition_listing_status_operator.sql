-- 181: catalog.transition_listing_status platform yetkisini doğru okuyor
--
-- 176 ile eklenen fonksiyon, platform aktörünü belirlemek için
-- core.organizations.platform_role sütununu okuyor. Bu sütun tabloda yok
-- (core.organizations yalnızca id, legal_name, timezone, created_at, kind
-- içeriyor), bu yüzden fonksiyon her çağrıda 42703 hatasıyla çöküyordu.
--
-- Projenin çalışan platform yetkisi tanımı onboarding.operator() fonksiyonudur:
-- workspace 'nexus' olmalı ve aktörün rolü izin listesinde bulunmalıdır.
-- catalog.review_listing() ve catalog.admin_publish() zaten bunu kullanıyor.
-- Burada da aynı tanıma geçilerek üç fonksiyon aynı yetki kuralını paylaşır.

CREATE OR REPLACE FUNCTION catalog.transition_listing_status(
  p_supplier_id   uuid,
  p_actor_org_id  uuid,
  p_property_id   uuid,
  p_new_moderation_status text,
  p_new_publication_status text DEFAULT NULL,
  p_note          text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $$
DECLARE
  v_old_status      text;
  v_old_mod_status  text;
  v_is_platform     boolean;
  v_is_supplier     boolean;
  v_allowed         boolean := false;
  v_new_pub_status  text;
BEGIN
  -- İlanı kilitle ve doğrula
  SELECT status, moderation_status
  INTO STRICT v_old_status, v_old_mod_status
  FROM catalog.properties
  WHERE id = p_property_id AND tenant_id = p_supplier_id
  FOR UPDATE;

  -- Hedef moderasyon durumu değişmiyorsa hata
  IF v_old_mod_status = p_new_moderation_status
    AND (p_new_publication_status IS NULL OR v_old_status = p_new_publication_status) THEN
    RAISE EXCEPTION 'listing_status_unchanged' USING ERRCODE = '22000';
  END IF;

  -- Geçiş matrisi doğrulaması
  IF NOT (
    (v_old_mod_status IN ('draft','changes_requested') AND p_new_moderation_status = 'in_review')
    OR (v_old_mod_status = 'in_review' AND p_new_moderation_status IN ('approved','changes_requested'))
    OR (v_old_mod_status = 'approved'  AND p_new_moderation_status IN ('approved','suspended'))
    OR (p_new_moderation_status = 'suspended')
    OR (v_old_mod_status = 'suspended' AND p_new_moderation_status = 'draft')
  ) THEN
    RAISE EXCEPTION 'listing_moderation_transition_not_allowed: % -> %',
      v_old_mod_status, p_new_moderation_status
      USING ERRCODE = '22000';
  END IF;

  -- Platform admin: onboarding.operator() aynı workspace ve rol kuralını
  -- catalog.review_listing ile catalog.admin_publish ile paylaşır.
  v_is_platform := onboarding.operator();
  -- Tedarikçi: aynı kuruluş
  v_is_supplier := (p_actor_org_id = p_supplier_id);

  -- İzin kuralları
  IF p_new_moderation_status = 'in_review' THEN
    v_allowed := v_is_supplier OR v_is_platform;

  ELSIF p_new_moderation_status IN ('approved','changes_requested') THEN
    v_allowed := v_is_platform;

  ELSIF p_new_moderation_status = 'suspended' THEN
    v_allowed := v_is_platform;

  ELSIF p_new_moderation_status = 'draft' AND v_old_mod_status = 'suspended' THEN
    v_allowed := v_is_platform;

  ELSE
    v_allowed := v_is_platform;
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'listing_status_transition_access_denied'
      USING ERRCODE = '42501';
  END IF;

  -- Yayın durumu kuralı: onaylanmışsa sahip publish yapabilir, platform askıya alabilir
  v_new_pub_status := COALESCE(p_new_publication_status, v_old_status);
  IF v_new_pub_status = 'published'
    AND p_new_moderation_status NOT IN ('approved') THEN
    RAISE EXCEPTION 'listing_cannot_be_published_without_approval'
      USING ERRCODE = '42501';
  END IF;
  IF v_new_pub_status = 'published' THEN
    IF NOT (v_is_supplier OR v_is_platform) THEN
      RAISE EXCEPTION 'listing_publication_access_denied' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Güncelle — trigger'lar sözleşme ve tedarikçi yayın kontrolünü çalıştırır
  UPDATE catalog.properties
  SET moderation_status = p_new_moderation_status,
      status            = v_new_pub_status,
      updated_at        = now()
  WHERE id = p_property_id AND tenant_id = p_supplier_id;

  -- Denetim kaydı (core.audit_log varsa)
  IF EXISTS(SELECT 1 FROM information_schema.tables
    WHERE table_schema='core' AND table_name='audit_log') THEN
    INSERT INTO core.audit_log(actor_org_id, entity_type, entity_id, action, payload)
    VALUES (
      p_actor_org_id, 'catalog.property', p_property_id,
      'status_transition',
      jsonb_build_object(
        'from_moderation', v_old_mod_status,
        'to_moderation',   p_new_moderation_status,
        'from_status',     v_old_status,
        'to_status',       v_new_pub_status,
        'note',            p_note
      )
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION catalog.transition_listing_status(uuid,uuid,uuid,text,text,text) IS
  'WP1 — sözleşme 1.2.0: Platform korumalı ilan moderasyon ve yayın geçiş makinesi.
   İş kuralları Acente agency.transition_listing_status (migration 225) ile eşdeğerdir.
   NEXUS iki katmanlı durum modeli (status + moderation_status) kullanır.
   Platform yetkisi onboarding.operator() ile belirlenir.';
