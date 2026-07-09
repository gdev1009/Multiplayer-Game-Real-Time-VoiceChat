-- Match Word — Milestone 1 hardening
-- Cross-device sign-in: verify a 4-digit PIN on the server BEFORE a session
-- exists, so the app can show email -> PIN -> one-time-code in that order on a
-- fresh device.
--
-- Security model:
--  * The PIN hash is never sent to the client; verification happens in the DB.
--  * Verifying the PIN does NOT grant a session — the emailed one-time code is
--    still the gate that establishes the session. This is defence in depth: a
--    guessed PIN alone cannot sign anyone in.
--  * Attempts are rate-limited (lockout after repeated failures) because a
--    4-digit PIN is low entropy.
--
-- Run this in the Supabase SQL editor after 0002_characters.sql.

create extension if not exists pgcrypto with schema extensions;

-- =============================================================================
-- mw_hash_pin — reproduces the app's PinHasher exactly.
--   PinHasher: bytes = utf8("salt:pin"); repeat 50000x: bytes = sha256(bytes);
--   result = base64url(bytes)  (URL-safe alphabet, '=' padding kept).
-- =============================================================================
create or replace function public.mw_hash_pin(p_salt text, p_pin text)
returns text
language plpgsql
immutable
set search_path = public, extensions
as $$
declare
  b bytea;
  i int;
begin
  b := convert_to(p_salt || ':' || p_pin, 'UTF8');
  for i in 1..50000 loop
    b := extensions.digest(b, 'sha256');
  end loop;
  -- Postgres base64 -> URL-safe base64 (strip any line breaks, swap +/ for -_).
  return translate(replace(encode(b, 'base64'), E'\n', ''), '+/', '-_');
end;
$$;

-- =============================================================================
-- pin_attempts — per-account brute-force throttle for pre-session PIN checks.
-- No RLS policies: only the SECURITY DEFINER function (running as owner) writes
-- it; the anon/authenticated API roles cannot read or change it directly.
-- =============================================================================
create table if not exists public.pin_attempts (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  fail_count   int not null default 0,
  locked_until timestamptz,
  updated_at   timestamptz not null default now()
);

alter table public.pin_attempts enable row level security;
revoke all on table public.pin_attempts from anon, authenticated;

-- =============================================================================
-- mw_verify_pin — look up an account by email and check its PIN, rate-limited.
-- Returns JSON: {ok:true, name:text} on success, otherwise
--   {ok:false, reason:'no_account'|'bad_pin'|'locked', retry_seconds:int}.
-- Verifying the PIN does not create a session; the caller must still complete
-- the emailed one-time-code step to sign in.
-- =============================================================================
create or replace function public.mw_verify_pin(p_email text, p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_uid          uuid;
  v_name         text;
  v_hash         text;
  v_salt         text;
  v_fail         int := 0;
  v_locked_until timestamptz;
  v_threshold    constant int := 5;         -- failures before a lockout
  v_lock_window  constant interval := interval '15 minutes';
begin
  -- Resolve the account by email (case-insensitive).
  select u.id into v_uid
    from auth.users u
   where lower(u.email) = lower(trim(p_email))
   limit 1;

  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'no_account');
  end if;

  select p.first_name, p.pin_hash, p.pin_salt
    into v_name, v_hash, v_salt
    from public.profiles p
   where p.id = v_uid;

  if v_hash is null or v_salt is null then
    return jsonb_build_object('ok', false, 'reason', 'no_account');
  end if;

  -- Enforce any active lockout.
  select fail_count, locked_until
    into v_fail, v_locked_until
    from public.pin_attempts
   where user_id = v_uid;

  if v_locked_until is not null and v_locked_until > now() then
    return jsonb_build_object(
      'ok', false,
      'reason', 'locked',
      'retry_seconds', ceil(extract(epoch from (v_locked_until - now())))::int
    );
  end if;

  -- Check the PIN.
  if public.mw_hash_pin(v_salt, p_pin) = v_hash then
    -- Success: clear any failure state.
    insert into public.pin_attempts (user_id, fail_count, locked_until, updated_at)
    values (v_uid, 0, null, now())
    on conflict (user_id)
    do update set fail_count = 0, locked_until = null, updated_at = now();

    return jsonb_build_object('ok', true, 'name', v_name);
  end if;

  -- Failure: increment and possibly lock.
  v_fail := coalesce(v_fail, 0) + 1;
  if v_fail >= v_threshold then
    insert into public.pin_attempts (user_id, fail_count, locked_until, updated_at)
    values (v_uid, 0, now() + v_lock_window, now())
    on conflict (user_id)
    do update set fail_count = 0, locked_until = now() + v_lock_window, updated_at = now();

    return jsonb_build_object(
      'ok', false,
      'reason', 'locked',
      'retry_seconds', ceil(extract(epoch from v_lock_window))::int
    );
  end if;

  insert into public.pin_attempts (user_id, fail_count, locked_until, updated_at)
  values (v_uid, v_fail, null, now())
  on conflict (user_id)
  do update set fail_count = v_fail, locked_until = null, updated_at = now();

  return jsonb_build_object('ok', false, 'reason', 'bad_pin');
end;
$$;

-- Only the two API roles may call it (not arbitrary PUBLIC grantees).
revoke all on function public.mw_verify_pin(text, text) from public;
grant execute on function public.mw_verify_pin(text, text) to anon, authenticated;

-- mw_hash_pin is a helper for mw_verify_pin; do not expose it to the API.
revoke all on function public.mw_hash_pin(text, text) from public;
