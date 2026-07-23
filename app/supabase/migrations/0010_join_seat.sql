-- Match Word — Milestone 4 enhancement
-- "Pick your own seat (and team) in the join preview."
-- Run this in the Supabase SQL editor after 0009_quick_match_ai.sql.
--
-- Why this is needed
-- ------------------
-- The join preview (mw_peek_game) lets a player see who's already in a game
-- before committing. Players then asked to *choose* which seat they take, so a
-- friend can deliberately land on the same team (even seats = Team A, odd
-- seats = Team B). This function seats the caller in a specific seat they
-- tapped, instead of the automatic "lowest free seat" rule.
--
-- Rules
-- -----
-- * A free seat is taken directly.
-- * A seat held by a computer player is taken over (the computer steps aside),
--   just like mw_seat_or_bump — so pre-filled games stay pickable.
-- * A seat held by another human is refused ('seat_taken') so two people can't
--   collide on the same chair.
-- * If the caller is already seated elsewhere in this game, they're moved to
--   the chosen seat (team/role updated to match the new seat).
--
-- SECURITY DEFINER so a not-yet-member holding the code can seat themselves.

create or replace function public.mw_join_seat(p_code text, p_seat int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_game      public.games%rowtype;
  v_name      text;
  v_occupant  public.game_players%rowtype;
  v_mine      int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select * into v_game
  from public.games
  where code = p_code and status = 'lobby' and expires_at > now()
  order by created_at desc
  limit 1;

  if v_game.id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if p_seat < 0 or p_seat >= v_game.max_players then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;

  select first_name into v_name from public.profiles where id = v_uid;

  -- Who (if anyone) currently holds the chosen seat?
  select * into v_occupant
  from public.game_players
  where game_id = v_game.id and seat = p_seat;

  -- A human already sitting there (and it isn't us) blocks the pick.
  if v_occupant.profile_id is not null
     and not v_occupant.is_ai
     and v_occupant.profile_id <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'seat_taken');
  end if;

  -- Already sitting in the chosen seat? Idempotent success.
  if v_occupant.profile_id = v_uid then
    return jsonb_build_object('ok', true, 'game_id', v_game.id, 'seat', p_seat);
  end if;

  -- Free the chosen seat if a computer player is holding it.
  if v_occupant.seat is not null then
    delete from public.game_players
    where game_id = v_game.id and seat = p_seat;
  end if;

  -- If we were already seated elsewhere in this game, vacate that seat.
  select seat into v_mine
  from public.game_players
  where game_id = v_game.id and profile_id = v_uid;
  if v_mine is not null then
    delete from public.game_players
    where game_id = v_game.id and profile_id = v_uid;
  end if;

  insert into public.game_players
    (game_id, profile_id, display_name, first_name, is_host, seat, team, role)
  values
    (v_game.id, v_uid, v_name, v_name, false, p_seat,
     public.mw_seat_team(p_seat), public.mw_seat_role(p_seat));

  return jsonb_build_object('ok', true, 'game_id', v_game.id, 'seat', p_seat);
end;
$$;

comment on function public.mw_join_seat(text, int) is
  'Seats the caller in a specific chosen seat of an open lobby (taking over a '
  'computer seat if needed), so players can pick their own team in the join '
  'preview. Refuses a seat already held by another human.';

grant execute on function public.mw_join_seat(text, int) to authenticated;
