-- Match Word — Milestone 4 enhancement
-- Quick match that always lands in a playable game, without shutting real
-- players out. Run this in the Supabase SQL editor after 0008_join_preview.sql.
--
-- Product goals (from the client)
-- -------------------------------
-- * Tapping "Find a Game" solo should match with other real players when a
--   lobby exists, and otherwise bring in computer players to fill the empty
--   spots so the person can start playing right away.
-- * Real-player matching must keep working: a game that was auto-filled with
--   computer players should still be joinable by a later human, who simply
--   takes over one of the computer seats.
--
-- How this works
-- --------------
-- * mw_seat_or_bump(): seats the caller in the lowest free seat; if the game is
--   full of computer players, the caller takes over the lowest computer seat
--   instead (the computer player steps aside). Returns the assigned seat, or -1
--   only when every seat is held by a human.
-- * mw_quick_match(): joins the oldest public lobby that has room for a human
--   (a free seat OR a computer seat to take over); if none exists, it creates a
--   new public game and fills the remaining seats with computer players so the
--   creator has a ready table. The new game stays public, so the next human to
--   quick-match will find it and take over a computer seat.
-- * mw_join_game(): now also uses mw_seat_or_bump, so a friend entering a code
--   can still get in (and land on a team) even if the host already filled the
--   empty seats with computer players.

-- =============================================================================
-- Seat the current user, taking over a computer seat if there's no free one.
-- Returns the assigned seat, or -1 when every seat is held by a human.
-- =============================================================================
create or replace function public.mw_seat_or_bump(p_game uuid)
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
  -- Already seated? Idempotent.
  select seat into v_seat
  from public.game_players
  where game_id = p_game and profile_id = v_uid;
  if v_seat is not null then
    return v_seat;
  end if;

  select max_players into v_max from public.games where id = p_game;
  select first_name into v_name from public.profiles where id = v_uid;

  -- Prefer the lowest free seat.
  select s.seat into v_seat
  from generate_series(0, v_max - 1) as s(seat)
  where not exists (
    select 1 from public.game_players gp
    where gp.game_id = p_game and gp.seat = s.seat
  )
  order by s.seat
  limit 1;

  if v_seat is not null then
    insert into public.game_players
      (game_id, profile_id, display_name, first_name, is_host, seat, team, role)
    values
      (p_game, v_uid, v_name, v_name, false, v_seat,
       public.mw_seat_team(v_seat), public.mw_seat_role(v_seat));
    return v_seat;
  end if;

  -- No free seat: take over the lowest computer seat.
  select seat into v_seat
  from public.game_players
  where game_id = p_game and is_ai
  order by seat
  limit 1;

  if v_seat is null then
    return -1;  -- Every seat is a human; genuinely full.
  end if;

  delete from public.game_players
  where game_id = p_game and seat = v_seat;

  insert into public.game_players
    (game_id, profile_id, display_name, first_name, is_host, seat, team, role)
  values
    (p_game, v_uid, v_name, v_name, false, v_seat,
     public.mw_seat_team(v_seat), public.mw_seat_role(v_seat));
  return v_seat;
end;
$$;

grant execute on function public.mw_seat_or_bump(uuid) to authenticated;

-- =============================================================================
-- Quick match: join the oldest open public lobby that has room for a human, or
-- create a new public game filled with computer players so play can start now.
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

  -- Oldest public lobby the user can slot into: a free seat OR a computer seat
  -- to take over, and where they're not already seated.
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
      (select count(*) from public.game_players gp where gp.game_id = g.id)
        < g.max_players
      or exists (
        select 1 from public.game_players gp
        where gp.game_id = g.id and gp.is_ai
      )
    )
  order by g.created_at asc
  limit 1;

  if v_game is not null then
    v_seat := public.mw_seat_or_bump(v_game);
    if v_seat >= 0 then
      return jsonb_build_object('ok', true, 'game_id', v_game, 'matched', true);
    end if;
    -- Raced and lost the last opening; fall through to a fresh game.
  end if;

  -- No match: create a new public game and fill the rest with computer players.
  v_res  := public.mw_create_game(true);
  v_game := (v_res ->> 'game_id')::uuid;
  perform public.mw_fill_seats(v_game);
  return jsonb_build_object('ok', true, 'game_id', v_game, 'matched', false);
end;
$$;

-- =============================================================================
-- Join by code — now takes over a computer seat if the lobby was pre-filled, so
-- a friend can always get in (and see which team they're on via mw_peek_game).
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

  v_seat := public.mw_seat_or_bump(v_game);
  if v_seat < 0 then
    return jsonb_build_object('ok', false, 'reason', 'full');
  end if;

  return jsonb_build_object('ok', true, 'game_id', v_game);
end;
$$;
