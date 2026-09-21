\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); p uuid; rows_count int; image_value jsonb;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Feed fixture','supplier');
 INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency,status,category_code,media)
 VALUES(t,'Typed Villa','Kaş',4,12000,'TRY','published','villa','["https://cdn.example/villa.jpg"]'::jsonb) RETURNING id INTO p;
 SELECT count(*) INTO rows_count FROM catalog.marketplace_listings_v2('','','');
 SELECT images INTO image_value FROM catalog.marketplace_listings_v2('','','') LIMIT 1;
 IF rows_count<1 OR image_value<>'["https://cdn.example/villa.jpg"]'::jsonb THEN RAISE EXCEPTION 'Typed feed/media contract failed'; END IF;
 RAISE NOTICE 'PASS: typed marketplace feed returns published listing and provider media';
END $$;
ROLLBACK;
