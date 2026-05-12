-- ============================================================
-- STK · Supabase schema
-- Run this in the SQL editor at:
--   https://supabase.com/dashboard/project/dhfyjdkazhxkhddnacsq/sql
--
-- After running, also do this in the Supabase dashboard:
--
--   1. (No more redirect URL config needed — magic links are sent
--      via EmailJS and verified by our own RPC, not Supabase Auth.)
--
--   2. Insert YOUR email into public.admins (last block of this file).
-- ============================================================

-- ─── 1. Newsletter ─────────────────────────────────────────
create table if not exists public.newsletter_subscribers (
  id          uuid primary key default gen_random_uuid(),
  email       text not null unique,
  source      text,
  created_at  timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

drop policy if exists "anon can insert"      on public.newsletter_subscribers;
drop policy if exists "admins can read"      on public.newsletter_subscribers;
drop policy if exists "admins can delete"    on public.newsletter_subscribers;
drop policy if exists "session admin reads"  on public.newsletter_subscribers;
drop policy if exists "session admin deletes" on public.newsletter_subscribers;

create policy "anon can insert"
  on public.newsletter_subscribers for insert
  to anon with check (true);

-- ─── 2. Contact submissions ────────────────────────────────
create table if not exists public.contact_submissions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null,
  subject     text,
  message     text not null,
  created_at  timestamptz not null default now()
);

alter table public.contact_submissions enable row level security;

drop policy if exists "anon can insert"      on public.contact_submissions;
drop policy if exists "admins can read"      on public.contact_submissions;
drop policy if exists "admins can delete"    on public.contact_submissions;
drop policy if exists "session admin reads"  on public.contact_submissions;
drop policy if exists "session admin deletes" on public.contact_submissions;

create policy "anon can insert"
  on public.contact_submissions for insert
  to anon with check (
    char_length(name)    between 1 and 200
    and char_length(email)   between 3 and 320
    and char_length(message) between 1 and 5000
  );

-- ─── 3. Bag events ─────────────────────────────────────────
create table if not exists public.bag_events (
  id          bigint generated always as identity primary key,
  sku         text,
  path        text,
  created_at  timestamptz not null default now()
);

alter table public.bag_events enable row level security;

drop policy if exists "anon can insert"     on public.bag_events;
drop policy if exists "admins can read"     on public.bag_events;
drop policy if exists "session admin reads" on public.bag_events;

create policy "anon can insert"
  on public.bag_events for insert
  to anon with check (true);

