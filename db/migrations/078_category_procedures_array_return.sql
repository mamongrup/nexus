-- 078_category_procedures_array_return.sql
-- Update procedure functions to return TABLE(data text[]) for calendar.rows / pog array decoding

DROP FUNCTION IF EXISTS onboarding.get_category_procedure(text);
DROP FUNCTION IF EXISTS onboarding.get_category_procedure_steps(text);
DROP FUNCTION IF EXISTS onboarding.all_category_procedures();

CREATE OR REPLACE FUNCTION onboarding.get_category_procedure(p_category text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    p.procedure_title,
    p.legal_basis,
    p.badge_text,
    p.steps::text,
    p.guidelines,
    p.required_documents,
    p.operational_rules
  ]
  FROM onboarding.category_procedures p
  WHERE p.category_code = p_category
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION onboarding.get_category_procedure_steps(p_category text)
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    (elem->>'step')::text,
    coalesce((elem->>'title')::text, ''),
    coalesce((elem->>'desc')::text, '')
  ]
  FROM onboarding.category_procedures p,
  LATERAL jsonb_array_elements(p.steps) elem
  WHERE p.category_code = p_category
  ORDER BY (elem->>'step')::int;
$$;

CREATE OR REPLACE FUNCTION onboarding.all_category_procedures()
RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    c.code,
    c.name,
    coalesce(p.procedure_title, c.name || ' İlan Ekleme Prosedürü'),
    coalesce(p.legal_basis, 'İlgili Sektörel Mevzuat ve Standartlar'),
    coalesce(p.badge_text, 'Yasal Prosedür'),
    coalesce(jsonb_array_length(p.steps), 0)::text,
    coalesce(p.guidelines, '')
  ]
  FROM onboarding.categories c
  LEFT JOIN onboarding.category_procedures p ON p.category_code = c.code
  WHERE c.active
  ORDER BY c.name;
$$;

GRANT USAGE ON SCHEMA onboarding TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.get_category_procedure(text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.get_category_procedure_steps(text) TO nexus_app;
GRANT EXECUTE ON FUNCTION onboarding.all_category_procedures() TO nexus_app;
