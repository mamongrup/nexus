CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA core;
CREATE SCHEMA auth;
CREATE SCHEMA catalog;
CREATE SCHEMA inventory;
CREATE SCHEMA booking;
CREATE SCHEMA finance;
CREATE SCHEMA events;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE nexustraveltech FROM PUBLIC;
GRANT CONNECT ON DATABASE nexustraveltech TO nexus_app;

CREATE TABLE core.organizations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), legal_name text NOT NULL CHECK(length(legal_name)>1),
 timezone text NOT NULL DEFAULT 'Europe/Istanbul', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE core.currencies (code char(3) PRIMARY KEY, minor_digits smallint NOT NULL CHECK(minor_digits BETWEEN 0 AND 4));
CREATE TABLE core.locales (code text PRIMARY KEY, label text NOT NULL, direction text NOT NULL CHECK(direction IN ('ltr','rtl')));
CREATE TABLE auth.users (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES core.organizations,
 email text NOT NULL UNIQUE CHECK(email=lower(email)), password_hash text NOT NULL,
 display_name text NOT NULL, role text NOT NULL DEFAULT 'owner' CHECK(role IN ('owner','editor','viewer')),
 failed_attempts int NOT NULL DEFAULT 0, locked_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,id)
);
CREATE TABLE auth.sessions (
 token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
 expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON auth.sessions(expires_at);
CREATE TABLE catalog.properties (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES core.organizations,
 title text NOT NULL CHECK(length(title) BETWEEN 3 AND 120), locality text NOT NULL CHECK(length(locality) BETWEEN 2 AND 80),
 description text NOT NULL DEFAULT '' CHECK(length(description)<=5000), capacity int NOT NULL CHECK(capacity BETWEEN 1 AND 50),
 nightly_minor bigint NOT NULL CHECK(nightly_minor BETWEEN 1 AND 1000000000), currency char(3) NOT NULL REFERENCES core.currencies,
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published')), version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,id)
);
CREATE INDEX ON catalog.properties(tenant_id,status,created_at DESC,id);
CREATE TABLE inventory.resources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, property_id uuid NOT NULL,
 name text NOT NULL, UNIQUE(tenant_id,id), FOREIGN KEY(tenant_id,property_id) REFERENCES catalog.properties(tenant_id,id)
);
CREATE TABLE inventory.days (
 tenant_id uuid NOT NULL, resource_id uuid NOT NULL, service_date date NOT NULL,
 capacity int NOT NULL CHECK(capacity>=0), blocked int NOT NULL DEFAULT 0 CHECK(blocked>=0),
 held int NOT NULL DEFAULT 0 CHECK(held>=0), sold int NOT NULL DEFAULT 0 CHECK(sold>=0),
 PRIMARY KEY(tenant_id,resource_id,service_date), FOREIGN KEY(tenant_id,resource_id) REFERENCES inventory.resources(tenant_id,id),
 CHECK(blocked+held+sold<=capacity)
);
CREATE TABLE booking.quotes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, property_id uuid NOT NULL,
 total_minor bigint NOT NULL CHECK(total_minor>0), currency char(3) NOT NULL REFERENCES core.currencies,
 snapshot jsonb NOT NULL, expires_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id), FOREIGN KEY(tenant_id,property_id) REFERENCES catalog.properties(tenant_id,id)
);
CREATE TABLE booking.holds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, quote_id uuid NOT NULL,
 status text NOT NULL CHECK(status IN ('active','consumed','released','expired')), expires_at timestamptz NOT NULL,
 UNIQUE(tenant_id,id), FOREIGN KEY(tenant_id,quote_id) REFERENCES booking.quotes(tenant_id,id)
);
CREATE INDEX ON booking.holds(tenant_id,expires_at) WHERE status='active';
CREATE TABLE booking.reservations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, hold_id uuid NOT NULL,
 status text NOT NULL CHECK(status IN ('pending','confirmed','cancelled','fulfilled')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,id), UNIQUE(tenant_id,hold_id),
 FOREIGN KEY(tenant_id,hold_id) REFERENCES booking.holds(tenant_id,id)
);
CREATE TABLE finance.books (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES core.organizations,
 name text NOT NULL, currency char(3) NOT NULL REFERENCES core.currencies, UNIQUE(tenant_id,id)
);
CREATE TABLE finance.journals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, book_id uuid NOT NULL,
 business_event_id uuid NOT NULL, currency char(3) NOT NULL REFERENCES core.currencies,
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','posted')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,id), UNIQUE(tenant_id,book_id,business_event_id),
 FOREIGN KEY(tenant_id,book_id) REFERENCES finance.books(tenant_id,id)
);
-- Posting is intentionally not granted or implemented until the ledger invariant tests exist.
CREATE TABLE finance.journal_lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, journal_id uuid NOT NULL,
 account_code text NOT NULL, side char(1) NOT NULL CHECK(side IN ('D','C')), amount_minor bigint NOT NULL CHECK(amount_minor>0),
 FOREIGN KEY(tenant_id,journal_id) REFERENCES finance.journals(tenant_id,id)
);
CREATE TABLE events.audit (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, actor_id uuid,
 action text NOT NULL, resource_id uuid NOT NULL, payload jsonb NOT NULL, occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE events.outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, event_type text NOT NULL,
 aggregate_id uuid NOT NULL, aggregate_version bigint NOT NULL, payload jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz
);
CREATE INDEX ON events.outbox(created_at) WHERE published_at IS NULL;

