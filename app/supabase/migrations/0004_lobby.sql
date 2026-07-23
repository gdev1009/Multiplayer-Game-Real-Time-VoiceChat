-- Match Word — Milestone 4 schema
-- Lobby, Game Codes & Matchmaking.
-- Run this in the Supabase SQL editor after 0003_pin_verify.sql.
--
-- Design notes
-- ------------
-- * A game is a room of up to 4 seats split into two teams (A and B).
--   Seat -> team/role mapping (kept in sync with the Dart LobbyRoles helper):
--       seat 0 -> Team A, role A1 (host)
--       seat 1 -> Team B, role B1
--       seat 2 -> Team A, role A2
--       seat 3 -> Team B, role B2
-- * All writes are server-authoritative: every mutation goes through a
--   SECURITY DEFINER function below. The tables have RLS enabled with SELECT
--   policies only, so clients can read the lobby they belong to (and public
--   games) but can never insert/update/delete rows directly.
-- * "Computer" seat-fill uses game_players.is_ai. The player-facing UI never
--   surfaces that wording — these simply appear as extra studio players.

-- =============================================================================
-- games  (one row per lobby / room)
-- =============================================================================
create table if not exists public.games (
  id           uuid primary key default gen_random_uuid(),
  code         text not null,
  host_id      uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'lobby'
                 check (status in ('lobby', 'in_progress', 'finished', 'cancelled')),
  is_public    boolean not null default false,
  max_players  int not null default 4 check (max_players between 2 and 4),
  created_at   timestamptz not null default now(),
  started_at   timestamptz,
  expires_at   timestamptz not null default now() + interval '24 hours',
  updated_at   timestamptz not null default now()
);

comment on table public.games is
  'A Match Word lobby/room. Codes are unique among active (lobby) games and '
  'expire after 24h.';

-- Only one active game may hold a given code at a time.
create unique index if not exists games_active_code_idx
  on public.games (code)
  where status = 'lobby';

create index if not exists games_public_lobby_idx
  on public.games (is_public, status, created_at);

-- =============================================================================
-- game_players  (seats within a game; a null profile_id is a computer seat)
-- =============================================================================
create table if not exists public.game_players (
  id           uuid primary key default gen_random_uuid(),
  game_id      uuid not null references public.games (id) on delete cascade,
  profile_id   uuid references public.profiles (id) on delete cascade,
  display_name text not null,
  first_name   text not null,
  is_ai        boolean not null default false,
  is_host      boolean not null default false,
  seat         int not null check (seat between 0 and 3),
  team         text not null check (team in ('A', 'B')),
  role         text not null check (role in ('A1', 'A2', 'B1', 'B2')),
  joined_at    timestamptz not null default now(),
  unique (game_id, seat)
);

-- A human may hold at most one seat per game.
create unique index if not exists game_players_unique_human_idx
  on public.game_players (game_id, profile_id)
  where profile_id is not null;

create index if not exists game_players_game_idx
  on public.game_players (game_id);

comment on table public.game_players is
  'Seats within a game. profile_id null = computer-filled seat (is_ai).';

-- =============================================================================
-- Helper: map a seat number to its (team, role).
-- =============================================================================
create or replace function public.mw_seat_team(p_seat int)
returns text language sql immutable as $$
  select case when p_seat % 2 = 0 then 'A' else 'B' end;
$$;

create or replace function public.mw_seat_role(p_seat int)
returns text language sql immutable as $$
  select public.mw_seat_team(p_seat) || ((p_seat / 2) + 1)::text;
$$;

-- =============================================================================
-- Helper: generate a 4-digit code not currently used by an active lobby.
-- =============================================================================
create or replace function public.mw_new_game_code()
returns text language plpgsql as $$
declare
  v_code text;
  v_tries int := 0;
begin
  loop
    v_code := lpad((floor(random() * 10000))::int::text, 4, '0');
    exit when not exists (
      select 1 from public.games
      where code = v_code and status = 'lobby'
    );
    v_tries := v_tries + 1;
    if v_tries > 50 then
      raise exception 'could_not_allocate_code';
    end if;
  end loop;
  return v_code;
end;
$$;

