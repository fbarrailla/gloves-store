-- ============================================================
-- STK · Supabase schema
-- Run this in the SQL editor at:
--   https://supabase.com/dashboard/project/dhfyjdkazhxkhddnacsq/sql
--
-- After running, also do this in the Supabase dashboard:
--
--   1. Auth → URL Configuration:
--        Site URL:        http://sarung-tangan-kiper.com
--        Redirect URLs:   http://sarung-tangan-kiper.com/admin/dashboard.html
--                         https://sarung-tangan-kiper.com/admin/dashboard.html
--                         http://localhost:4477/admin/dashboard.html   (dev)
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

drop policy if exists "anon can insert"   on public.contact_submissions;
drop policy if exists "admins can read"   on public.contact_submissions;
drop policy if exists "admins can delete" on public.contact_submissions;

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

drop policy if exists "anon can insert" on public.bag_events;
drop policy if exists "admins can read" on public.bag_events;

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

drop policy if exists "anon can read live"     on public.products;
drop policy if exists "admins can read"        on public.products;
drop policy if exists "admins can write"       on public.products;

-- Public can see live + sold-out, but never draft
create policy "anon can read live"
  on public.products for select
  to anon using (status in ('live','sold-out'));

-- ─── 5. Admins allowlist ───────────────────────────────────
create table if not exists public.admins (
  email       text primary key,
  added_at    timestamptz not null default now()
);

alter table public.admins enable row level security;
-- No public read; service role only. Admins use auth.email() to check membership.

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where email = auth.email());
$$;

-- ─── 6. Authenticated-admin policies on the other tables ──
create policy "admins can read"
  on public.newsletter_subscribers for select
  to authenticated using (public.is_admin());

create policy "admins can delete"
  on public.newsletter_subscribers for delete
  to authenticated using (public.is_admin());

create policy "admins can read"
  on public.contact_submissions for select
  to authenticated using (public.is_admin());

create policy "admins can delete"
  on public.contact_submissions for delete
  to authenticated using (public.is_admin());

create policy "admins can read"
  on public.bag_events for select
  to authenticated using (public.is_admin());

create policy "admins can read"
  on public.products for select
  to authenticated using (public.is_admin());

create policy "admins can write"
  on public.products for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ─── 7. Add yourself as the first admin ────────────────────
-- IMPORTANT: replace francois.barrailla@gmail.com with your real address
insert into public.admins (email)
values ('francois.barrailla@gmail.com')
on conflict do nothing;
