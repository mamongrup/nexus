CREATE TABLE onboarding.category_fields (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 category_code text NOT NULL REFERENCES onboarding.categories(code) ON DELETE CASCADE,
 field_code text NOT NULL CHECK(field_code ~ '^[a-z][a-z0-9_]{1,50}$'),
 label text NOT NULL CHECK(length(label) BETWEEN 2 AND 120),
 kind text NOT NULL CHECK(kind IN ('text','number','boolean','select','document','json')),
 choices text NOT NULL DEFAULT '',
 required boolean NOT NULL DEFAULT false,
 active boolean NOT NULL DEFAULT true,
 position int NOT NULL DEFAULT 10,
 UNIQUE(category_code,field_code)
);
ALTER TABLE onboarding.category_fields ENABLE ROW LEVEL SECURITY;
INSERT INTO onboarding.category_fields(category_code,field_code,label,kind,required,position) VALUES
 ('villa','bedrooms','Yatak odası','number',true,10),('villa','bathrooms','Banyo','number',true,20),('hotel','room_type','Oda tipi','text',true,10),('hotel','amenities','Tesis olanakları','json',false,20),('tour','duration','Süre','text',true,10),('transfer','vehicle_class','Araç sınıfı','text',true,10)
 ON CONFLICT DO NOTHING;

CREATE FUNCTION onboarding.category_fields(p_category text) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[id::text,field_code,label,kind,choices,required::text,active::text,position::text]
 FROM onboarding.category_fields WHERE category_code=p_category AND active ORDER BY position,id;
$$;

CREATE FUNCTION onboarding.category_fields_admin(p_category text) RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[id::text,field_code,label,kind,choices,required::text,active::text,position::text]
 FROM onboarding.category_fields WHERE category_code=p_category AND onboarding.operator() ORDER BY position,id;
$$;
GRANT EXECUTE ON FUNCTION onboarding.category_fields(text),onboarding.category_fields_admin(text) TO nexus_app;
