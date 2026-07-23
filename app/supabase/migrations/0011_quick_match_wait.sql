-- Match Word — Milestone 4 enhancement
-- "Give real players a moment before the studio players fill in."
-- Run this in the Supabase SQL editor after 0010_join_seat.sql.
--
-- Why this changes
-- ----------------
-- 0009's mw_quick_match filled the empty seats with studio (AI) players
-- IMMEDIATELY when it created a fresh game, so a solo player never had a window
-- for a real person to join first. The client now wants a short, adjustable
-- "looking for players" wait before the studio players step in — so real
-- matches get first chance at the open seats.
--
-- The wait itself is timed on the CLIENT (LobbyController.quickMatchFillDelay),
-- which calls mw_fill_seats when it elapses (and only if seats are still open).
-- So this migration's job is simply to STOP mw_quick_match from auto-filling on
-- create; everything else about matching/seat-bumping is unchanged.
--
-- Returns: { ok, game_id, matched }
--   matched=true  -> slotted into an existing public lobby
--   matched=false -> created a fresh public game (seats left open for the wait)

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

  -- No match: create a fresh public game and LEAVE the seats open. The client
  -- waits quickMatchFillDelay for real players, then calls mw_fill_seats if the
  -- seats are still empty. The game stays public, so other humans quick-matching
  -- during the wait will find it and take a seat first.
  v_res  := public.mw_create_game(true);
  v_game := (v_res ->> 'game_id')::uuid;
  return jsonb_build_object('ok', true, 'game_id', v_game, 'matched', false);
end;
$$;

comment on function public.mw_quick_match() is
  'Quick match: slot into an open public lobby (free or take-over-AI seat), or '
  'create a fresh public game with seats left OPEN. The client waits a short, '
  'adjustable window for real players before calling mw_fill_seats.';
