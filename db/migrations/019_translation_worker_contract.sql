CREATE OR REPLACE FUNCTION cms.claim_translation_jobs(p_limit integer DEFAULT 10)
RETURNS TABLE(id uuid, slug text, source_locale text, target_locale text, source_version bigint, attempts integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT cms.can_edit() THEN RETURN; END IF;
  RETURN QUERY
  WITH picked AS (
    SELECT j.id
    FROM cms.translation_jobs j
    WHERE j.status IN ('queued','retry') AND j.attempts < 5
    ORDER BY j.created_at
    FOR UPDATE SKIP LOCKED
    LIMIT greatest(1, least(p_limit, 100))
  )
  UPDATE cms.translation_jobs j
     SET status='processing', attempts=j.attempts+1, started_at=now(), error=NULL
    FROM picked
   WHERE j.id=picked.id
  RETURNING j.id,j.slug,j.source_locale,j.target_locale,j.source_version,j.attempts;
END $$;

CREATE OR REPLACE FUNCTION cms.complete_translation_job(
  p_id uuid, p_title text, p_summary text, p_body text, p_provider text DEFAULT 'ai'
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE j cms.translation_jobs%ROWTYPE;
BEGIN
  IF NOT cms.can_edit() THEN RETURN 'forbidden'; END IF;
  SELECT * INTO j FROM cms.translation_jobs WHERE id=p_id FOR UPDATE;
  IF NOT FOUND OR j.status <> 'processing' THEN RETURN 'not_found'; END IF;
  UPDATE cms.translation_jobs SET status='completed', completed_at=now(), provider=p_provider, error=NULL WHERE id=p_id;
  UPDATE cms.translations SET title=coalesce(p_title,''), summary=coalesce(p_summary,''), body=coalesce(p_body,''), status='translated', translated_by=p_provider, updated_at=now()
   WHERE slug=j.slug AND locale=j.target_locale AND version=j.source_version;
  RETURN 'completed';
END $$;

CREATE OR REPLACE FUNCTION cms.fail_translation_job(p_id uuid, p_error text, p_retry boolean DEFAULT true)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT cms.can_edit() THEN RETURN 'forbidden'; END IF;
  UPDATE cms.translation_jobs SET status=CASE WHEN p_retry AND attempts < 5 THEN 'retry' ELSE 'failed' END, error=left(coalesce(p_error,'unknown error'),1000), completed_at=CASE WHEN NOT (p_retry AND attempts < 5) THEN now() ELSE NULL END WHERE id=p_id AND status='processing';
  RETURN CASE WHEN FOUND THEN 'updated' ELSE 'not_found' END;
END $$;

GRANT EXECUTE ON FUNCTION cms.claim_translation_jobs(integer),cms.complete_translation_job(uuid,text,text,text,text),cms.fail_translation_job(uuid,text,boolean) TO nexus_app;