-- ─── 4. Products ───────────────────────────────────────────
create table if not exists public.products (
  id                  uuid primary key default gen_random_uuid(),
  sku                 text not null unique,
  name                text not null,
  subtitle            text,
  cut                 text not null default 'negative' check (cut in ('negative','roll','flat')),
  status              text not null default 'draft'    check (status in ('live','sold-out','draft')),
  price_idr           integer not null default 0,
  price_idr_compare   integer,
  stock               integer not null default 0,
  stock_max           integer not null default 0,
  image_url           text,
  position            integer not null default 999,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create or replace function public.tg_touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists products_touch on public.products;
create trigger products_touch
  before update on public.products
  for each row execute function public.tg_touch_updated_at();

alter table public.products enable row level security;

drop policy if exists "anon can read live"      on public.products;
drop policy if exists "admins can read"         on public.products;
drop policy if exists "admins can write"        on public.products;
drop policy if exists "session admin reads"     on public.products;
drop policy if exists "session admin writes"    on public.products;
drop policy if exists "session admin updates"   on public.products;
drop policy if exists "session admin deletes"   on public.products;

-- Public storefront sees live + sold-out, never draft
create policy "anon can read live"
  on public.products for select
  to anon using (status in ('live','sold-out'));

-- ─── 5. Admins allowlist ───────────────────────────────────
create table if not exists public.admins (
  email       text primary key,
  added_at    timestamptz not null default now()
);

alter table public.admins enable row level security;
-- No public policies; only SECURITY DEFINER functions read this table.

-- ─── 6. Custom magic-link auth (EmailJS delivers the email) ─
create table if not exists public.admin_login_tokens (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);
alter table public.admin_login_tokens enable row level security;
-- All access via SECURITY DEFINER RPCs; no public policies.

create table if not exists public.admin_sessions (
  token       text primary key,
  email       text not null,
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now()
);
alter table public.admin_sessions enable row level security;
-- All access via SECURITY DEFINER RPCs; no public policies.

-- Mint a single-use login token for the given email. Always returns
-- a UUID so we don't leak which emails are admins; only the matching
-- token gets persisted and is therefore actually consumable.
create or replace function public.request_admin_login(p_email text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_token uuid;
begin
  if not exists (select 1 from public.admins where lower(email) = lower(p_email)) then
    return gen_random_uuid();   -- decoy
  end if;

  insert into public.admin_login_tokens (email, expires_at)
  values (lower(p_email), now() + interval '15 minutes')
  returning id into v_token;
  return v_token;
end;
$$;
grant execute on function public.request_admin_login(text) to anon;

-- Consume a login token and create a session. Returns the session
-- token on success, null on invalid/expired/already-used tokens.
create or replace function public.consume_admin_login_token(p_token uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_email text;
  v_session text;
begin
  update public.admin_login_tokens
     set used_at = now()
   where id = p_token
     and used_at is null
     and expires_at > now()
     and email in (select lower(email) from public.admins)
  returning email into v_email;

  if v_email is null then return null; end if;

  v_session := encode(gen_random_bytes(32), 'hex');
  insert into public.admin_sessions (token, email, expires_at)
  values (v_session, v_email, now() + interval '30 days');
  return v_session;
end;
$$;
grant execute on function public.consume_admin_login_token(uuid) to anon;

-- Reads the X-Admin-Token header from the current request and
-- returns the matching admin's email, or null.
create or replace function public.verify_admin_session()
returns text
language plpgsql stable security definer set search_path = public as $$
declare v_token text; v_email text;
begin
  begin
    v_token := (current_setting('request.headers', true)::jsonb) ->> 'x-admin-token';
  exception when others then
    return null;
  end;
  if v_token is null or length(v_token) < 32 then return null; end if;
  select email into v_email
    from public.admin_sessions
   where token = v_token and expires_at > now();
  return v_email;
end;
$$;
grant execute on function public.verify_admin_session() to anon;

-- Same helper, but returns boolean — used inside RLS policies.
create or replace function public.is_admin_session() returns boolean
language sql stable security definer set search_path = public as $$
  select public.verify_admin_session() is not null;
$$;

-- Sign-out: invalidate the current session.
create or replace function public.revoke_admin_session()
returns void
language plpgsql security definer set search_path = public as $$
declare v_token text;
begin
  begin
    v_token := (current_setting('request.headers', true)::jsonb) ->> 'x-admin-token';
  exception when others then
    return;
  end;
  if v_token is not null then
    delete from public.admin_sessions where token = v_token;
  end if;
end;
$$;
grant execute on function public.revoke_admin_session() to anon;

-- ─── 7. Admin-side policies (session-token gated) ──────────
create policy "session admin reads"
  on public.newsletter_subscribers for select
  to anon using (public.is_admin_session());
create policy "session admin deletes"
  on public.newsletter_subscribers for delete
  to anon using (public.is_admin_session());

create policy "session admin reads"
  on public.contact_submissions for select
  to anon using (public.is_admin_session());
create policy "session admin deletes"
  on public.contact_submissions for delete
  to anon using (public.is_admin_session());

create policy "session admin reads"
  on public.bag_events for select
  to anon using (public.is_admin_session());

create policy "session admin reads"
  on public.products for select
  to anon using (public.is_admin_session());
create policy "session admin writes"
  on public.products for insert
  to anon with check (public.is_admin_session());
create policy "session admin updates"
  on public.products for update
  to anon using (public.is_admin_session()) with check (public.is_admin_session());
create policy "session admin deletes"
  on public.products for delete
  to anon using (public.is_admin_session());

-- ─── 8. Add yourself as the first admin ────────────────────
-- IMPORTANT: replace francois.barrailla@gmail.com with your real address
insert into public.admins (email)
values ('francois.barrailla@gmail.com')
on conflict do nothing;
