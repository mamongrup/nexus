-- 087_supplier_campaigns_and_discounts.sql
-- Supplier Discounts, Promotions & Campaign Engine

CREATE TABLE IF NOT EXISTS catalog.campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  campaign_type text NOT NULL,
  discount_type text NOT NULL DEFAULT 'percentage',
  discount_val bigint NOT NULL DEFAULT 10,
  property_id uuid REFERENCES catalog.properties(id) ON DELETE CASCADE,
  category_code text,
  promo_code text,
  min_stay_nights int NOT NULL DEFAULT 1,
  days_in_advance int NOT NULL DEFAULT 0,
  start_date date NOT NULL DEFAULT current_date,
  end_date date NOT NULL DEFAULT (current_date + interval '180 days'),
  usage_limit int NOT NULL DEFAULT 100,
  used_count int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  badge_text text NOT NULL DEFAULT '🔥 Özel İndirim',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT campaign_type_check CHECK (campaign_type IN ('early_bird', 'last_minute', 'long_stay', 'flash_sale', 'promo_code', 'weekend_special')),
  CONSTRAINT campaign_discount_type_check CHECK (discount_type IN ('percentage', 'fixed_minor'))
);

CREATE INDEX IF NOT EXISTS campaigns_tenant_idx ON catalog.campaigns(tenant_id);
CREATE INDEX IF NOT EXISTS campaigns_prop_idx ON catalog.campaigns(property_id);
CREATE INDEX IF NOT EXISTS campaigns_code_idx ON catalog.campaigns(promo_code);
CREATE INDEX IF NOT EXISTS campaigns_active_idx ON catalog.campaigns(is_active);

-- 1. List Supplier Campaigns (with tenant isolation)
CREATE OR REPLACE FUNCTION catalog.supplier_campaigns()
RETURNS TABLE(data text[]) LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
BEGIN
  RETURN QUERY
  SELECT ARRAY[
    c.id::text,
    c.name,
    c.campaign_type,
    c.discount_type,
    c.discount_val::text,
    coalesce(c.property_id::text, ''),
    coalesce(p.title, 'Tüm İlanlarım'),
    coalesce(c.category_code, 'all'),
    coalesce(c.promo_code, ''),
    c.min_stay_nights::text,
    c.days_in_advance::text,
    to_char(c.start_date, 'YYYY-MM-DD'),
    to_char(c.end_date, 'YYYY-MM-DD'),
    c.usage_limit::text,
    c.used_count::text,
    c.is_active::text,
    c.badge_text
  ]
  FROM catalog.campaigns c
  LEFT JOIN catalog.properties p ON p.id = c.property_id
  WHERE (auth.workspace() = 'nexus' OR c.tenant_id = t)
  ORDER BY c.created_at DESC;
END $$;