-- =============================================================================
-- Create a game. The caller becomes the host in seat 0 (Team A / A1).
-- Returns: { ok, game_id, code }
-- =============================================================================
create or replace function public.mw_create_game(p_is_public boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_name  text;
  v_code  text;
  v_game  uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select first_name into v_name from public.profiles where id = v_uid;
  if v_name is null then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;

  v_code := public.mw_new_game_code();

  insert into public.games (code, host_id, is_public)
  values (v_code, v_uid, coalesce(p_is_public, false))
  returning id into v_game;

  insert into public.game_players
    (game_id, profile_id, display_name, first_name, is_host, seat, team, role)
  values
    (v_game, v_uid, v_name, v_name, true, 0,
     public.mw_seat_team(0), public.mw_seat_role(0));

  return jsonb_build_object('ok', true, 'game_id', v_game, 'code', v_code);
end;
$$;

-- =============================================================================
-- Internal: seat the current user into a game. Assumes the game is joinable.
-- Returns the assigned seat, or -1 if the game is full.
-- =============================================================================
create or replace function public.mw_seat_current_user(p_game uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_name  text;
  v_max   int;
  v_seat  int;
begin
  -- Already seated? Return the existing seat (idempotent join).
  select seat into v_seat
  from public.game_players
  where game_id = p_game and profile_id = v_uid;
  if v_seat is not null then
    return v_seat;
  end if;

  select max_players into v_max from public.games where id = p_game;
  select first_name into v_name from public.profiles where id = v_uid;

  -- Lowest free seat in [0, max_players).
  select s.seat into v_seat
  from generate_series(0, v_max - 1) as s(seat)
  where not exists (
    select 1 from public.game_players gp
    where gp.game_id = p_game and gp.seat = s.seat
  )
  order by s.seat
  limit 1;

  if v_seat is null then
    return -1;
  end if;

  insert into public.game_players
    (game_id, profile_id, display_name, first_name, is_host, seat, team, role)
  values
    (p_game, v_uid, v_name, v_name, false, v_seat,
     public.mw_seat_team(v_seat), public.mw_seat_role(v_seat));

  return v_seat;
end;
$$;

-- =============================================================================
-- Join a game by its 4-digit code.
-- Returns: { ok, game_id } or { ok:false, reason }
-- =============================================================================
create or replace function public.mw_join_game(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_game  uuid;
  v_seat  int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select id into v_game
  from public.games
  where code = p_code and status = 'lobby' and expires_at > now()
  order by created_at desc
  limit 1;

  if v_game is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  v_seat := public.mw_seat_current_user(v_game);
  if v_seat < 0 then
    return jsonb_build_object('ok', false, 'reason', 'full');
  end if;

  return jsonb_build_object('ok', true, 'game_id', v_game);
end;
$$;

-- =============================================================================
-- Quick match: join the oldest open public lobby with a free seat, or create a
-- new public game if none is available.
-- Returns: { ok, game_id, matched }
-- =============================================================================
create or replace function public.mw_quick_match()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_game  uuid;
  v_seat  int;
  v_res   jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select g.id into v_game
  from public.games g
  where g.is_public
    and g.status = 'lobby'
    and g.expires_at > now()
    and not exists (
      select 1 from public.game_players gp
      where gp.game_id = g.id and gp.profile_id = v_uid
    )
    and (
      select count(*) from public.game_players gp where gp.game_id = g.id
    ) < g.max_players
  order by g.created_at asc
  limit 1;

  if v_game is null then
    v_res := public.mw_create_game(true);
    return v_res || jsonb_build_object('matched', false);
  end if;

  v_seat := public.mw_seat_current_user(v_game);
  if v_seat < 0 then
    -- Raced and lost the last seat; fall back to a fresh public game.
    v_res := public.mw_create_game(true);
    return v_res || jsonb_build_object('matched', false);
  end if;

  return jsonb_build_object('ok', true, 'game_id', v_game, 'matched', true);
end;
$$;

-- =============================================================================
-- Host action: fill the remaining empty seats with computer players.
-- Returns: { ok, added } or { ok:false, reason }
-- =============================================================================
create or replace function public.mw_fill_seats(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_host   uuid;
  v_max    int;
  v_status text;
  v_seat   int;
  v_added  int := 0;
  v_names  text[] := array['Sunny', 'Rosie', 'Buddy', 'Pearl', 'Gus', 'Mabel', 'Otis', 'Ada'];
  v_name   text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select host_id, max_players, status
    into v_host, v_max, v_status
  from public.games where id = p_game;

  if v_host is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_host <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'not_host');
  end if;
  if v_status <> 'lobby' then
    return jsonb_build_object('ok', false, 'reason', 'not_in_lobby');
  end if;

  for v_seat in 0 .. v_max - 1 loop
    if not exists (
      select 1 from public.game_players gp
      where gp.game_id = p_game and gp.seat = v_seat
    ) then
      v_name := v_names[1 + (v_seat % array_length(v_names, 1))];
      insert into public.game_players
        (game_id, profile_id, display_name, first_name, is_ai, seat, team, role)
      values
        (p_game, null, v_name, v_name, true, v_seat,
         public.mw_seat_team(v_seat), public.mw_seat_role(v_seat));
      v_added := v_added + 1;
    end if;
  end loop;

  update public.games set updated_at = now() where id = p_game;
  return jsonb_build_object('ok', true, 'added', v_added);
end;
$$;

-- =============================================================================
-- Leave a game. If the host leaves, hand off to the next human, or cancel the
-- game when no humans remain.
-- Returns: { ok }
-- =============================================================================
create or replace function public.mw_leave_game(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_was_host boolean;
  v_new_host uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select is_host into v_was_host
  from public.game_players
  where game_id = p_game and profile_id = v_uid;

  delete from public.game_players
  where game_id = p_game and profile_id = v_uid;

  if coalesce(v_was_host, false) then
    -- Promote the lowest-seat remaining human, if any.
    select profile_id into v_new_host
    from public.game_players
    where game_id = p_game and profile_id is not null
    order by seat asc
    limit 1;

    if v_new_host is null then
      update public.games
        set status = 'cancelled', updated_at = now()
      where id = p_game;
    else
      update public.game_players set is_host = false where game_id = p_game;
      update public.game_players set is_host = true
        where game_id = p_game and profile_id = v_new_host;
      update public.games
        set host_id = v_new_host, updated_at = now()
      where id = p_game;
    end if;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

-- =============================================================================
-- Host action: start the game (lobby -> in_progress).
-- Returns: { ok } or { ok:false, reason }
-- =============================================================================
create or replace function public.mw_start_game(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_host   uuid;
  v_status text;
  v_count  int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select host_id, status into v_host, v_status
  from public.games where id = p_game;

  if v_host is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_host <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'not_host');
  end if;
  if v_status <> 'lobby' then
    return jsonb_build_object('ok', false, 'reason', 'not_in_lobby');
  end if;

  select count(*) into v_count from public.game_players where game_id = p_game;
  if v_count < 2 then
    return jsonb_build_object('ok', false, 'reason', 'need_more_players');
  end if;

  update public.games
    set status = 'in_progress', started_at = now(), updated_at = now()
  where id = p_game;

  return jsonb_build_object('ok', true);
end;
$$;

-- =============================================================================
-- Row Level Security
--   Reads: members can see their game + its players; anyone signed in can see
--   open public lobbies. Writes: none direct — the SECURITY DEFINER functions
--   above are the only way to mutate lobby state (server-authoritative).
-- =============================================================================
alter table public.games        enable row level security;
alter table public.game_players enable row level security;

drop policy if exists "games_select_visible" on public.games;
create policy "games_select_visible"
  on public.games for select
  using (
    (is_public and status = 'lobby')
    or exists (
      select 1 from public.game_players gp
      where gp.game_id = id and gp.profile_id = auth.uid()
    )
  );

drop policy if exists "game_players_select_visible" on public.game_players;
create policy "game_players_select_visible"
  on public.game_players for select
  using (
    exists (
      select 1 from public.game_players me
      where me.game_id = game_players.game_id and me.profile_id = auth.uid()
    )
    or exists (
      select 1 from public.games g
      where g.id = game_players.game_id and g.is_public and g.status = 'lobby'
    )
  );

-- =============================================================================
-- Realtime: broadcast lobby changes to subscribed clients.
-- =============================================================================
do $$
begin
  begin
    alter publication supabase_realtime add table public.games;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.game_players;
  exception when duplicate_object then null;
  end;
end $$;
