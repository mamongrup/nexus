-- 075_harmonize_supplier_category_gate.sql
-- Allow newly onboarded suppliers without application records to create draft listings

CREATE OR REPLACE FUNCTION onboarding.categories_for_listing() RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[c.code,c.name,c.description] FROM onboarding.categories c
 WHERE c.active AND (
   onboarding.operator() 
   OR EXISTS(
     SELECT FROM onboarding.applications a WHERE a.category_code=c.code AND a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
     AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid AND a.status='approved'
   )
   OR NOT EXISTS(
     SELECT FROM onboarding.applications a WHERE a.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid
   )
 )
 ORDER BY c.name
$$;

CREATE OR REPLACE FUNCTION catalog.enforce_supplier_category_approval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()='supplier' AND EXISTS(
   SELECT FROM onboarding.applications a WHERE a.tenant_id=NEW.tenant_id
 ) AND NOT EXISTS(
   SELECT FROM onboarding.applications a
   WHERE a.tenant_id=NEW.tenant_id AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid
   AND a.category_code=NEW.category_code AND a.status='approved'
 ) THEN RAISE EXCEPTION 'Supplier is not approved for category %',NEW.category_code USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
