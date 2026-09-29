\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid; rows_count int; image_value jsonb;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Feed fixture','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role)
 VALUES(u,t,u::text||'@example.invalid','disabled','Owner','owner');
 INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
 VALUES(u,t,'holiday_home','Feed fixture','approved','verified');
 INSERT INTO catalog.properties(tenant_id,title,description,locality,capacity,nightly_minor,currency,status,moderation_status,last_confirmed_at,category_code,attributes,seo_title,seo_description,media)
 VALUES(t,'Typed Villa','Marketplace feed test listing','Kaş',4,12000,'TRY','published','approved',now(),'holiday_home',
        '{"property_type":"villa","bedroom_count":2,"bathroom_count":1,"guest_capacity":4}'::jsonb,
        'Typed Villa','Marketplace feed test listing','["https://cdn.example/villa.jpg"]'::jsonb) RETURNING id INTO p;
 SELECT count(*) INTO rows_count FROM catalog.marketplace_listings_v2('','','');
 SELECT images INTO image_value FROM catalog.marketplace_listings_v2('','','') LIMIT 1;
 IF rows_count<1 OR image_value<>'["https://cdn.example/villa.jpg"]'::jsonb THEN RAISE EXCEPTION 'Typed feed/media contract failed'; END IF;
 RAISE NOTICE 'PASS: typed marketplace feed returns published listing and provider media';
END $$;
ROLLBACK;