CREATE FUNCTION auth.login(p_email text,p_password text,p_token text) RETURNS TABLE(tenant text, username text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,auth,public AS $$
DECLARE u auth.users%ROWTYPE;
BEGIN
 SELECT * INTO u FROM auth.users WHERE email=lower(p_email) FOR UPDATE;
 IF NOT FOUND THEN PERFORM public.crypt(p_password, public.gen_salt('bf',12)); RETURN; END IF;
 IF u.locked_until > now() THEN RETURN; END IF;
 IF length(p_password)>72 OR u.password_hash<>public.crypt(p_password,u.password_hash) THEN
   UPDATE auth.users SET failed_attempts=failed_attempts+1,
     locked_until=CASE WHEN failed_attempts>=4 THEN now()+interval '15 minutes' ELSE NULL END WHERE id=u.id;
   RETURN;
 END IF;
 UPDATE auth.users SET failed_attempts=0,locked_until=NULL WHERE id=u.id;
 INSERT INTO auth.sessions(token_hash,user_id,expires_at) VALUES(encode(public.digest(p_token,'sha256'),'hex'),u.id,now()+interval '8 hours');
 RETURN QUERY SELECT u.tenant_id::text,u.display_name;
END $$;
CREATE FUNCTION auth.session(p_token text) RETURNS TABLE(tenant text, userid text, username text, userrole text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,auth,public AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.role FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id
 WHERE s.token_hash=encode(public.digest(p_token,'sha256'),'hex') AND s.expires_at>now();
$$;
CREATE FUNCTION auth.logout(p_token text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,auth,public AS $$
 DELETE FROM auth.sessions WHERE token_hash=encode(public.digest(p_token,'sha256'),'hex');
$$;
CREATE FUNCTION catalog.published() RETURNS TABLE(id text,title text,locality text,description text,capacity int,nightly_minor bigint,currency text,status text,version bigint)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,catalog AS $$
 SELECT id::text,title,locality,description,capacity,nightly_minor,currency::text,status,version FROM catalog.properties WHERE status='published' ORDER BY created_at DESC LIMIT 100;
$$;
CREATE FUNCTION events.property_changed() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,events AS $$
BEGIN
 INSERT INTO events.audit(tenant_id,actor_id,action,resource_id,payload)
 VALUES(NEW.tenant_id,nullif(current_setting('app.actor_id',true),'')::uuid,'property.'||lower(TG_OP),NEW.id,jsonb_build_object('title',NEW.title,'status',NEW.status,'version',NEW.version));
 INSERT INTO events.outbox(tenant_id,event_type,aggregate_id,aggregate_version,payload)
 VALUES(NEW.tenant_id,'property.changed',NEW.id,NEW.version,jsonb_build_object('status',NEW.status));
 RETURN NEW;
END $$;
CREATE TRIGGER property_audit AFTER INSERT OR UPDATE ON catalog.properties FOR EACH ROW EXECUTE FUNCTION events.property_changed();
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['catalog.properties','inventory.resources','inventory.days','booking.quotes','booking.holds','booking.reservations','finance.books','finance.journals','finance.journal_lines','events.audit','events.outbox'] LOOP
   EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY',t);
   EXECUTE format('CREATE POLICY tenant_isolation ON %s USING (tenant_id = nullif(current_setting(''app.tenant_id'',true),'''')::uuid) WITH CHECK (tenant_id = nullif(current_setting(''app.tenant_id'',true),'''')::uuid)',t);
 END LOOP;
END $$;
GRANT USAGE ON SCHEMA core,auth,catalog,inventory,booking,finance,events TO nexus_app;
GRANT SELECT ON core.currencies,core.locales TO nexus_app;
GRANT SELECT,INSERT,UPDATE ON catalog.properties TO nexus_app;
GRANT SELECT ON inventory.resources,inventory.days,booking.quotes,booking.holds,booking.reservations,events.audit TO nexus_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA auth,catalog,events FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.login(text,text,text),auth.session(text),auth.logout(text),catalog.published() TO nexus_app;

