-- Supplier inventory must leave the storefront when category approval is lost.
CREATE OR REPLACE FUNCTION catalog.pause_listings_on_supplier_approval_loss()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF OLD.status='approved' AND NEW.status<>'approved'
    AND NOT EXISTS(SELECT 1 FROM onboarding.applications a
      WHERE a.id<>NEW.id AND a.tenant_id=NEW.tenant_id
        AND a.category_code=NEW.category_code AND a.status='approved')
  THEN
    WITH changed AS (
      UPDATE catalog.properties p SET status='draft',moderation_status='suspended',
        version=version+1,updated_at=now()
      WHERE p.tenant_id=NEW.tenant_id AND p.category_code=NEW.category_code
        AND p.status='published'
      RETURNING p.id
    )
    INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
    SELECT NEW.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,
      'property.paused_supplier_approval_lost',c.id,
      jsonb_build_object('application_id',NEW.id,'application_status',NEW.status)
    FROM changed c;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS supplier_listing_approval_loss ON onboarding.applications;
CREATE TRIGGER supplier_listing_approval_loss AFTER UPDATE OF status ON onboarding.applications
FOR EACH ROW WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION catalog.pause_listings_on_supplier_approval_loss();

CREATE OR REPLACE FUNCTION catalog.guard_supplier_publication_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.status='published'
    AND EXISTS(SELECT 1 FROM core.organizations o WHERE o.id=NEW.tenant_id AND o.kind='supplier')
    AND NOT EXISTS(SELECT 1 FROM onboarding.applications a
      WHERE a.tenant_id=NEW.tenant_id AND a.category_code=NEW.category_code AND a.status='approved')
  THEN RAISE EXCEPTION 'supplier_not_approved' USING ERRCODE='42501'; END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS supplier_publication_status_guard ON catalog.properties;
CREATE TRIGGER supplier_publication_status_guard
BEFORE INSERT OR UPDATE OF status,category_code ON catalog.properties
FOR EACH ROW EXECUTE FUNCTION catalog.guard_supplier_publication_status();
