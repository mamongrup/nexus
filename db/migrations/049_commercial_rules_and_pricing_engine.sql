CREATE SCHEMA IF NOT EXISTS pricing;

CREATE TABLE IF NOT EXISTS pricing.commercial_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  rule_name text NOT NULL,
  rule_type text NOT NULL CHECK(rule_type IN (
    'supplier_default', 'product_rule', 'agency_rule', 'channel_rule',
    'date_rule', 'contract_rule', 'volume_tier'
  )),
  priority int NOT NULL DEFAULT 10,
  target_agency_id uuid REFERENCES core.organizations(id),
  target_property_id uuid,
  channel text CHECK(channel IN ('b2c', 'agency', 'api', 'white_label')),
  commission_rate_bps int NOT NULL DEFAULT 1000 CHECK(commission_rate_bps BETWEEN 0 AND 5000), -- 1000 = 10.00%
  markup_rate_bps int NOT NULL DEFAULT 0 CHECK(markup_rate_bps BETWEEN 0 AND 5000), -- e.g. 500 = 5.00%
  nexus_take_bps int NOT NULL DEFAULT 300 CHECK(nexus_take_bps BETWEEN 0 AND 2000), -- 300 = 3.00%
  tax_rate_bps int NOT NULL DEFAULT 1000 CHECK(tax_rate_bps BETWEEN 0 AND 3000), -- 1000 = 10.00% KDV
  start_date date,
  end_date date,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, target_property_id) REFERENCES catalog.properties(tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS pricing.quote_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  property_id uuid NOT NULL,
  agency_id uuid REFERENCES core.organizations(id),
  channel text NOT NULL DEFAULT 'agency',
  currency character(3) NOT NULL REFERENCES core.currencies(code),
  nights int NOT NULL CHECK(nights > 0),
  list_price_minor bigint NOT NULL CHECK(list_price_minor > 0),
  supplier_commission_bps int NOT NULL DEFAULT 1000,
  supplier_net_minor bigint NOT NULL CHECK(supplier_net_minor > 0),
  nexus_fee_bps int NOT NULL DEFAULT 300,
  nexus_fee_minor bigint NOT NULL DEFAULT 0,
  agency_markup_bps int NOT NULL DEFAULT 0,
  agency_markup_minor bigint NOT NULL DEFAULT 0,
  tax_rate_bps int NOT NULL DEFAULT 1000,
  tax_minor bigint NOT NULL DEFAULT 0,
  customer_price_minor bigint NOT NULL CHECK(customer_price_minor > 0),
  rule_applied text NOT NULL DEFAULT 'supplier_default',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION pricing.calculate_offer(
  p_property text,
  p_agency text,
  p_channel text,
  p_start text,
  p_end text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  prop catalog.properties%ROWTYPE;
  start_d date := p_start::date;
  end_d date := p_end::date;
  num_nights int;
  base_nightly bigint;
  list_price bigint;
  agency_uuid uuid := nullif(p_agency, '')::uuid;
  active_rule pricing.commercial_rules%ROWTYPE;
  comm_bps int := 1000;
  markup_bps int := 0;
  nexus_bps int := 300;
  tax_bps int := 1000;
  supplier_net bigint;
  nexus_fee bigint;
  agency_markup bigint;
  tax_amount bigint;
  customer_price bigint;
  rule_name text := 'supplier_default';
BEGIN
  IF end_d <= start_d THEN
    RETURN jsonb_build_object('error', 'invalid_dates');
  END IF;
  num_nights := end_d - start_d;

  SELECT * INTO prop FROM catalog.properties WHERE id::text = p_property;
  IF prop.id IS NULL THEN
    RETURN jsonb_build_object('error', 'property_not_found');
  END IF;

  base_nightly := prop.nightly_minor;
  list_price := base_nightly * num_nights;

  -- Rule resolution hierarchy: contract > date > channel > agency > product > default
  SELECT * INTO active_rule
  FROM pricing.commercial_rules
  WHERE tenant_id = prop.tenant_id
    AND active = true
    AND (target_property_id IS NULL OR target_property_id = prop.id)
    AND (target_agency_id IS NULL OR target_agency_id = agency_uuid)
    AND (channel IS NULL OR channel = coalesce(p_channel, 'agency'))
    AND (start_date IS NULL OR start_date <= start_d)
    AND (end_date IS NULL OR end_date >= end_d)
  ORDER BY priority DESC, created_at DESC
  LIMIT 1;

  IF active_rule.id IS NOT NULL THEN
    comm_bps := active_rule.commission_rate_bps;
    markup_bps := active_rule.markup_rate_bps;
    nexus_bps := active_rule.nexus_take_bps;
    tax_bps := active_rule.tax_rate_bps;
    rule_name := active_rule.rule_type || ':' || active_rule.rule_name;
  END IF;

  -- Formula from PDF Blueprint Page 8:
  -- LIST PRICE / COST
  -- -> Supplier Commission Rule
  -- -> Supplier Net / NEXUS Cost
  -- -> NEXUS Commercial Rules
  -- -> Agency Markup / Special Commission
  -- -> Taxes / Fees
  -- -> Customer Sell Price
  supplier_net := list_price - ((list_price * comm_bps) / 10000);
  nexus_fee := (list_price * nexus_bps) / 10000;
  agency_markup := (list_price * markup_bps) / 10000;
  tax_amount := ((supplier_net + nexus_fee + agency_markup) * tax_bps) / 10000;
  customer_price := supplier_net + nexus_fee + agency_markup + tax_amount;

  RETURN jsonb_build_object(
    'property_id', prop.id,
    'property_title', prop.title,
    'nights', num_nights,
    'currency', prop.currency,
    'list_price_minor', list_price,
    'supplier_commission_bps', comm_bps,
    'supplier_net_minor', supplier_net,
    'nexus_fee_bps', nexus_bps,
    'nexus_fee_minor', nexus_fee,
    'agency_markup_bps', markup_bps,
    'agency_markup_minor', agency_markup,
    'tax_rate_bps', tax_bps,
    'tax_minor', tax_amount,
    'customer_price_minor', customer_price,
    'rule_applied', rule_name
  );
END $$;

CREATE OR REPLACE FUNCTION pricing.rules_directory()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    r.id::text,
    r.rule_name,
    r.rule_type,
    r.priority::text,
    coalesce(r.channel, 'all'),
    (r.commission_rate_bps / 100.0)::text || '%',
    (r.markup_rate_bps / 100.0)::text || '%',
    (r.nexus_take_bps / 100.0)::text || '%',
    case when r.active then 'Aktif' else 'Pasif' end
  ]
  FROM pricing.commercial_rules r
  WHERE r.tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  ORDER BY r.priority DESC, r.rule_name;
$$;
