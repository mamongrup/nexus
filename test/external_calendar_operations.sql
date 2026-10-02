BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); other_t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); r uuid; f uuid; c uuid; h uuid; q uuid; a date:=current_date+20; token text:=repeat('a',64); result jsonb;
BEGIN
 INSERT INTO core.organizations(id,legal_name,kind) VALUES(t,'Calendar fixture','supplier'),(other_t,'Other fixture','supplier');
 INSERT INTO auth.users(id,tenant_id,email,password_hash,display_name,role) VALUES(u,t,u::text||'@fixture.invalid','invalid','Calendar fixture','owner');
 INSERT INTO catalog.properties(id,tenant_id,title,locality,capacity,nightly_minor,currency,status,category_code)
 VALUES(p,t,'Calendar fixture','Gocek',10,100000,'TRY','draft','yacht');
 PERFORM set_config('app.tenant_id',t::text,true); PERFORM set_config('app.actor_id',u::text,true);
 f:=inventory.save_external_calendar(t,u,p,'fixture','https://calendar.example.com/feed.ics','Europe/Istanbul');
 BEGIN PERFORM inventory.save_external_calendar(other_t,u,p,'foreign','https://calendar.example.com/feed.ics','Europe/Istanbul'); RAISE EXCEPTION 'foreign scope accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'calendar_access_denied' THEN RAISE; END IF; END;
 SELECT claim_id INTO c FROM inventory.external_calendar_feeds WHERE id=f;
 result:=inventory.claim_external_calendars();
 SELECT claim_id INTO c FROM inventory.external_calendar_feeds WHERE id=f;
 IF c IS NULL THEN RAISE EXCEPTION 'claim missing'; END IF;
 PERFORM inventory.complete_external_calendar(t,f,c,jsonb_build_array(jsonb_build_object('key','event','start',a,'end',a+3)),'');
 INSERT INTO inventory.resources(tenant_id,property_id,name) VALUES(t,p,'Fixture unit') RETURNING id INTO r;
 IF NOT inventory.external_calendar_blocked(t,r,a) OR inventory.external_calendar_blocked(t,r,a+3) THEN RAISE EXCEPTION 'exclusive end incorrect'; END IF;
 INSERT INTO inventory.days(tenant_id,resource_id,service_date,capacity,nightly_minor,currency) SELECT t,r,a+i,1,100000,'TRY' FROM generate_series(0,5) i;
 BEGIN
  PERFORM inventory.create_hold(p::text,a::text,(a+1)::text,30,'calendar-blocked-fixture');
  RAISE EXCEPTION 'blocked hold accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'external_calendar_unavailable' THEN RAISE; END IF; END;
 IF EXISTS(SELECT 1 FROM inventory.days WHERE tenant_id=t AND resource_id=r AND (held<>0 OR sold<>0 OR blocked<>0)) THEN RAISE EXCEPTION 'base stock overwritten'; END IF;
 PERFORM inventory.external_calendar_action(t,u,f,'sync');
 result:=inventory.claim_external_calendars(); SELECT claim_id INTO c FROM inventory.external_calendar_feeds WHERE id=f;
 PERFORM inventory.complete_external_calendar(t,f,c,'[]','fetch failed');
 IF NOT inventory.external_calendar_blocked(t,r,a) THEN RAISE EXCEPTION 'failure cleared blocks'; END IF;
 PERFORM inventory.rotate_calendar_export(t,u,p,token);
 IF inventory.calendar_export_data(token) IS NULL THEN RAISE EXCEPTION 'export missing'; END IF;
 PERFORM inventory.rotate_calendar_export(t,u,p,repeat('b',64));
 IF inventory.calendar_export_data(token) IS NOT NULL THEN RAISE EXCEPTION 'old token accepted'; END IF;
 PERFORM inventory.external_calendar_action(t,u,f,'remove');
 IF inventory.external_calendar_blocked(t,r,a) THEN RAISE EXCEPTION 'removed overlay remains'; END IF;
 IF inventory.create_hold(p::text,(a+3)::text,(a+4)::text,30,'calendar-free-fixture')<>'ok' THEN RAISE EXCEPTION 'free hold failed'; END IF;
 result:=inventory.commerce_operations_data(t,u);
 IF result::text LIKE '%feed.ics%' THEN RAISE EXCEPTION 'feed secret leaked'; END IF;
 IF jsonb_array_length(result->'categories')<>17 THEN RAISE EXCEPTION 'category scope mismatch'; END IF;
 RAISE NOTICE 'calendar: scope, exclusive dates, booking gate, preserved stock, failure retention, rotation and operations passed';
END $$;
ROLLBACK;
