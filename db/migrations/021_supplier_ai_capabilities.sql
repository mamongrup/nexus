ALTER TABLE settings.supplier_ai_credentials DROP CONSTRAINT IF EXISTS supplier_ai_credentials_provider_check;
ALTER TABLE settings.supplier_ai_credentials ADD CONSTRAINT supplier_ai_credentials_provider_check CHECK(provider IN ('disabled','openai','anthropic','gemini','deepseek','compatible'));
ALTER TABLE settings.supplier_ai_credentials
  ADD COLUMN IF NOT EXISTS visual_provider text NOT NULL DEFAULT 'disabled',
  ADD COLUMN IF NOT EXISTS writing_provider text NOT NULL DEFAULT 'disabled',
  ADD COLUMN IF NOT EXISTS content_provider text NOT NULL DEFAULT 'disabled',
  ADD COLUMN IF NOT EXISTS seo_provider text NOT NULL DEFAULT 'disabled';
ALTER TABLE settings.supplier_ai_credentials
  ADD CONSTRAINT supplier_ai_capability_provider_check CHECK (visual_provider IN ('disabled','openai','anthropic','gemini','deepseek','compatible') AND writing_provider IN ('disabled','openai','anthropic','gemini','deepseek','compatible') AND content_provider IN ('disabled','openai','anthropic','gemini','deepseek','compatible') AND seo_provider IN ('disabled','openai','anthropic','gemini','deepseek','compatible'));

CREATE OR REPLACE FUNCTION settings.supplier_ai_list(p_supplier uuid) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[coalesce(c.provider,'disabled'),'','',coalesce(c.base_url,''),coalesce(c.model,''),coalesce(c.monthly_budget_minor,0)::text,coalesce(c.version,0)::text,coalesce(c.visual_provider,'disabled'),coalesce(c.writing_provider,'disabled'),coalesce(c.content_provider,'disabled'),coalesce(c.seo_provider,'disabled')]
 FROM (SELECT 1) x LEFT JOIN settings.supplier_ai_credentials c ON c.supplier_id=p_supplier
 WHERE auth.workspace()='nexus' AND EXISTS(SELECT 1 FROM core.organizations o WHERE o.id=p_supplier AND o.kind='supplier');
$$;

CREATE OR REPLACE FUNCTION settings.supplier_ai_save(p_supplier uuid,p_provider text,p_token text,p_base_url text,p_model text,p_budget bigint,p_version bigint,p_visual text DEFAULT 'disabled',p_writing text DEFAULT 'disabled',p_content text DEFAULT 'disabled',p_seo text DEFAULT 'disabled')
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()<>'nexus' OR NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=nullif(current_setting('app.actor_id',true),'')::uuid AND u.role='owner') THEN RETURN 'forbidden'; END IF;
 IF NOT EXISTS(SELECT 1 FROM core.organizations WHERE id=p_supplier AND kind='supplier') OR p_provider NOT IN ('disabled','openai','anthropic','gemini','deepseek','compatible') OR p_visual NOT IN ('disabled','openai','anthropic','gemini','deepseek','compatible') OR p_writing NOT IN ('disabled','openai','anthropic','gemini','deepseek','compatible') OR p_content NOT IN ('disabled','openai','anthropic','gemini','deepseek','compatible') OR p_seo NOT IN ('disabled','openai','anthropic','gemini','deepseek','compatible') OR p_budget<0 THEN RETURN 'invalid'; END IF;
 INSERT INTO settings.supplier_ai_credentials(supplier_id,provider,token,base_url,model,monthly_budget_minor,version,visual_provider,writing_provider,content_provider,seo_provider,updated_by) VALUES(p_supplier,p_provider,p_token,p_base_url,p_model,p_budget,p_version+1,p_visual,p_writing,p_content,p_seo,nullif(current_setting('app.actor_id',true),'')::uuid)
 ON CONFLICT(supplier_id) DO UPDATE SET provider=EXCLUDED.provider,token=CASE WHEN EXCLUDED.token='' THEN settings.supplier_ai_credentials.token ELSE EXCLUDED.token END,base_url=EXCLUDED.base_url,model=EXCLUDED.model,monthly_budget_minor=EXCLUDED.monthly_budget_minor,version=EXCLUDED.version,visual_provider=EXCLUDED.visual_provider,writing_provider=EXCLUDED.writing_provider,content_provider=EXCLUDED.content_provider,seo_provider=EXCLUDED.seo_provider,updated_at=now(),updated_by=EXCLUDED.updated_by;
 RETURN 'ok';
END $$;
