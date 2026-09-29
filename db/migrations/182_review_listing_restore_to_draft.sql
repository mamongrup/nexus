-- 182: Askıya alınmış ilanı taslağa döndürme kararı arayüzden verilebilir
--
-- catalog.transition_listing_status (176) 'suspended -> draft' geçişini platform
-- için tanımlıyor, ancak HTTP katmanı platform kararlarını
-- catalog.review_listing() üzerinden gönderiyor ve bu fonksiyon yalnızca
-- 'approved', 'changes_requested' ve 'suspended' kararlarını kabul ediyordu.
-- 'draft' gönderildiğinde 'invalid_decision' dönüyor, yani platform askıya
-- aldığı bir ilanı arayüzden geri alamıyordu.
--
-- 'draft' kararı burada yalnızca mevcut moderasyon durumu 'suspended' olduğunda
-- kabul edilir; böylece 176'daki geçiş matrisi birebir karşılanır ve
-- onaylı/taslak ilanların durumu keyfî olarak değiştirilemez.
-- Fonksiyonun başındaki onboarding.operator() denetimi bu yolun yalnızca
-- platform operatörlerine açık olmasını sağlar.

CREATE OR REPLACE FUNCTION catalog.review_listing(p_id text, p_version int, p_decision text, p_note text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE p catalog.properties%ROWTYPE;
BEGIN
 IF NOT onboarding.operator() THEN RETURN 'forbidden'; END IF;
 SELECT * INTO p FROM catalog.properties WHERE id::text=p_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF p.version<>p_version THEN RETURN 'conflict'; END IF;
 IF p_decision NOT IN ('approved','changes_requested','suspended','draft') THEN RETURN 'invalid_decision'; END IF;
 IF p_decision='approved' AND p.moderation_status<>'in_review' THEN RETURN 'invalid_state'; END IF;
 IF p_decision='approved' AND NOT catalog.listing_contract_required_complete(p.id::text) THEN RETURN 'requirements_incomplete'; END IF;
 -- Bir ilan yalnızca askıya alınmış durumdan taslağa dönebilir.
 IF p_decision='draft' AND p.moderation_status<>'suspended' THEN RETURN 'invalid_state'; END IF;
 UPDATE catalog.properties SET
  moderation_status=p_decision,
  review_note=coalesce(p_note,''),
  reviewed_at=now(),
  reviewed_by=nullif(current_setting('app.actor_id',true),'')::uuid,
  status=CASE WHEN p_decision='approved' THEN 'published' ELSE 'draft' END,
  last_confirmed_at=CASE WHEN p_decision='approved' THEN now() ELSE last_confirmed_at END,
  version=version+1,
  updated_at=now()
 WHERE id=p.id;
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
  VALUES(p.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.reviewed',p.id,
         jsonb_build_object('decision',p_decision,'note',p_note,'contract_version','1.0.0'));
 RETURN 'ok';
END;
$$;

COMMENT ON FUNCTION catalog.review_listing(text,int,text,text) IS
  'Platform moderasyon kararı. Kararlar: approved, changes_requested, suspended ve
   yalnızca askıya alınmış ilanlar için draft. Sözleşme 1.2.0 geçiş matrisi ile uyumludur.';
