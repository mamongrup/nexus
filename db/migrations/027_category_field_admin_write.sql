CREATE FUNCTION onboarding.category_field_save(p_id uuid,p_category text,p_code text,p_label text,p_kind text,p_choices text,p_required boolean,p_active boolean,p_position int)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT onboarding.operator() OR p_category IS NULL OR p_code !~ '^[a-z][a-z0-9_]{1,50}$' OR p_kind NOT IN ('text','number','boolean','select','document','json') THEN RETURN 'forbidden'; END IF;
 INSERT INTO onboarding.category_fields(id,category_code,field_code,label,kind,choices,required,active,position) VALUES(coalesce(p_id,gen_random_uuid()),p_category,p_code,p_label,p_kind,coalesce(p_choices,''),coalesce(p_required,false),coalesce(p_active,true),coalesce(p_position,10))
 ON CONFLICT(category_code,field_code) DO UPDATE SET label=EXCLUDED.label,kind=EXCLUDED.kind,choices=EXCLUDED.choices,required=EXCLUDED.required,active=EXCLUDED.active,position=EXCLUDED.position;
 RETURN 'ok';
END $$;
CREATE FUNCTION onboarding.category_field_delete(p_id uuid) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DELETE FROM onboarding.category_fields WHERE id=p_id AND onboarding.operator() RETURNING 'deleted';
$$;
GRANT EXECUTE ON FUNCTION onboarding.category_field_save(uuid,text,text,text,text,text,boolean,boolean,int),onboarding.category_field_delete(uuid) TO nexus_app;
