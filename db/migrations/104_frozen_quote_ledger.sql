-- Post only an authenticated supplier's confirmed reservation from its frozen quote.
-- Existing journals remain immutable; missing commercial snapshots need explicit repair.
CREATE OR REPLACE FUNCTION finance.post_reservation_ledger(p_reservation_id text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
 t uuid := nullif(current_setting('app.tenant_id',true),'')::uuid;
 u uuid := nullif(current_setting('app.actor_id',true),'')::uuid;
 r booking.reservations%ROWTYPE;
 q booking.quotes%ROWTYPE;
 book_uuid uuid; j_id uuid;
 gross bigint; net bigint; nexus_take bigint; agency_share bigint; taxes bigint;
BEGIN
 IF NOT EXISTS(SELECT FROM auth.users au WHERE au.id=u AND au.tenant_id=t AND au.active
   AND au.role IN ('owner','general_manager','accounting','finance_manager')) THEN
  RETURN 'forbidden';
 END IF;
 SELECT * INTO r FROM booking.reservations WHERE id::text=p_reservation_id AND tenant_id=t FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF EXISTS(SELECT FROM finance.journals WHERE tenant_id=t AND business_event_id=r.id) THEN RETURN 'already_posted'; END IF;
 IF r.status IS DISTINCT FROM 'confirmed' THEN RETURN 'invalid_status'; END IF;
 SELECT bq.* INTO q FROM booking.holds h JOIN booking.quotes bq ON bq.id=h.quote_id AND bq.tenant_id=h.tenant_id
 WHERE h.id=r.hold_id AND h.tenant_id=t;
 IF NOT FOUND OR q.total_minor IS DISTINCT FROM r.total_minor OR q.currency IS DISTINCT FROM r.currency
   OR jsonb_typeof(q.snapshot) IS DISTINCT FROM 'object'
   OR NOT (q.snapshot ?& ARRAY['supplier_net_minor','nexus_fee_minor','agency_markup_minor','tax_minor','customer_price_minor','currency'])
 THEN RETURN 'invalid_snapshot'; END IF;
 -- Strict integer parsing, no fractional rounding or accidental NULL acceptance.
 IF EXISTS(SELECT FROM jsonb_each(q.snapshot) e WHERE e.key IN
  ('supplier_net_minor','nexus_fee_minor','agency_markup_minor','tax_minor','customer_price_minor')
  AND (jsonb_typeof(e.value) IS DISTINCT FROM 'number' OR e.value::text !~ '^[0-9]+$')) THEN RETURN 'invalid_snapshot'; END IF;
 BEGIN
  gross := (q.snapshot->>'customer_price_minor')::bigint;
  net := (q.snapshot->>'supplier_net_minor')::bigint;
  nexus_take := (q.snapshot->>'nexus_fee_minor')::bigint;
  agency_share := (q.snapshot->>'agency_markup_minor')::bigint;
  taxes := (q.snapshot->>'tax_minor')::bigint;
 EXCEPTION WHEN numeric_value_out_of_range OR invalid_text_representation THEN RETURN 'invalid_snapshot';
 END;
 IF gross IS DISTINCT FROM r.total_minor OR net <= 0 OR gross <= 0
   OR q.snapshot->>'currency' IS DISTINCT FROM r.currency::text
   OR net::numeric+nexus_take::numeric+agency_share::numeric+taxes::numeric <> gross::numeric
   OR (agency_share > 0 AND r.agency_id IS NULL)
 THEN RETURN 'invalid_snapshot'; END IF;
 -- Serialize book creation across reservations in the same organization.
 PERFORM 1 FROM core.organizations WHERE id=t FOR UPDATE;
 SELECT id INTO book_uuid FROM finance.books WHERE tenant_id=t AND currency=r.currency ORDER BY id LIMIT 1;
 IF book_uuid IS NULL THEN
  INSERT INTO finance.books(tenant_id,name,currency) VALUES(t,'Reservation ledger',r.currency) RETURNING id INTO book_uuid;
 END IF;
 INSERT INTO finance.journals(tenant_id,book_id,business_event_id,currency,state)
 VALUES(t,book_uuid,r.id,r.currency,'posted') RETURNING id INTO j_id;
 INSERT INTO finance.journal_lines(tenant_id,journal_id,account_code,side,amount_minor)
 SELECT t,j_id,x.code,x.side,x.amount FROM (VALUES
 ('1100','D',gross),('2000','C',net),('2100','C',nexus_take),('2200','C',agency_share),('2300','C',taxes)
 ) AS x(code,side,amount) WHERE x.amount>0;
 INSERT INTO finance.settlements(tenant_id,reservation_id,supplier_id,agency_id,gross_amount_minor,supplier_net_minor,nexus_fee_minor,agency_markup_minor,currency,status)
 VALUES(t,r.id,t,r.agency_id,gross,net,nexus_take,agency_share,r.currency,'pending');
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
 VALUES(t,u,'finance.ledger.posted',j_id,jsonb_build_object('reservation_id',r.id,'quote_id',q.id,'gross',gross,'net',net,'nexus_fee',nexus_take,'agency_share',agency_share,'tax',taxes));
 RETURN 'ok';
END $$;
REVOKE ALL ON FUNCTION finance.post_reservation_ledger(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION finance.post_reservation_ledger(text) TO nexus_app;

