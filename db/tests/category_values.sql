BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); p uuid;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Category validation fixture','supplier');
 BEGIN
  INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency,schema_managed,attributes) VALUES(t,'Test villa','Fethiye',4,100,'TRY',true,'{}');
  RAISE EXCEPTION 'TEST: missing required fields accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'TEST:%' THEN RAISE; END IF;
 END;
 INSERT INTO catalog.properties(tenant_id,title,locality,capacity,nightly_minor,currency,schema_managed,attributes) VALUES(t,'Test villa','Fethiye',4,100,'TRY',true,'{"bedrooms":"2","bathrooms":"1"}') RETURNING id INTO p;
 IF NOT EXISTS(SELECT FROM catalog.properties WHERE id=p AND attributes->>'bedrooms'='2') THEN RAISE EXCEPTION 'Values not saved'; END IF;
 RAISE NOTICE 'PASS: required category fields rejected and valid values saved';
END $$;
ROLLBACK;
