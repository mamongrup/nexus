CREATE FUNCTION catalog.enforce_supplier_category_approval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF auth.workspace()='supplier' AND NOT EXISTS(
   SELECT FROM onboarding.applications a
   WHERE a.tenant_id=NEW.tenant_id AND a.owner_user_id=nullif(current_setting('app.actor_id',true),'')::uuid
   AND a.category_code=NEW.category_code AND a.status='approved'
 ) THEN RAISE EXCEPTION 'Supplier is not approved for category %',NEW.category_code USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER supplier_category_approval BEFORE INSERT OR UPDATE OF category_code ON catalog.properties
FOR EACH ROW EXECUTE FUNCTION catalog.enforce_supplier_category_approval();
REVOKE ALL ON FUNCTION catalog.enforce_supplier_category_approval() FROM PUBLIC;
