-- Match Word — Milestone 1 schema
-- Sign In & Account System: profiles + device-id trial-abuse ledger.
-- Run this in the Supabase SQL editor (or via the CLI migrations).

-- =============================================================================
-- profiles
-- =============================================================================
create table if not exists public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  first_name        text not null,
  device_id         text not null,
  pin_hash          text not null,
  pin_salt          text not null,
  trial_used        boolean not null default false,
  trial_started_at  timestamptz,
  created_at        timestamptz not null default now()
);

comment on table public.profiles is
  'Player profile. Email lives in auth.users (recovery only) and is never shown.';

-- =============================================================================
-- device_trials  (silent free-trial abuse prevention — device id is primary)
-- =============================================================================
create table if not exists public.device_trials (
  device_id      text primary key,
  first_trial_at timestamptz not null default now(),
  ip_address     text  -- reserved for the later-phase IP layer
);

comment on table public.device_trials is
  'One row per device that has ever started a free trial.';

-- =============================================================================
-- Row Level Security
-- =============================================================================
alter table public.profiles enable row level security;
alter table public.device_trials enable row level security;

-- profiles: a user may only see and change their own row.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- device_trials: any authenticated user may check/record a device id.
-- (No row is tied to a user; this is an anonymous ledger.)
drop policy if exists "device_trials_select" on public.device_trials;
create policy "device_trials_select"
  on public.device_trials for select
  to authenticated
  using (true);

drop policy if exists "device_trials_insert" on public.device_trials;
create policy "device_trials_insert"
  on public.device_trials for insert
  to authenticated
  with check (true);
