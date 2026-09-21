CREATE TABLE settings.supplier_ai_credentials (
  supplier_id uuid PRIMARY KEY REFERENCES core.organizations(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK(provider IN ('disabled','openai','anthropic','gemini','compatible')),
  token text NOT NULL DEFAULT '',
  base_url text NOT NULL DEFAULT '',
  model text NOT NULL DEFAULT '',
  monthly_budget_minor bigint NOT NULL DEFAULT 0 CHECK(monthly_budget_minor >= 0),
  version bigint NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NOT NULL REFERENCES auth.users(id)
);
ALTER TABLE settings.supplier_ai_credentials ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION settings.supplier_ai_list(p_supplier uuid) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[coalesce(c.provider,'disabled'),'',coalesce(c.base_url,''),coalesce(c.model,''),coalesce(c.monthly_budget_minor,0)::text,coalesce(c.version,0)::text]
 FROM (SELECT 1) x LEFT JOIN settings.supplier_ai_credentials c ON c.supplier_id=p_supplier
 WHERE auth.workspace()='nexus' AND EXISTS(SELECT 1 FROM core.organizations o WHERE o.id=p_supplier AND o.kind='supplier');
$$;

CREATE FUNCTION settings.supplier_ai_save(p_supplier uuid,p_provider text,p_token text,p_base_url text,p_model text,p_budget bigint,p_version bigint)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()<>'nexus' OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.role='owner') THEN RETURN 'forbidden'; END IF;
 IF NOT EXISTS(SELECT 1 FROM core.organizations WHERE id=p_supplier AND kind='supplier') OR p_provider NOT IN ('disabled','openai','anthropic','gemini','compatible') OR p_budget<0 THEN RETURN 'invalid'; END IF;
 INSERT INTO settings.supplier_ai_credentials(supplier_id,provider,token,base_url,model,monthly_budget_minor,version,updated_by) VALUES(p_supplier,p_provider,p_token,p_base_url,p_model,p_budget,p_version+1,nullif(current_setting('app.actor_id',true),'')::uuid)
 ON CONFLICT(supplier_id) DO UPDATE SET provider=EXCLUDED.provider,token=CASE WHEN EXCLUDED.token='' THEN settings.supplier_ai_credentials.token ELSE EXCLUDED.token END,base_url=EXCLUDED.base_url,model=EXCLUDED.model,monthly_budget_minor=EXCLUDED.monthly_budget_minor,version=EXCLUDED.version,updated_at=now(),updated_by=EXCLUDED.updated_by;
 RETURN 'ok';
END $$;
GRANT EXECUTE ON FUNCTION settings.supplier_ai_list(uuid),settings.supplier_ai_save(uuid,text,text,text,text,bigint,bigint) TO nexus_app;
