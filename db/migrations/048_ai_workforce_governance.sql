CREATE TABLE IF NOT EXISTS ai.workforce_roles (
  role_code text PRIMARY KEY,
  tier text NOT NULL CHECK(tier IN ('worker','manager','director','general_manager')),
  title text NOT NULL,
  supervisor_role text REFERENCES ai.workforce_roles(role_code),
  default_authority text NOT NULL CHECK(default_authority IN ('AUTO','RECOMMEND','APPROVAL','HUMAN_ONLY')),
  responsibilities text NOT NULL
);

INSERT INTO ai.workforce_roles(role_code, tier, title, supervisor_role, default_authority, responsibilities) VALUES
  ('ai_general_manager', 'general_manager', 'AI General Manager', NULL, 'APPROVAL', 'En üst düzey operasyonel yönetim, 5 kritik risk/fırsat takibi, koordinasyon'),
  ('commercial_director', 'director', 'Commercial Director', 'ai_general_manager', 'APPROVAL', 'Fiyatlandırma, komisyon, acente ilişkileri ve ticari strateji'),
  ('operations_director', 'director', 'Operations Director', 'ai_general_manager', 'APPROVAL', 'Rezervasyonlar, takvim, tedarikçi operasyonları ve SLA takibi'),
  ('finance_director', 'director', 'Finance Director', 'ai_general_manager', 'APPROVAL', 'Ledger, mutabakat, hakedişler ve nakit akışı kontrolü'),
  ('technology_director', 'director', 'Technology Director', 'ai_general_manager', 'APPROVAL', 'API entegrasyonları, sağlayıcı sağlığı ve sistem güvenilirliği'),
  ('risk_compliance_director', 'director', 'Risk & Compliance Director', 'ai_general_manager', 'APPROVAL', 'Dolandırıcılık tespiti, KVKK/uyumluluk ve yetki denetimi'),
  ('price_guardian', 'worker', 'Price Guardian', 'commercial_director', 'RECOMMEND', 'Piyasa fiyat analizi, anomali tespiti ve dinamik fiyat önerisi'),
  ('sales_agent', 'worker', 'AI Sales Agent', 'commercial_director', 'RECOMMEND', 'Teklif hazırlama, acente iletişimi ve talep takibi'),
  ('listing_worker', 'worker', 'Listing Worker & QA', 'operations_director', 'AUTO', 'İlan normalizasyonu, veri çıkarma ve eksik analizi'),
  ('reservation_manager', 'manager', 'Reservation Manager', 'operations_director', 'RECOMMEND', 'Bekleyen rezervasyonlar, opsiyon süreleri ve onay iş akışı'),
  ('finance_manager', 'manager', 'Finance Manager', 'finance_director', 'RECOMMEND', 'Çift taraflı kayıt denetimi, bakiye doğrulama ve anomali tespiti'),
  ('api_monitor', 'worker', 'API & Connectivity Monitor', 'technology_director', 'AUTO', 'Dış sağlayıcı gecikme ve hata oranları izleme, devre kesici uyarısı'),
  ('risk_agent', 'worker', 'Risk & Compliance Agent', 'risk_compliance_director', 'APPROVAL', 'Yüksek tutarlı iade ve şüpheli işlem kontrolü')
ON CONFLICT (role_code) DO UPDATE SET
  tier = EXCLUDED.tier,
  title = EXCLUDED.title,
  default_authority = EXCLUDED.default_authority,
  responsibilities = EXCLUDED.responsibilities;

CREATE TABLE IF NOT EXISTS ai.actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  role_code text NOT NULL REFERENCES ai.workforce_roles(role_code),
  action_type text NOT NULL CHECK(action_type IN (
    'CREATE_LISTING', 'UPDATE_PRICE', 'HOLD_INVENTORY', 'CREATE_BOOKING',
    'REQUEST_APPROVAL', 'SEND_MESSAGE', 'RECONCILE_PAYMENT', 'FLAG_RISK'
  )),
  authority_level text NOT NULL CHECK(authority_level IN ('AUTO','RECOMMEND','APPROVAL','HUMAN_ONLY')),
  status text NOT NULL DEFAULT 'pending_approval' CHECK(status IN ('pending_approval','approved','rejected','executed','overridden')),
  risk_score int NOT NULL DEFAULT 0 CHECK(risk_score BETWEEN 0 AND 100),
  confidence_score int NOT NULL DEFAULT 90 CHECK(confidence_score BETWEEN 0 AND 100),
  resource_id text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  outcome jsonb NOT NULL DEFAULT '{}'::jsonb,
  justification text NOT NULL DEFAULT '',
  decision_notes text,
  decided_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  executed_at timestamptz
);

