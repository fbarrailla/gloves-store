-- ============================================================
-- STK · Supabase schema
-- Run this once in the SQL editor at:
--   https://supabase.com/dashboard/project/dhfyjdkazhxkhddnacsq/sql
-- ============================================================

-- ─── 1. Newsletter ─────────────────────────────────────────
create table if not exists public.newsletter_subscribers (
  id          uuid primary key default gen_random_uuid(),
  email       text not null unique,
  source      text,
  created_at  timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

drop policy if exists "anon can insert"    on public.newsletter_subscribers;
drop policy if exists "no public reads"    on public.newsletter_subscribers;

create policy "anon can insert"
  on public.newsletter_subscribers for insert
  to anon with check (true);

-- (Default: no SELECT policy = no public reads. Use service role to read.)

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

drop policy if exists "anon can insert" on public.contact_submissions;

create policy "anon can insert"
  on public.contact_submissions for insert
  to anon with check (
    char_length(name)    between 1 and 200
    and char_length(email)   between 3 and 320
    and char_length(message) between 1 and 5000
  );

-- ─── 3. Bag events (best-effort analytics) ─────────────────
create table if not exists public.bag_events (
  id          bigint generated always as identity primary key,
  sku         text,
  path        text,
  created_at  timestamptz not null default now()
);

alter table public.bag_events enable row level security;

drop policy if exists "anon can insert" on public.bag_events;

create policy "anon can insert"
  on public.bag_events for insert
  to anon with check (true);
