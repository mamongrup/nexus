CREATE OR REPLACE FUNCTION onboarding.supplier_performance()
RETURNS TABLE(data text[]) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH context AS (
   SELECT nullif(current_setting('app.tenant_id',true),'')::uuid tenant_id
   WHERE auth.workspace()='supplier'
 ), metrics AS (
   SELECT 10 seq,'Yayındaki ilan' label,(SELECT count(*) FROM catalog.properties p,context c WHERE p.tenant_id=c.tenant_id AND p.status='published') value
   UNION ALL SELECT 20,'Bekleyen acente talebi',(SELECT count(*) FROM booking.option_requests r,context c WHERE r.supplier_id=c.tenant_id AND r.status='pending')
   UNION ALL SELECT 30,'Onaylanan talep',(SELECT count(*) FROM booking.option_requests r,context c WHERE r.supplier_id=c.tenant_id AND r.status='approved')
   UNION ALL SELECT 40,'Kesin rezervasyon',(SELECT count(*) FROM booking.reservations r,context c WHERE r.tenant_id=c.tenant_id AND r.status='confirmed')
   UNION ALL SELECT 50,'İptal rezervasyon',(SELECT count(*) FROM booking.reservations r,context c WHERE r.tenant_id=c.tenant_id AND r.status='cancelled')
   UNION ALL SELECT 60,'Bekleyen hakediş',(SELECT count(*) FROM finance.settlements s,context c WHERE s.supplier_id=c.tenant_id AND s.status IN ('pending','approved'))
   UNION ALL SELECT 70,'Ödenen hakediş',(SELECT count(*) FROM finance.settlements s,context c WHERE s.supplier_id=c.tenant_id AND s.status='paid')
   UNION ALL SELECT 80,'30 gün içinde bitecek belge',(SELECT count(*) FROM onboarding.documents d JOIN onboarding.applications a ON a.id=d.application_id,context c WHERE a.tenant_id=c.tenant_id AND d.expires_on IS NOT NULL AND d.expires_on<=current_date+30 AND d.status='accepted')
 )
 SELECT ARRAY[label,value::text] FROM metrics WHERE EXISTS(SELECT 1 FROM context) ORDER BY seq;
$$;

CREATE OR REPLACE FUNCTION onboarding.supplier_settlement_totals()
RETURNS TABLE(data text[]) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[s.currency,
   (coalesce(sum(s.supplier_net_minor) FILTER (WHERE s.status IN ('pending','approved')),0)/100.0)::numeric(16,2)::text,
   (coalesce(sum(s.supplier_net_minor) FILTER (WHERE s.status='paid'),0)/100.0)::numeric(16,2)::text]
 FROM finance.settlements s WHERE auth.workspace()='supplier'
   AND s.supplier_id=nullif(current_setting('app.tenant_id',true),'')::uuid
 GROUP BY s.currency ORDER BY s.currency;
$$;

REVOKE ALL ON FUNCTION onboarding.supplier_performance(),onboarding.supplier_settlement_totals() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding.supplier_performance(),onboarding.supplier_settlement_totals() TO nexus_app;
