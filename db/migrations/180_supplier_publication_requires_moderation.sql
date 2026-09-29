-- 180: Tedarikçi yayınlaması platform moderasyonuna bağlanır
--
-- catalog.guard_supplier_publication_status() yalnızca tedarikçinin kategori
-- için onaylı onboarding başvurusu olup olmadığını denetliyordu. Bu yüzden
-- doğrudan status güncellemesi, moderation_status hâlâ 'draft' olan bir ilanı
-- yayınlayabiliyordu. Böylece 176 ile eklenen iki katmanlı durum makinesi
-- (tedarikçi gönderir, platform onaylar, sonra yayınlanır) atlanıyordu.
--
-- Yayınlamak artık iki koşulu birden gerektirir:
--   1. kategori için onaylı onboarding başvurusu (değişmedi)
--   2. moderation_status = 'approved'
--
-- Kapsam değişmez: koruma yalnızca ilanın sahibi tedarikçi kuruluşu olduğunda
-- çalışır, platform yayınları etkilenmez. catalog.review_listing() onayı
-- moderation_status ve status alanlarını aynı UPDATE içinde yazdığı için
-- gerçek bir onay yine korumadan geçer.

CREATE OR REPLACE FUNCTION catalog.guard_supplier_publication_status() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.status = 'published'
    AND EXISTS (SELECT 1 FROM core.organizations o WHERE o.id = NEW.tenant_id AND o.kind = 'supplier')
  THEN
    IF NOT EXISTS (
      SELECT 1 FROM onboarding.applications a
      WHERE a.tenant_id = NEW.tenant_id
        AND a.category_code = NEW.category_code
        AND a.status = 'approved'
    ) THEN
      RAISE EXCEPTION 'supplier_not_approved' USING ERRCODE = '42501';
    END IF;

    -- Moderasyon onayı olmadan vitrinde yayınlanamaz.
    IF NEW.moderation_status IS DISTINCT FROM 'approved' THEN
      RAISE EXCEPTION 'listing_not_moderation_approved' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END $$;

-- Mevcut veri: platform moderasyonu hiç uygulanmadan yayına alınmış ilanlar
-- sözleşmeye aykırıydı. Bunları geri çekiyoruz; onay verildiğinde yeniden
-- yayınlanabilirler. İşlem geri alınabilir ve audit kaydı bırakılır.
DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM catalog.properties p
  JOIN core.organizations o ON o.id = p.tenant_id
  WHERE o.kind = 'supplier'
    AND p.status = 'published'
    AND p.moderation_status IS DISTINCT FROM 'approved';

  IF v_count > 0 THEN
    UPDATE catalog.properties p
    SET status = 'draft', updated_at = now()
    FROM core.organizations o
    WHERE o.id = p.tenant_id
      AND o.kind = 'supplier'
      AND p.status = 'published'
      AND p.moderation_status IS DISTINCT FROM 'approved';

    INSERT INTO events.audit(tenant_id, actor_id, action, resource_id, payload)
    SELECT p.tenant_id,
           NULL,
           'property.unapproved_withdrawn',
           p.id,
           jsonb_build_object('from_status', 'published', 'to_status', 'draft', 'reason', 'migration_180_moderation_not_approved')
    FROM catalog.properties p
    JOIN core.organizations o ON o.id = p.tenant_id
    WHERE o.kind = 'supplier'
      AND p.status = 'draft'
      AND p.moderation_status IS DISTINCT FROM 'approved'
      AND p.updated_at > now() - interval '1 minute';

    RAISE NOTICE '180: % unapproved supplier listing(s) withdrawn from the public catalogue', v_count;
  END IF;
END $$;
