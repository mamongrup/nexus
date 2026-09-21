CREATE TABLE IF NOT EXISTS partners.partner_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  partner_id uuid NOT NULL REFERENCES core.organizations(id),
  supplier_health_score int NOT NULL DEFAULT 85 CHECK(supplier_health_score BETWEEN 0 AND 100),
  agency_health_score int NOT NULL DEFAULT 80 CHECK(agency_health_score BETWEEN 0 AND 100),
  listing_quality_score int NOT NULL DEFAULT 90 CHECK(listing_quality_score BETWEEN 0 AND 100),
  trust_score int NOT NULL DEFAULT 95 CHECK(trust_score BETWEEN 0 AND 100),
  commercial_score int NOT NULL DEFAULT 75 CHECK(commercial_score BETWEEN 0 AND 100),
  risk_score int NOT NULL DEFAULT 10 CHECK(risk_score BETWEEN 0 AND 100),
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, partner_id)
);

CREATE OR REPLACE FUNCTION organization.digital_twin(p_org_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  target_id uuid;
  org core.organizations%ROWTYPE;
  prod_count int;
  published_count int;
  hold_count int;
  res_count int;
  gross_rev bigint;
  pending_payout bigint;
  scores partners.partner_scores%ROWTYPE;
  cf_7d bigint;
  cf_30d bigint;
  cf_90d bigint;
BEGIN
  target_id := coalesce(nullif(p_org_id, '')::uuid, nullif(current_setting('app.tenant_id', true), '')::uuid);
  SELECT * INTO org FROM core.organizations WHERE id = target_id;
  IF org.id IS NULL THEN
    RETURN jsonb_build_object('error', 'org_not_found');
  END IF;

  SELECT count(*), count(*) FILTER (WHERE status = 'published')
  INTO prod_count, published_count
  FROM catalog.properties WHERE tenant_id = target_id;

  SELECT count(*) INTO hold_count
  FROM booking.holds
  WHERE tenant_id = target_id AND status = 'active' AND expires_at > clock_timestamp();

  SELECT count(*), coalesce(sum(total_minor), 0)
  INTO res_count, gross_rev
  FROM booking.reservations
  WHERE (tenant_id = target_id OR agency_id = target_id) AND status <> 'cancelled';

  SELECT coalesce(sum(supplier_net_minor), 0)
  INTO pending_payout
  FROM finance.settlements
  WHERE supplier_id = target_id AND status = 'pending';

  SELECT * INTO scores
  FROM partners.partner_scores
  WHERE partner_id = target_id
  LIMIT 1;

  -- 7 / 30 / 90 days projected cash flow
  cf_7d := (gross_rev * 15) / 100;
  cf_30d := (gross_rev * 65) / 100;
  cf_90d := (gross_rev * 140) / 100;

  RETURN jsonb_build_object(
    'organization_id', org.id,
    'legal_name', org.legal_name,
    'kind', org.kind,
    'products_total', prod_count,
    'products_published', published_count,
    'active_holds', hold_count,
    'total_reservations', res_count,
    'gross_revenue_minor', gross_rev,
    'pending_payout_minor', pending_payout,
    'health_score', coalesce(scores.supplier_health_score, 88),
    'quality_score', coalesce(scores.listing_quality_score, 92),
    'trust_score', coalesce(scores.trust_score, 95),
    'risk_score', coalesce(scores.risk_score, 8),
    'cashflow_forecast_7d_minor', cf_7d,
    'cashflow_forecast_30d_minor', cf_30d,
    'cashflow_forecast_90d_minor', cf_90d
  );
END $$;

CREATE OR REPLACE FUNCTION organization.digital_twin_cards()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    o.id::text,
    o.legal_name,
    o.kind,
    coalesce(ps.supplier_health_score, 88)::text,
    coalesce(ps.trust_score, 94)::text,
    coalesce(ps.risk_score, 8)::text,
    coalesce(counts.prod_cnt, 0)::text,
    coalesce(counts.res_cnt, 0)::text,
    (coalesce(counts.rev_minor, 0) / 100.0)::text
  ]
  FROM core.organizations o
  LEFT JOIN partners.partner_scores ps ON ps.partner_id = o.id
  LEFT JOIN (
    SELECT p.tenant_id,
           count(DISTINCT p.id) as prod_cnt,
           count(DISTINCT r.id) as res_cnt,
           coalesce(sum(r.total_minor), 0) as rev_minor
    FROM catalog.properties p
    LEFT JOIN booking.reservations r ON r.tenant_id = p.tenant_id AND r.status <> 'cancelled'
    GROUP BY p.tenant_id
  ) counts ON counts.tenant_id = o.id
  WHERE o.id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  ORDER BY o.legal_name;
$$;
