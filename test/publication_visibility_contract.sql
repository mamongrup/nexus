-- 184: Publication visibility contract applies to every read path.
--
-- 180 forced the two layer state machine on the write side only. The read
-- paths kept their 004/063 era "status='published'" filter, so a listing that
-- is stale, or that was never moderated, was still listed in the public
-- catalogue, in the agency catalogue and could still receive a booking
-- option. catalog.published() encoded the correct rule but nothing called it.
BEGIN;
DO $$
DECLARE
  s uuid := gen_random_uuid();   -- supplier tenant
  a uuid := gen_random_uuid();   -- agency tenant
  n uuid := gen_random_uuid();   -- platform tenant
  su uuid := gen_random_uuid();
  au uuid := gen_random_uuid();
  p uuid := gen_random_uuid();   -- moderated listing
  stale uuid := gen_random_uuid();
  unmoderated uuid := gen_random_uuid();
  visible integer;
  answer text;
BEGIN
  INSERT INTO core.organizations(id,legal_name,kind) VALUES
    (s,'Visibility supplier','supplier'),
    (a,'Visibility agency','agency'),
    (n,'Visibility nexus','nexus');
  INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES
    (su,s,su::text||'@example.invalid','disabled','Supplier','owner'),
    (au,a,au::text||'@example.invalid','disabled','Agency','owner');
  INSERT INTO onboarding.categories(code,name) VALUES('visibility-test','Visibility test');
  INSERT INTO onboarding.applications(owner_user_id,tenant_id,category_code,legal_name,status,identity_status)
    VALUES(su,s,'visibility-test','Visibility supplier','approved','verified');
  INSERT INTO partners.connections(supplier_id,agency_id,status) VALUES(s,a,'active'),(n,a,'active');
  INSERT INTO partners.connection_policies(agency_id,allowed_categories,listing_limit,active)
    VALUES(a,'["visibility-test"]',50,true);

  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,schema_managed)
    VALUES(p,s,'Visibility listing','Antalya','Complete description',2,10000,'TRY','visibility-test',
           '{}'::jsonb,'SEO title','SEO description','["https://example.invalid/visibility.jpg"]'::jsonb,true);
  -- The stale twin carries the same state but was last confirmed too long ago.
  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,schema_managed)
    VALUES(stale,s,'Visibility stale listing','Antalya','Complete description',2,10000,'TRY','visibility-test',
           '{}'::jsonb,'SEO title','SEO description','["https://example.invalid/visibility.jpg"]'::jsonb,true);
  -- A platform owned listing bypasses the supplier write guard entirely, which
  -- is exactly why the read side cannot rely on that trigger alone.
  INSERT INTO catalog.properties(id,tenant_id,title,locality,description,capacity,nightly_minor,currency,category_code,attributes,seo_title,seo_description,media,schema_managed)
    VALUES(unmoderated,n,'Visibility unmoderated listing','Antalya','Complete description',2,10000,'TRY','visibility-test',
           '{}'::jsonb,'SEO title','SEO description','["https://example.invalid/visibility.jpg"]'::jsonb,true);

  -- 1. A draft listing must not be reachable from any catalogue.
  SELECT count(*) INTO visible FROM catalog.marketplace_listings('','','') r WHERE r.data[1] = p::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'draft listing reached the public catalogue'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listing_detail(p) r WHERE r.data[1] = p::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'draft listing reached the public detail view'; END IF;

  -- 2. Publish both listings the way review_listing does.
  UPDATE catalog.properties SET status='published', moderation_status='approved', last_confirmed_at=now() WHERE id IN (p,stale);
  UPDATE catalog.properties SET status='published', last_confirmed_at=now()-interval '40 days' WHERE id=stale;
  UPDATE catalog.properties SET status='published' WHERE id=unmoderated;

  -- 3. The current listing is visible on every read path.
  SELECT count(*) INTO visible FROM catalog.marketplace_listings('','','') r WHERE r.data[1] = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the public catalogue'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listings_v2('','','') r WHERE r.id = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the sync feed'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listing_detail(p) r WHERE r.data[1] = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the public detail view'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listings_for_agency(a::text) r WHERE r.id = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the agency portfolio'; END IF;

  -- 3b. The agency listing feed, which is what the agency app actually calls.
  SELECT count(*) INTO visible FROM catalog.agency_listing_feed(a::text,'','','') r WHERE r.id = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the agency feed'; END IF;
  SELECT count(*) INTO visible FROM catalog.agency_listing_feed(a::text,'','','') r
   WHERE r.id IN (stale::text, unmoderated::text);
  IF visible <> 0 THEN RAISE EXCEPTION 'stale or unmoderated listing reached the agency feed'; END IF;

  -- 4. The stale listing is published but outside the 30 day freshness window.
  SELECT count(*) INTO visible FROM catalog.marketplace_listings('','','') r WHERE r.data[1] = stale::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'stale listing stayed in the public catalogue'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listings_v2('','','') r WHERE r.id = stale::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'stale listing stayed in the sync feed'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listing_detail(stale) r WHERE r.data[1] = stale::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'stale listing stayed in the public detail view'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listings_for_agency(a::text) r WHERE r.id = stale::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'stale listing stayed in the agency portfolio'; END IF;

  -- 5. A listing that was never moderated must stay invisible even though it
  --    is published and belongs to an organisation the write guard ignores.
  SELECT count(*) INTO visible FROM catalog.marketplace_listings('','','') r WHERE r.data[1] = unmoderated::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'unmoderated listing stayed in the public catalogue'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listings_v2('','','') r WHERE r.id = unmoderated::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'unmoderated listing stayed in the sync feed'; END IF;
  SELECT count(*) INTO visible FROM catalog.marketplace_listing_detail(unmoderated) r WHERE r.data[1] = unmoderated::text;
  IF visible <> 0 THEN RAISE EXCEPTION 'unmoderated listing stayed in the public detail view'; END IF;

  -- 6. Agency scoped reads follow the same contract.
  PERFORM set_config('app.tenant_id',a::text,true);
  PERFORM set_config('app.actor_id',au::text,true);
  SELECT count(*) INTO visible FROM partners.agency_catalog() r WHERE r.data[1] = p::text;
  IF visible <> 1 THEN RAISE EXCEPTION 'published listing missing from the agency catalogue'; END IF;
  SELECT count(*) INTO visible FROM partners.agency_catalog() r WHERE r.data[1] IN (stale::text, unmoderated::text);
  IF visible <> 0 THEN RAISE EXCEPTION 'stale or unmoderated listing reached the agency catalogue'; END IF;

  -- 7. Booking options may only be opened for a visible listing.
  answer := booking.request_option(p::text,(current_date+10)::text,(current_date+12)::text,30,'visibility-fixture-key');
  IF answer <> 'ok' THEN RAISE EXCEPTION 'option request rejected for a visible listing: %', answer; END IF;
  answer := booking.request_option(stale::text,(current_date+20)::text,(current_date+22)::text,30,'visibility-stale-key');
  IF answer <> 'not_found' THEN RAISE EXCEPTION 'option request accepted for a stale listing: %', answer; END IF;
  answer := booking.request_option(unmoderated::text,(current_date+30)::text,(current_date+32)::text,30,'visibility-unmoderated-key');
  IF answer <> 'not_found' THEN RAISE EXCEPTION 'option request accepted for an unmoderated listing: %', answer; END IF;

  -- 8. The inventory feed is the leak 185 closes. Before it, this function
  --    carried no publication filter at all: an active connection plus a
  --    policy was enough to read the daily price and availability of a draft
  --    or suspended listing.
  INSERT INTO inventory.resources(id,tenant_id,property_id,name)
    SELECT gen_random_uuid(),tenant_id,id,title FROM catalog.properties WHERE id IN (p,stale,unmoderated);
  INSERT INTO inventory.days(tenant_id,resource_id,service_date,capacity,nightly_minor)
    SELECT r.tenant_id,r.id,(current_date+40)::date,5,10000
    FROM inventory.resources r
    JOIN catalog.properties prop ON prop.id=r.property_id AND prop.tenant_id=r.tenant_id
    WHERE prop.id IN (p,stale,unmoderated);

  SELECT count(*) INTO visible FROM inventory.agency_inventory_feed(a::text,p::text);
  IF visible <> 1 THEN RAISE EXCEPTION 'inventory rows missing for a visible listing: %', visible; END IF;
  SELECT count(*) INTO visible FROM inventory.agency_inventory_feed(a::text,stale::text);
  IF visible <> 0 THEN RAISE EXCEPTION 'inventory feed exposed a stale listing: %', visible; END IF;
  SELECT count(*) INTO visible FROM inventory.agency_inventory_feed(a::text,unmoderated::text);
  IF visible <> 0 THEN RAISE EXCEPTION 'inventory feed exposed an unmoderated listing: %', visible; END IF;

  RAISE NOTICE 'PASS: publication visibility contract holds on every read path';
END $$;
ROLLBACK;