CREATE TABLE IF NOT EXISTS ai.executive_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES core.organizations(id),
  insight_type text NOT NULL CHECK(insight_type IN ('risk','opportunity')),
  title text NOT NULL,
  description text NOT NULL,
  action_owner text NOT NULL REFERENCES ai.workforce_roles(role_code),
  deadline date NOT NULL DEFAULT (CURRENT_DATE + 7),
  expected_impact text NOT NULL,
  priority int NOT NULL DEFAULT 1 CHECK(priority BETWEEN 1 AND 5),
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','mitigated','dismissed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION ai.post_action(
  p_role text,
  p_action_type text,
  p_resource text,
  p_payload jsonb,
  p_risk int,
  p_justification text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id',true),'')::uuid;
  u uuid := nullif(current_setting('app.actor_id',true),'')::uuid;
  r ai.workforce_roles%ROWTYPE;
  act_id uuid;
  final_auth text;
  final_status text;
BEGIN
  IF t IS NULL THEN RETURN 'forbidden'; END IF;
  SELECT * INTO r FROM ai.workforce_roles WHERE role_code = p_role;
  IF r.role_code IS NULL THEN RETURN 'invalid_role'; END IF;

  final_auth := r.default_authority;
  IF p_risk > 60 THEN
    final_auth := 'APPROVAL';
  ELSIF p_risk > 85 THEN
    final_auth := 'HUMAN_ONLY';
  END IF;

  IF final_auth = 'AUTO' AND p_risk <= 20 THEN
    final_status := 'executed';
  ELSE
    final_status := 'pending_approval';
  END IF;

  INSERT INTO ai.actions(
    tenant_id, role_code, action_type, authority_level, status,
    risk_score, resource_id, payload, justification, executed_at
  ) VALUES (
    t, p_role, p_action_type, final_auth, final_status,
    coalesce(p_risk, 10), p_resource, coalesce(p_payload, '{}'::jsonb),
    coalesce(p_justification, 'AI workforce recommendation'),
    CASE WHEN final_status = 'executed' THEN now() ELSE NULL END
  ) RETURNING id INTO act_id;

  INSERT INTO events.audit(tenant_id, actor_id, action, resource_id, payload)
  VALUES (t, u, 'ai.action.' || lower(final_status), act_id, jsonb_build_object(
    'role', p_role, 'action_type', p_action_type, 'authority', final_auth, 'risk', p_risk
  ));

  RETURN final_status;
END $$;

CREATE OR REPLACE FUNCTION ai.decide_action(
  p_action_id text,
  p_decision text,
  p_notes text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  t uuid := nullif(current_setting('app.tenant_id',true),'')::uuid;
  u uuid := nullif(current_setting('app.actor_id',true),'')::uuid;
  act ai.actions%ROWTYPE;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = u AND tenant_id = t AND role IN ('owner','editor')) THEN
    RETURN 'forbidden';
  END IF;
  IF p_decision NOT IN ('approved','rejected','overridden') THEN
    RETURN 'invalid_decision';
  END IF;

  SELECT * INTO act FROM ai.actions WHERE id::text = p_action_id AND (tenant_id = t OR auth.workspace() = 'nexus');
  IF act.id IS NULL THEN RETURN 'not_found'; END IF;
  IF act.status <> 'pending_approval' THEN RETURN 'already_decided'; END IF;

  UPDATE ai.actions
  SET status = CASE WHEN p_decision = 'approved' THEN 'executed' ELSE p_decision END,
      decided_by = u,
      decision_notes = left(coalesce(p_notes, ''), 1000),
      executed_at = CASE WHEN p_decision = 'approved' THEN now() ELSE NULL END
  WHERE id = act.id;

  INSERT INTO events.audit(tenant_id, actor_id, action, resource_id, payload)
  VALUES (t, u, 'ai.action.' || p_decision, act.id, jsonb_build_object(
    'role', act.role_code, 'action_type', act.action_type, 'notes', p_notes
  ));

  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION ai.workforce_overview()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    r.role_code,
    r.title,
    r.tier,
    r.default_authority,
    coalesce(cnt.pending_count, 0)::text,
    coalesce(cnt.executed_count, 0)::text
  ]
  FROM ai.workforce_roles r
  LEFT JOIN (
    SELECT role_code,
           count(*) FILTER (WHERE status = 'pending_approval') as pending_count,
           count(*) FILTER (WHERE status = 'executed') as executed_count
    FROM ai.actions
    WHERE tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
       OR auth.workspace() = 'nexus'
    GROUP BY role_code
  ) cnt ON cnt.role_code = r.role_code
  ORDER BY CASE r.tier
    WHEN 'general_manager' THEN 1
    WHEN 'director' THEN 2
    WHEN 'manager' THEN 3
    ELSE 4
  END, r.title;
$$;

CREATE OR REPLACE FUNCTION ai.actions_feed()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.id::text,
    r.title,
    a.action_type,
    a.authority_level,
    a.status,
    a.risk_score::text,
    coalesce(a.resource_id, '-'),
    a.justification,
    to_char(a.created_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
  ]
  FROM ai.actions a
  JOIN ai.workforce_roles r ON r.role_code = a.role_code
  WHERE a.tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  ORDER BY a.created_at DESC
  LIMIT 50;
$$;

CREATE OR REPLACE FUNCTION ai.executive_dashboard()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    i.id::text,
    i.insight_type,
    i.title,
    i.description,
    r.title,
    to_char(i.deadline, 'DD.MM.YYYY'),
    i.expected_impact,
    i.priority::text,
    i.status
  ]
  FROM ai.executive_insights i
  JOIN ai.workforce_roles r ON r.role_code = i.action_owner
  WHERE i.tenant_id = nullif(current_setting('app.tenant_id',true),'')::uuid
     OR auth.workspace() = 'nexus'
  ORDER BY i.priority ASC, i.deadline ASC
  LIMIT 5;
$$;
