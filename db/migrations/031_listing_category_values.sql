ALTER TABLE catalog.properties ADD COLUMN attributes jsonb NOT NULL DEFAULT '{}', ADD COLUMN schema_managed boolean NOT NULL DEFAULT false;
CREATE FUNCTION catalog.validate_category_values() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE f record; v text;
BEGIN
 IF NOT NEW.schema_managed THEN RETURN NEW; END IF;
 IF jsonb_typeof(NEW.attributes)<>'object' OR octet_length(NEW.attributes::text)>50000 THEN RAISE EXCEPTION 'invalid attributes'; END IF;
 IF NOT EXISTS(SELECT FROM onboarding.categories WHERE code=NEW.category_code AND active) THEN RAISE EXCEPTION 'inactive category'; END IF;
 FOR f IN SELECT * FROM onboarding.category_fields WHERE category_code=NEW.category_code AND active LOOP
  v:=NEW.attributes->>f.field_code;
  IF f.required AND coalesce(trim(v),'')='' THEN RAISE EXCEPTION 'required field: %',f.label; END IF;
  IF coalesce(v,'')<>'' THEN
   IF f.kind='number' AND v !~ '^-?[0-9]+([.][0-9]+)?$' THEN RAISE EXCEPTION 'invalid number'; END IF;
   IF f.kind='boolean' AND v NOT IN ('true','false') THEN RAISE EXCEPTION 'invalid boolean'; END IF;
   IF f.kind='select' AND NOT v=ANY(regexp_split_to_array(f.choices,'\s*,\s*')) THEN RAISE EXCEPTION 'invalid choice'; END IF;
   IF f.kind='json' THEN PERFORM v::jsonb; END IF;
   IF f.kind='document' THEN RAISE EXCEPTION 'document upload not configured'; END IF;
  END IF;
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION catalog.validate_category_values() FROM PUBLIC;
CREATE TRIGGER category_values BEFORE INSERT OR UPDATE ON catalog.properties FOR EACH ROW EXECUTE FUNCTION catalog.validate_category_values();