-- 2. Create Campaign
CREATE OR REPLACE FUNCTION catalog.create_campaign(
  p_name text,
  p_type text,
  p_discount_type text,
  p_discount_val bigint,
  p_property_id uuid,
  p_category_code text,
  p_promo_code text,
  p_min_stay int,
  p_days_advance int,
  p_start_date date,
  p_end_date date,
  p_usage_limit int,
  p_badge text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
  v_prop catalog.properties%ROWTYPE;
BEGIN
  IF t IS NULL AND auth.workspace() <> 'nexus' THEN
    RETURN 'forbidden';
  END IF;

  -- Default to first tenant if nexus operator creates on behalf
  IF t IS NULL THEN
    SELECT tenant_id INTO t FROM catalog.properties LIMIT 1;
  END IF;

  IF length(trim(p_name)) < 3 THEN
    RETURN 'invalid_name';
  END IF;

  IF p_type NOT IN ('early_bird', 'last_minute', 'long_stay', 'flash_sale', 'promo_code', 'weekend_special') THEN
    RETURN 'invalid_type';
  END IF;

  IF p_discount_type NOT IN ('percentage', 'fixed_minor') THEN
    RETURN 'invalid_discount_type';
  END IF;

  IF p_discount_val <= 0 THEN
    RETURN 'invalid_discount_val';
  END IF;

  IF p_discount_type = 'percentage' AND p_discount_val > 90 THEN
    RETURN 'invalid_percentage';
  END IF;

  IF p_property_id IS NOT NULL THEN
    SELECT * INTO v_prop FROM catalog.properties WHERE id = p_property_id AND (auth.workspace() = 'nexus' OR tenant_id = t);
    IF v_prop.id IS NULL THEN
      RETURN 'property_not_found';
    END IF;
  END IF;

  INSERT INTO catalog.campaigns (
    tenant_id,
    name,
    campaign_type,
    discount_type,
    discount_val,
    property_id,
    category_code,
    promo_code,
    min_stay_nights,
    days_in_advance,
    start_date,
    end_date,
    usage_limit,
    badge_text
  ) VALUES (
    t,
    trim(p_name),
    p_type,
    p_discount_type,
    p_discount_val,
    p_property_id,
    nullif(trim(p_category_code), ''),
    nullif(upper(trim(p_promo_code)), ''),
    greatest(1, coalesce(p_min_stay, 1)),
    greatest(0, coalesce(p_days_advance, 0)),
    coalesce(p_start_date, current_date),
    coalesce(p_end_date, current_date + interval '180 days'),
    greatest(1, coalesce(p_usage_limit, 100)),
    coalesce(nullif(trim(p_badge), ''), '🔥 Fırsat')
  );

  RETURN 'ok';
END $$;

-- 3. Toggle Campaign Status
CREATE OR REPLACE FUNCTION catalog.toggle_campaign(p_id uuid, p_active boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
BEGIN
  UPDATE catalog.campaigns
  SET is_active = p_active, updated_at = now()
  WHERE id = p_id AND (auth.workspace() = 'nexus' OR tenant_id = t);

  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;

  RETURN 'ok';
END $$;

-- 4. Delete Campaign
CREATE OR REPLACE FUNCTION catalog.delete_campaign(p_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id', true), '')::uuid;
BEGIN
  DELETE FROM catalog.campaigns
  WHERE id = p_id AND (auth.workspace() = 'nexus' OR tenant_id = t);

  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;

  RETURN 'ok';
END $$;

-- 5. List Active Campaigns for a Property
CREATE OR REPLACE FUNCTION catalog.listing_active_campaigns(p_property_id uuid)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    c.id::text,
    c.name,
    c.campaign_type,
    c.discount_type,
    c.discount_val::text,
    coalesce(c.promo_code, ''),
    c.min_stay_nights::text,
    c.days_in_advance::text,
    to_char(c.start_date, 'YYYY-MM-DD'),
    to_char(c.end_date, 'YYYY-MM-DD'),
    c.badge_text
  ]
  FROM catalog.campaigns c
  JOIN catalog.properties p ON p.id = p_property_id
  WHERE c.is_active = true
    AND c.used_count < c.usage_limit
    AND current_date BETWEEN c.start_date AND c.end_date
    AND (c.property_id = p_property_id OR (c.property_id IS NULL AND (c.category_code IS NULL OR c.category_code = p.category_code) AND c.tenant_id = p.tenant_id))
  ORDER BY c.discount_val DESC;
$$;

-- 6. Calculate Booking Discount
CREATE OR REPLACE FUNCTION catalog.calculate_booking_discount(
  p_property_id uuid,
  p_promo_code text,
  p_check_in date,
  p_check_out date,
  p_base_price_minor bigint
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_nights int := greatest(1, p_check_out - p_check_in);
  v_advance_days int := greatest(0, p_check_in - current_date);
  v_prop catalog.properties%ROWTYPE;
  v_camp catalog.campaigns%ROWTYPE;
  v_best_discount_minor bigint := 0;
  v_best_camp_name text := '';
  v_best_badge text := '';
  v_best_discount_pct int := 0;
  v_cur_discount_minor bigint := 0;
  v_cur_pct int := 0;
  v_clean_code text := upper(trim(coalesce(p_promo_code, '')));
BEGIN
  SELECT * INTO v_prop FROM catalog.properties WHERE id = p_property_id;
  IF v_prop.id IS NULL THEN
    RETURN jsonb_build_object('has_discount', false, 'discount_minor', 0, 'final_price_minor', p_base_price_minor, 'campaign_name', '', 'badge_text', '');
  END IF;

  FOR v_camp IN
    SELECT * FROM catalog.campaigns c
    WHERE c.is_active = true
      AND c.used_count < c.usage_limit
      AND (p_check_in BETWEEN c.start_date AND c.end_date OR current_date BETWEEN c.start_date AND c.end_date)
      AND (c.property_id = p_property_id OR (c.property_id IS NULL AND (c.category_code IS NULL OR c.category_code = v_prop.category_code) AND c.tenant_id = v_prop.tenant_id))
  LOOP
    v_cur_discount_minor := 0;
    v_cur_pct := 0;

    -- A. Promo code match
    IF v_camp.campaign_type = 'promo_code' THEN
      IF v_clean_code <> '' AND v_camp.promo_code = v_clean_code THEN
        IF v_camp.discount_type = 'percentage' THEN
          v_cur_pct := v_camp.discount_val::int;
          v_cur_discount_minor := (p_base_price_minor * v_camp.discount_val) / 100;
        ELSE
          v_cur_discount_minor := least(p_base_price_minor, v_camp.discount_val);
          v_cur_pct := ((v_cur_discount_minor * 100) / p_base_price_minor)::int;
        END IF;
      END IF;

    -- B. Early Bird
    ELSIF v_camp.campaign_type = 'early_bird' THEN
      IF v_advance_days >= v_camp.days_in_advance AND v_nights >= v_camp.min_stay_nights THEN
        IF v_camp.discount_type = 'percentage' THEN
          v_cur_pct := v_camp.discount_val::int;
          v_cur_discount_minor := (p_base_price_minor * v_camp.discount_val) / 100;
        ELSE
          v_cur_discount_minor := least(p_base_price_minor, v_camp.discount_val);
        END IF;
      END IF;

    -- C. Last Minute
    ELSIF v_camp.campaign_type = 'last_minute' THEN
      IF v_advance_days <= v_camp.days_in_advance AND v_nights >= v_camp.min_stay_nights THEN
        IF v_camp.discount_type = 'percentage' THEN
          v_cur_pct := v_camp.discount_val::int;
          v_cur_discount_minor := (p_base_price_minor * v_camp.discount_val) / 100;
        ELSE
          v_cur_discount_minor := least(p_base_price_minor, v_camp.discount_val);
        END IF;
      END IF;

    -- D. Long Stay
    ELSIF v_camp.campaign_type = 'long_stay' THEN
      IF v_nights >= v_camp.min_stay_nights THEN
        IF v_camp.discount_type = 'percentage' THEN
          v_cur_pct := v_camp.discount_val::int;
          v_cur_discount_minor := (p_base_price_minor * v_camp.discount_val) / 100;
        ELSE
          v_cur_discount_minor := least(p_base_price_minor, v_camp.discount_val);
        END IF;
      END IF;

    -- E. Flash sale / Weekend special
    ELSIF v_camp.campaign_type IN ('flash_sale', 'weekend_special') THEN
      IF v_nights >= v_camp.min_stay_nights THEN
        IF v_camp.discount_type = 'percentage' THEN
          v_cur_pct := v_camp.discount_val::int;
          v_cur_discount_minor := (p_base_price_minor * v_camp.discount_val) / 100;
        ELSE
          v_cur_discount_minor := least(p_base_price_minor, v_camp.discount_val);
        END IF;
      END IF;
    END IF;

    IF v_cur_discount_minor > v_best_discount_minor THEN
      v_best_discount_minor := v_cur_discount_minor;
      v_best_camp_name := v_camp.name;
      v_best_badge := v_camp.badge_text;
      v_best_discount_pct := v_cur_pct;
    END IF;
  END LOOP;

  IF v_best_discount_minor > 0 THEN
    RETURN jsonb_build_object(
      'has_discount', true,
      'discount_minor', v_best_discount_minor,
      'final_price_minor', (p_base_price_minor - v_best_discount_minor),
      'campaign_name', v_best_camp_name,
      'badge_text', v_best_badge,
      'discount_pct', v_best_discount_pct
    );
  ELSE
    RETURN jsonb_build_object(
      'has_discount', false,
      'discount_minor', 0,
      'final_price_minor', p_base_price_minor,
      'campaign_name', '',
      'badge_text', '',
      'discount_pct', 0
    );
  END IF;
END $$;

-- 7. Update create_marketplace_booking to Support Promo Code / Campaign Discount
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(
  p_property_id uuid,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text,
  p_tc text,
  p_check_in date,
  p_check_out date,
  p_guests int,
  p_promo_code text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_prop catalog.properties%ROWTYPE;
  v_nights int;
  v_raw_total_minor bigint;
  v_discount_calc jsonb;
  v_discount_minor bigint := 0;
  v_total_minor bigint;
  v_camp_name text := '';
  v_pnr text;
  v_res_id uuid := gen_random_uuid();
  v_unit catalog.property_units%ROWTYPE;
  v_dispatch text;
  v_inv text;
BEGIN
  IF p_check_out <= p_check_in THEN
    RETURN jsonb_build_object('error', 'invalid_dates', 'message', 'Çıkış tarihi giriş tarihinden sonra olmalıdır.');
  END IF;

  v_nights := p_check_out - p_check_in;

  SELECT * INTO v_prop FROM catalog.properties WHERE id = p_property_id AND status = 'published';
  IF v_prop.id IS NULL THEN
    RETURN jsonb_build_object('error', 'property_not_found', 'message', 'İlan bulunamadı veya yayında değil.');
  END IF;

  IF p_guests > v_prop.capacity THEN
    RETURN jsonb_build_object('error', 'capacity_exceeded', 'message', 'Misafir sayısı ilan kapasitesini aşamaz.');
  END IF;

  v_raw_total_minor := v_prop.nightly_minor * v_nights;

  -- Calculate campaign discount
  v_discount_calc := catalog.calculate_booking_discount(p_property_id, p_promo_code, p_check_in, p_check_out, v_raw_total_minor);
  IF (v_discount_calc->>'has_discount')::boolean THEN
    v_discount_minor := (v_discount_calc->>'discount_minor')::bigint;
    v_total_minor := (v_discount_calc->>'final_price_minor')::bigint;
    v_camp_name := coalesce(v_discount_calc->>'campaign_name', '');

    -- Increment usage
    UPDATE catalog.campaigns
    SET used_count = used_count + 1
    WHERE name = v_camp_name AND (property_id = p_property_id OR property_id IS NULL);
  ELSE
    v_total_minor := v_raw_total_minor;
  END IF;

  v_pnr := 'NX-' || to_char(now(), 'YYMM') || '-' || floor(random() * 89999 + 10000)::text;

  -- 1. PMS Assign available room if any
  SELECT * INTO v_unit FROM catalog.property_units 
  WHERE property_id = p_property_id AND occupancy_status = 'available'
  LIMIT 1;

  IF v_unit.id IS NOT NULL THEN
    UPDATE catalog.property_units
    SET occupancy_status = 'occupied',
        notes = 'Rezervasyon PNR: ' || v_pnr || ' - Misafir: ' || p_guest_name
    WHERE id = v_unit.id;
  END IF;

  -- 2. KBS Queue insertion
  v_dispatch := catalog.dispatch_kbs(
    p_property_id,
    p_guest_name,
    coalesce(nullif(p_tc, ''), '10000000000'),
    coalesce(v_unit.unit_code, 'Suit-1'),
    p_check_in,
    p_check_out
  );

  -- 3. WhatsApp Automated Voucher Confirmation
  PERFORM catalog.send_guest_whatsapp(
    p_property_id,
    p_guest_phone,
    'welcome',
    'Sayın ' || p_guest_name || ', ' || v_prop.title || ' rezervasyonunuz onaylanmıştır! PNR: ' || v_pnr || ', Giriş: ' || to_char(p_check_in, 'DD.MM.YYYY') || ', Çıkış: ' || to_char(p_check_out, 'DD.MM.YYYY') || ', Tutar: ' || (v_total_minor / 100)::text || ' ' || v_prop.currency || CASE WHEN v_discount_minor > 0 THEN ' (Kampanya İndirimi: -' || (v_discount_minor / 100)::text || ' ' || v_prop.currency || ')' ELSE '' END || '. İyi tatiller dileriz!'
  );

  -- 4. e-Fatura generation
  v_inv := catalog.generate_listing_invoice(p_property_id, p_guest_name, v_total_minor);

  RETURN jsonb_build_object(
    'status', 'ok',
    'pnr', v_pnr,
    'property_title', v_prop.title,
    'guest_name', p_guest_name,
    'check_in', p_check_in,
    'check_out', p_check_out,
    'nights', v_nights,
    'raw_total_minor', v_raw_total_minor,
    'discount_minor', v_discount_minor,
    'campaign_name', v_camp_name,
    'total_minor', v_total_minor,
    'currency', v_prop.currency,
    'room', coalesce(v_unit.unit_name, 'Özel Tahsis'),
    'kbs_code', v_dispatch,
    'invoice_no', v_inv
  );
END $$;

-- 8. Backward-compatible 8-parameter overload
CREATE OR REPLACE FUNCTION catalog.create_marketplace_booking(
  p_property_id uuid,
  p_guest_name text,
  p_guest_email text,
  p_guest_phone text,
  p_tc text,
  p_check_in date,
  p_check_out date,
  p_guests int
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT catalog.create_marketplace_booking(p_property_id, p_guest_name, p_guest_email, p_guest_phone, p_tc, p_check_in, p_check_out, p_guests, '');
$$;

-- 9. Seed Sample Initial Campaigns for Current Supplier Properties
DO $$
DECLARE
  v_tenant uuid;
  v_villa uuid;
  v_hotel uuid;
BEGIN
  SELECT id INTO v_tenant FROM core.organizations WHERE legal_name ILIKE '%tedarik%' OR id IN (SELECT tenant_id FROM catalog.properties) LIMIT 1;
  IF v_tenant IS NOT NULL THEN
    SELECT id INTO v_villa FROM catalog.properties WHERE tenant_id = v_tenant AND category_code = 'villa' LIMIT 1;
    SELECT id INTO v_hotel FROM catalog.properties WHERE tenant_id = v_tenant AND category_code = 'hotel' LIMIT 1;

    -- Campaign 1: Erken Rezervasyon (%15)
    INSERT INTO catalog.campaigns (tenant_id, name, campaign_type, discount_type, discount_val, min_stay_nights, days_in_advance, badge_text, usage_limit, used_count)
    VALUES (v_tenant, '2026 Yaz Erken Rezervasyon Fırsatı', 'early_bird', 'percentage', 15, 3, 30, '🔥 %15 Erken Rezervasyon', 200, 14)
    ON CONFLICT DO NOTHING;

    -- Campaign 2: YAZ2026 Kupon Kodu (%20)
    INSERT INTO catalog.campaigns (tenant_id, name, campaign_type, discount_type, discount_val, promo_code, badge_text, usage_limit, used_count)
    VALUES (v_tenant, 'Yaz Sezonu Özel Promosyon Kuponu', 'promo_code', 'percentage', 20, 'YAZ2026', '🏷️ YAZ2026 ile %20 İndirim', 100, 28)
    ON CONFLICT DO NOTHING;

    -- Campaign 3: 7 Gece ve Üzeri Uzun Konaklama (%10)
    INSERT INTO catalog.campaigns (tenant_id, name, campaign_type, discount_type, discount_val, min_stay_nights, badge_text, usage_limit, used_count)
    VALUES (v_tenant, 'Haftalık Uzun Konaklama Avantajı', 'long_stay', 'percentage', 10, 7, '🏡 7+ Geceye %10 İndirim', 150, 9)
    ON CONFLICT DO NOTHING;

    -- Campaign 4: Son Dakika Fırsatı (%25)
    IF v_villa IS NOT NULL THEN
      INSERT INTO catalog.campaigns (tenant_id, property_id, name, campaign_type, discount_type, discount_val, days_in_advance, badge_text, usage_limit, used_count)
      VALUES (v_tenant, v_villa, 'Villa Kaş Son Dakika İndirimi', 'last_minute', 'percentage', 25, 3, '⚡ Son Dakika %25', 50, 4)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

-- 10. Enhanced marketplace_listings with dynamic campaign badge & discount
CREATE OR REPLACE FUNCTION catalog.marketplace_listings(
  p_q text,
  p_category text,
  p_locality text
) RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.id::text,
    p.title,
    p.locality,
    p.category_code,
    p.capacity::text,
    p.nightly_minor::text,
    p.currency::text,
    p.description,
    coalesce(p.media->>0, 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80'),
    coalesce((SELECT string_agg(value#>>'{}', ', ') FROM jsonb_array_elements(p.amenities)), 'Wi-Fi, Havuz, Klima'),
    coalesce(c.name, p.category_code),
    coalesce((SELECT badge_text FROM catalog.campaigns cp WHERE cp.is_active = true AND cp.used_count < cp.usage_limit AND current_date BETWEEN cp.start_date AND cp.end_date AND (cp.property_id = p.id OR (cp.property_id IS NULL AND (cp.category_code IS NULL OR cp.category_code = p.category_code) AND cp.tenant_id = p.tenant_id)) ORDER BY cp.discount_val DESC LIMIT 1), ''),
    coalesce((SELECT discount_val::text FROM catalog.campaigns cp WHERE cp.is_active = true AND cp.used_count < cp.usage_limit AND current_date BETWEEN cp.start_date AND cp.end_date AND (cp.property_id = p.id OR (cp.property_id IS NULL AND (cp.category_code IS NULL OR cp.category_code = p.category_code) AND cp.tenant_id = p.tenant_id)) ORDER BY cp.discount_val DESC LIMIT 1), '0')
  ]
  FROM catalog.properties p
  LEFT JOIN onboarding.categories c ON c.code = p.category_code
  WHERE p.status = 'published'
    AND (p_category IS NULL OR p_category = '' OR p_category = 'all' OR p.category_code = p_category)
    AND (p_locality IS NULL OR p_locality = '' OR p.locality ILIKE '%' || p_locality || '%')
    AND (p_q IS NULL OR p_q = '' OR p.title ILIKE '%' || p_q || '%' OR p.description ILIKE '%' || p_q || '%' OR p.locality ILIKE '%' || p_q || '%')
  ORDER BY p.created_at DESC;
$$;

-- Grants
GRANT USAGE ON SCHEMA catalog TO nexus_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.campaigns TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.supplier_campaigns() TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.create_campaign(text, text, text, bigint, uuid, text, text, int, int, date, date, int, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.toggle_campaign(uuid, boolean) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.delete_campaign(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.listing_active_campaigns(uuid) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.calculate_booking_discount(uuid, text, date, date, bigint) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.create_marketplace_booking(uuid, text, text, text, text, date, date, int, text) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.create_marketplace_booking(uuid, text, text, text, text, date, date, int) TO nexus_app;
GRANT EXECUTE ON FUNCTION catalog.marketplace_listings(text, text, text) TO nexus_app;

