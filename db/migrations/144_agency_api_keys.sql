-- Agency scoped API keys for tenant-bound feed, inventory and webhook calls.
-- Secrets are never stored in plaintext; only SHA-256 hashes are persisted.

create table if not exists partners.agency_api_keys (
  agency_id uuid not null references core.organizations(id) on delete cascade,
  label text not null default 'default',
  key_hash text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_used_at timestamptz,
  primary key (agency_id, label),
  unique (agency_id, key_hash),
  constraint agency_api_keys_label_not_blank check (btrim(label) <> ''),
  constraint agency_api_keys_hash_not_blank check (btrim(key_hash) <> '')
);

create or replace function partners.agency_api_key_required(p_agency_id text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
      from partners.agency_api_keys k
     where k.agency_id = nullif(p_agency_id, '')::uuid
       and k.active
  );
$$;

create or replace function partners.agency_api_key_ok(
  p_agency_id text,
  p_api_key text
)
returns boolean
language plpgsql
security definer
set search_path = partners, core, public
as $$
declare
  v_agency_id uuid;
  v_key text;
  v_hash text;
begin
  begin
    v_agency_id := nullif(p_agency_id, '')::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  v_key := nullif(btrim(coalesce(p_api_key, '')), '');
  if v_agency_id is null or v_key is null then
    return false;
  end if;

  if not exists (
    select 1
      from core.organizations o
     where o.id = v_agency_id
       and o.kind = 'agency'
  ) then
    return false;
  end if;

  v_hash := encode(public.digest(v_key, 'sha256'), 'hex');

  update partners.agency_api_keys k
     set last_used_at = now(),
         updated_at = now()
   where k.agency_id = v_agency_id
     and k.key_hash = v_hash
     and k.active;

  return found;
end;
$$;

grant select, insert, update on partners.agency_api_keys to nexus_app;
grant execute on function partners.agency_api_key_required(text) to nexus_app;
grant execute on function partners.agency_api_key_ok(text, text) to nexus_app;
