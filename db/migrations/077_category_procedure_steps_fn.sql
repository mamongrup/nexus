-- 077_category_procedure_steps_fn.sql
-- Function to extract structured procedure steps for UI rendering without client-side JSON parsing

CREATE OR REPLACE FUNCTION onboarding.get_category_procedure_steps(p_category text)
RETURNS TABLE(step_no text, step_title text, step_desc text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT 
    (elem->>'step')::text,
    coalesce((elem->>'title')::text, ''),
    coalesce((elem->>'desc')::text, '')
  FROM onboarding.category_procedures p,
  LATERAL jsonb_array_elements(p.steps) elem
  WHERE p.category_code = p_category
  ORDER BY (elem->>'step')::int;
$$;

GRANT EXECUTE ON FUNCTION onboarding.get_category_procedure_steps(text) TO nexus_app;
