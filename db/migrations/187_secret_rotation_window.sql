-- Secret rotation window gate (acente'deki db/migrations/238 sözleşmesinin
-- platform aynalaması). Her SECRET_KEY_BASE rotasyonu scripts/record-secret-
-- rotation.ps1 ile burada tarihlenir. Pencere varsayılanı 48 saattir:
-- rotasyondan sonra SECRET_KEY_BASE_PREVIOUS en fazla bu kadar süre
-- devrede kalmalı. scripts/check-secret-hygiene.ps1 pencere durumunu bu
-- fonksiyonlardan hesaplar; kayıt yoksa durum 'unknown' olur ve kontrol
-- başarısız sayılır (fail-closed) — kayıtsız sır denetlenemez.
--
-- Tablo işletim/telemetri verisidir; uygulama (nexus_app) okumaz, yalnızca
-- owner rotasyon operasyonunda kullanır.

CREATE TABLE IF NOT EXISTS events.secret_rotations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  secret_name varchar(64) NOT NULL,
  rotated_at timestamptz NOT NULL DEFAULT now(),
  source varchar(64) NOT NULL DEFAULT 'manual'
);

CREATE INDEX IF NOT EXISTS events_secret_rotations_name_time_idx
  ON events.secret_rotations(secret_name, rotated_at DESC);

-- Sır bazlı pencere ayarı. Satır yoksa varsayılan 48 saat uygulanır
-- (bkz. events.rotation_window_hours).
CREATE TABLE IF NOT EXISTS events.secret_rotation_settings (
  secret_name varchar(64) PRIMARY KEY,
  window_hours int NOT NULL CHECK (window_hours BETWEEN 1 AND 24 * 30)
);

INSERT INTO events.secret_rotation_settings(secret_name, window_hours)
VALUES
  ('SECRET_KEY_BASE', 48),
  ('SECRET_KEY_BASE_PREVIOUS', 48)
ON CONFLICT (secret_name) DO NOTHING;

CREATE OR REPLACE FUNCTION events.rotation_window_hours(p_secret text)
RETURNS int
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT window_hours FROM events.secret_rotation_settings
      WHERE secret_name = p_secret),
    48
  );
$$;

CREATE OR REPLACE FUNCTION events.set_rotation_window(p_secret text, p_hours int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
  IF p_secret IS NULL OR length(trim(p_secret)) = 0 THEN
    RAISE EXCEPTION 'secret_name is required';
  END IF;
  IF p_hours IS NULL OR p_hours < 1 OR p_hours > 24 * 30 THEN
    RAISE EXCEPTION 'window_hours must be between 1 and 720';
  END IF;
  INSERT INTO events.secret_rotation_settings(secret_name, window_hours)
  VALUES (left(trim(p_secret), 64), p_hours)
  ON CONFLICT (secret_name) DO UPDATE SET window_hours = EXCLUDED.window_hours;
END;
$$;

CREATE OR REPLACE FUNCTION events.latest_rotation_age_hours(p_secret text)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT round(
    EXTRACT(EPOCH FROM (now() - max(rotated_at))) / 3600.0, 2
  )
  FROM events.secret_rotations
  WHERE secret_name = p_secret;
$$;

-- Pencere durumu: 'unknown' (kayıt yok — fail-closed), 'open' (pencere
-- içinde), 'expired' (pencere kapandı — SECRET_KEY_BASE_PREVIOUS
-- env'den kaldırılmalı, hatırlatma burada üretilir).
CREATE OR REPLACE FUNCTION events.rotation_window_state(p_secret text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_age numeric;
  v_window int;
BEGIN
  SELECT events.latest_rotation_age_hours(p_secret) INTO v_age;
  IF v_age IS NULL THEN
    RETURN 'unknown';
  END IF;
  v_window := events.rotation_window_hours(p_secret);
  IF v_age <= v_window THEN
    RETURN 'open';
  END IF;
  RETURN 'expired';
END;
$$;

COMMENT ON TABLE events.secret_rotations IS
  'Secret rotation timestamps; window gate for SECRET_KEY_BASE_PREVIOUS (48h default).';
COMMENT ON FUNCTION events.rotation_window_state(text) IS
  'unknown=no record (fail-closed), open=within window, expired=remove previous secret.';
