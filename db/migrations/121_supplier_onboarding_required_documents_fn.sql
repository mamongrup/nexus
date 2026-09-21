CREATE OR REPLACE FUNCTION onboarding.required_document_codes(p_category text)
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[code]
  FROM onboarding.requirements
  WHERE category_code=p_category
    AND kind='document'
    AND required
  ORDER BY code;
$$;

GRANT EXECUTE ON FUNCTION onboarding.required_document_codes(text) TO nexus_app;
