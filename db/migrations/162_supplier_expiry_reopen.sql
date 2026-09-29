-- An accepted document can expire after approval without another user action.
-- Reopen those applications for review and remove them from publishable status.
CREATE OR REPLACE FUNCTION onboarding.reopen_expired_applications()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_count integer;
BEGIN
  WITH changed AS (
    UPDATE onboarding.applications a SET status='review',updated_at=now()
    WHERE a.status='approved' AND EXISTS (
      SELECT 1 FROM onboarding.documents d
      JOIN onboarding.requirements r ON r.id=d.requirement_id
      WHERE d.application_id=a.id AND r.category_code=a.category_code
        AND r.required AND d.status='accepted' AND d.expires_on<current_date
    )
    RETURNING a.id,a.tenant_id
  ), audited AS (
    INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
    SELECT c.tenant_id,NULL,'onboarding.document_expired',c.id,
      jsonb_build_object('reason','required_document_expired') FROM changed c
    RETURNING 1
  ) SELECT count(*) INTO v_count FROM audited;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION onboarding.reopen_expired_applications() FROM PUBLIC;
