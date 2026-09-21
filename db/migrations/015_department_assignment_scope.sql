CREATE OR REPLACE FUNCTION organization.assign(p_org text,p_workspace text,p_code text,p_status text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT ((auth.workspace()='nexus' AND onboarding.operator()) OR (auth.workspace()='supplier' AND p_workspace='supplier' AND p_org=nullif(current_setting('app.tenant_id',true),'')::text)) OR p_workspace NOT IN ('nexus','supplier') OR p_status NOT IN ('active','paused') THEN RETURN 'forbidden'; END IF;
 IF NOT EXISTS(SELECT FROM core.organizations WHERE id::text=p_org AND kind=p_workspace) OR NOT EXISTS(SELECT FROM organization.departments WHERE workspace=p_workspace AND code=p_code) THEN RETURN 'not_found'; END IF;
 INSERT INTO organization.org_departments(organization_id,department_code,workspace,status,lead_user_id) VALUES(p_org::uuid,p_code,p_workspace,p_status,nullif(current_setting('app.actor_id',true),'')::uuid) ON CONFLICT(organization_id,department_code) DO UPDATE SET status=EXCLUDED.status,lead_user_id=EXCLUDED.lead_user_id;
 RETURN 'ok';
END $$;
