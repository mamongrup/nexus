ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true;

CREATE OR REPLACE FUNCTION auth.login(p_email text,p_password text,p_token text) RETURNS TABLE(tenant text, username text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,auth,public AS $$
DECLARE u auth.users%ROWTYPE;
BEGIN
 SELECT * INTO u FROM auth.users WHERE email=lower(trim(p_email)) FOR UPDATE;
 IF NOT FOUND THEN PERFORM public.crypt(p_password,public.gen_salt('bf',12)); RETURN; END IF;
 IF NOT u.active OR u.locked_until>now() THEN RETURN; END IF;
 IF length(p_password)>72 OR u.password_hash<>public.crypt(p_password,u.password_hash) THEN
  UPDATE auth.users SET failed_attempts=failed_attempts+1,locked_until=CASE WHEN failed_attempts>=4 THEN now()+interval '15 minutes' ELSE NULL END WHERE id=u.id; RETURN;
 END IF;
 UPDATE auth.users SET failed_attempts=0,locked_until=NULL WHERE id=u.id;
 INSERT INTO auth.sessions(token_hash,user_id,expires_at) VALUES(encode(public.digest(p_token,'sha256'),'hex'),u.id,now()+interval '8 hours');
 RETURN QUERY SELECT u.tenant_id::text,u.display_name;
END $$;

CREATE OR REPLACE FUNCTION auth.session(p_token text) RETURNS TABLE(tenant text,userid text,username text,userrole text,workspace text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.role,o.kind FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id JOIN core.organizations o ON o.id=u.tenant_id
 WHERE s.token_hash=encode(public.digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active
$$;

CREATE OR REPLACE FUNCTION auth.managed_users() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[u.id::text,o.id::text,o.legal_name,u.email,u.display_name,u.role,u.active::text]
 FROM auth.users u JOIN core.organizations o ON o.id=u.tenant_id
 WHERE (auth.workspace()='nexus' OR u.tenant_id=nullif(current_setting('app.tenant_id',true),'')::uuid)
 ORDER BY o.legal_name,u.display_name
$$;
CREATE OR REPLACE FUNCTION auth.managed_organizations() RETURNS TABLE(data text[]) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ARRAY[o.id::text,o.legal_name,o.kind] FROM core.organizations o
 WHERE auth.workspace()='nexus' OR o.id=nullif(current_setting('app.tenant_id',true),'')::uuid ORDER BY o.legal_name
$$;
CREATE OR REPLACE FUNCTION auth.create_managed_user(p_tenant text,p_email text,p_name text,p_role text,p_password text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE target uuid:=nullif(p_tenant,'')::uuid;
BEGIN
 IF current_setting('app.role',true)<>'owner' THEN RETURN 'forbidden'; END IF;
 IF auth.workspace()<>'nexus' THEN target:=nullif(current_setting('app.tenant_id',true),'')::uuid; END IF;
 IF target IS NULL OR NOT EXISTS(SELECT FROM core.organizations WHERE id=target) OR p_role NOT IN('owner','editor','viewer') OR length(trim(p_name)) NOT BETWEEN 2 AND 100 OR p_email<>lower(trim(p_email)) OR p_email!~'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' OR length(p_password) NOT BETWEEN 10 AND 72 THEN RETURN 'invalid_user'; END IF;
 INSERT INTO auth.users(tenant_id,email,password_hash,display_name,role) VALUES(target,trim(p_email),crypt(p_password,gen_salt('bf',12)),trim(p_name),p_role); RETURN 'ok';
EXCEPTION WHEN unique_violation THEN RETURN 'email_exists';
END $$;
CREATE OR REPLACE FUNCTION auth.update_managed_user(p_user text,p_name text,p_role text,p_active boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE target auth.users%ROWTYPE;
BEGIN
 SELECT * INTO target FROM auth.users WHERE id::text=p_user;
 IF NOT FOUND OR current_setting('app.role',true)<>'owner' OR (auth.workspace()<>'nexus' AND target.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid) OR p_role NOT IN('owner','editor','viewer') OR length(trim(p_name)) NOT BETWEEN 2 AND 100 OR (target.id=nullif(current_setting('app.actor_id',true),'')::uuid AND NOT p_active) THEN RETURN 'forbidden'; END IF;
 UPDATE auth.users SET display_name=trim(p_name),role=p_role,active=p_active WHERE id=target.id; IF NOT p_active THEN DELETE FROM auth.sessions WHERE user_id=target.id; END IF; RETURN 'ok';
END $$;
CREATE OR REPLACE FUNCTION auth.reset_managed_password(p_user text,p_password text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE target auth.users%ROWTYPE;
BEGIN SELECT * INTO target FROM auth.users WHERE id::text=p_user;
 IF NOT FOUND OR current_setting('app.role',true)<>'owner' OR (auth.workspace()<>'nexus' AND target.tenant_id<>nullif(current_setting('app.tenant_id',true),'')::uuid) OR length(p_password) NOT BETWEEN 10 AND 72 THEN RETURN 'forbidden'; END IF;
 UPDATE auth.users SET password_hash=crypt(p_password,gen_salt('bf',12)),failed_attempts=0,locked_until=null WHERE id=target.id; DELETE FROM auth.sessions WHERE user_id=target.id AND target.id<>nullif(current_setting('app.actor_id',true),'')::uuid; RETURN 'ok'; END $$;
CREATE OR REPLACE FUNCTION auth.update_my_profile(p_name text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN IF length(trim(p_name)) NOT BETWEEN 2 AND 100 THEN RETURN 'invalid_user'; END IF; UPDATE auth.users SET display_name=trim(p_name) WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid; RETURN 'ok'; END $$;
CREATE OR REPLACE FUNCTION auth.change_my_password(p_current text,p_new text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE u auth.users%ROWTYPE; BEGIN SELECT * INTO u FROM auth.users WHERE id=nullif(current_setting('app.actor_id',true),'')::uuid FOR UPDATE; IF NOT FOUND OR u.password_hash<>crypt(p_current,u.password_hash) THEN RETURN 'wrong_password'; END IF; IF length(p_new) NOT BETWEEN 10 AND 72 THEN RETURN 'weak_password'; END IF; UPDATE auth.users SET password_hash=crypt(p_new,gen_salt('bf',12)),failed_attempts=0,locked_until=null WHERE id=u.id; RETURN 'ok'; END $$;
REVOKE ALL ON FUNCTION auth.managed_users(),auth.managed_organizations(),auth.create_managed_user(text,text,text,text,text),auth.update_managed_user(text,text,text,boolean),auth.reset_managed_password(text,text),auth.update_my_profile(text),auth.change_my_password(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.managed_users(),auth.managed_organizations(),auth.create_managed_user(text,text,text,text,text),auth.update_managed_user(text,text,text,boolean),auth.reset_managed_password(text,text),auth.update_my_profile(text),auth.change_my_password(text,text) TO nexus_app;
