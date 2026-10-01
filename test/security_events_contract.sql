-- 186: events.security_events + events.record_security_event platform sözleşmesi.
-- Acente tarafındaki agency.security_events (db/migrations/139) sözleşmesinin
-- platform aynalaması: SECURITY DEFINER fonksiyon üzerinden append-only kayıt,
-- doğrulama ve uzunluk sınırları. test.ps1 glob'u bu dosyayı otomatik koşar.
BEGIN;
DO $$
DECLARE
  v_id bigint;
  v_count int;
BEGIN
  -- Zorunlu alanlar: boş request_id/event_type reddedilir.
  BEGIN
    PERFORM events.record_security_event('', 'client', 'POST', '/api/csp-report', 'csp_violation', 'info', 'observed', '{}'::jsonb);
    RAISE EXCEPTION 'empty request_id must be rejected';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT LIKE '%request_id and event_type are required%' THEN
      RAISE EXCEPTION 'unexpected error for empty request_id: %', SQLERRM;
    END IF;
  END;

  BEGIN
    PERFORM events.record_security_event('req-186-b', 'client', 'POST', '/api/csp-report', '', 'info', 'observed', '{}'::jsonb);
    RAISE EXCEPTION 'empty event_type must be rejected';
  EXCEPTION WHEN others THEN
    IF SQLERRM NOT LIKE '%request_id and event_type are required%' THEN
      RAISE EXCEPTION 'unexpected error for empty event_type: %', SQLERRM;
    END IF;
  END;

  -- Normal kayıt: id döner, satır uzunluk sınırlarıyla yazılır.
  v_id := events.record_security_event(
    repeat('r', 300),          -- request_id 128'e kırpılır
    repeat('c', 300),          -- client_id 128'e kırpılır, boş değil
    'post',                    -- method upper(16) -> POST
    repeat('/route', 200),     -- route 512'ye kırpılır
    'csp_violation', 'info', 'observed',
    '{"document-uri":"http://localhost:8081/","violated-directive":"script-src-elem","blocked-uri":"https://evil.example/x.js"}'::jsonb
  );
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'record_security_event must return the inserted id';
  END IF;

  SELECT count(*)::int INTO v_count FROM events.security_events WHERE id = v_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'expected exactly one stored row for id %', v_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM events.security_events
    WHERE id = v_id
      AND length(request_id) = 128
      AND length(client_id) = 128
      AND method = 'POST'
      AND event_type = 'csp_violation'
      AND severity = 'info'
      AND decision = 'observed'
      AND metadata->>'violated-directive' = 'script-src-elem'
  ) THEN
    RAISE EXCEPTION 'stored row does not match the expected normalization';
  END IF;

  -- Geçersiz severity/decision tablo CHECK'lerine takılmalı (farklı hata sınıfı).
  BEGIN
    PERFORM events.record_security_event('req-186-sev', 'client', 'POST', '/', 'csp_violation', 'urgent', 'observed', '{}'::jsonb);
    RAISE EXCEPTION 'invalid severity must be rejected';
  EXCEPTION WHEN check_violation THEN
    NULL; -- beklenen
  END;

  BEGIN
    PERFORM events.record_security_event('req-186-dec', 'client', 'POST', '/', 'csp_violation', 'info', 'allowed', '{}'::jsonb);
    RAISE EXCEPTION 'invalid decision must be rejected';
  EXCEPTION WHEN check_violation THEN
    NULL; -- beklenen
  END;

  -- metadata non-object reddedilir (fonksiyon {} normalizasyonu değil, hata bekler
  -- gibi görünse de sözleşme: CHECK jsonb_typeof = 'object'; fonksiyon savunmacı
  -- şekilde normallize eder; dolayısıyla hata değil, {} yazılmalı).
  v_id := events.record_security_event('req-186-meta', 'client', 'POST', '/', 'csp_violation', 'info', 'observed', '[1,2,3]'::jsonb);
  IF NOT EXISTS (
    SELECT 1 FROM events.security_events WHERE id = v_id AND metadata = '{}'::jsonb
  ) THEN
    RAISE EXCEPTION 'non-object metadata must be normalized to empty object';
  END IF;

  RAISE NOTICE 'PASS: events.security_events contract (append-only telemetry via SECURITY DEFINER function)';
END $$;
ROLLBACK;
