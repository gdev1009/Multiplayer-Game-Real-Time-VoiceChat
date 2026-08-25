-- =============================================================================
-- 0031_turn_order_clue_repeat_names.sql
-- =============================================================================
-- Ronna's Aug 2026 play-test, server side. Mirrors the Dart MatchEngine in
-- app/lib/features/game/game_engine.dart.
--
--  1. Turn order: "about 3/4 of the way through it gives the team that's
--     opposite to me two or three turns in a row." The opener was derived from
--     the word number, but a steal moves control mid-word, so the team that
--     stole word N also opened word N+1 whenever N+1's parity named them. The
--     opener is now whichever team did *not* give the last clue.
--  2. Clue repeats: "the opposition is getting the same clue that we gave and
--     then we give that same clue again. They have to give a new clue every
--     time." A clue may now only be used once per word.
--  3. Seat names: display_name was snapshotted when a player sat down and never
--     refreshed, so a profile renamed afterwards kept showing the old name
--     ("my name isn't showing up when I'm the player").

-- -----------------------------------------------------------------------------
-- 1. Next word opens with the team that did not just give a clue.
-- -----------------------------------------------------------------------------
create or replace function public.mw_next_word(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s       public.game_state%rowtype;
  v_next  int;
  v_total int;
  v_team  text;
  v_win   text;
begin
  if not public.mw_is_game_member(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'not_member');
  end if;

  select * into s from public.game_state where game_id = p_game for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if s.step <> 'resolved' then
    return jsonb_build_object('ok', false, 'reason', 'not_resolved');
  end if;
  -- Only active halves may advance; halftime requires begin_second_half.
  if s.phase not in ('first_half', 'second_half') then
    return jsonb_build_object('ok', false, 'reason', 'not_in_half');
  end if;

  v_next  := s.word_index + 1;
  v_total := s.words_per_half * 2;

  if v_next >= v_total then
    v_win := case
      when s.score_a = s.score_b then null
      when s.score_a > s.score_b then 'A' else 'B' end;
    update public.game_state set
      phase = 'game_over',
      word_index = v_next,
      pending_clue = null,
      host_line = case
        when v_win is null then 'It''s a tie — what a game! ' ||
             s.score_a || ' to ' || s.score_b || '.'
        else 'Team ' || v_win || ' wins ' ||
             greatest(s.score_a, s.score_b) || ' to ' ||
             least(s.score_a, s.score_b) || '!' end,
      updated_at = now()
    where game_id = p_game;
    update public.games
      set status = 'finished', updated_at = now() where id = p_game;
    return jsonb_build_object('ok', true, 'phase', 'game_over');
  end if;

  if v_next = s.words_per_half then
    update public.game_state set
      phase = 'halftime',
      word_index = v_next,
      pending_clue = null,
      host_line = 'Halftime! Teams, switch clue-giver and guesser. Score: ' ||
                  s.score_a || ' – ' || s.score_b || '.',
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object('ok', true, 'phase', 'halftime');
  end if;

  -- Alternate on who actually held the floor, not on the word number.
  v_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
  update public.game_state set
    word_index = v_next,
    cluing_team = v_team,
    step = 'awaiting_clue',
    exchange_count = 0,
    pending_clue = null,
    last_outcome = 'none',
    host_line = public.mw_clue_prompt(p_game, v_team, s.phase),
    updated_at = now()
  where game_id = p_game;
  return jsonb_build_object('ok', true, 'phase', s.phase);
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Second half opens with the team that did not close the first half.
-- -----------------------------------------------------------------------------
create or replace function public.mw_begin_second_half(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.game_state%rowtype;
  v_host uuid;
  v_team text;
begin
  select host_id into v_host from public.games where id = p_game;
  if v_host is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_host <> auth.uid() then
    return jsonb_build_object('ok', false, 'reason', 'not_host');
  end if;

  select * into s from public.game_state where game_id = p_game for update;
  if not found or s.phase <> 'halftime' then
    return jsonb_build_object('ok', false, 'reason', 'not_halftime');
  end if;

  v_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
  update public.game_state set
    phase = 'second_half',
    cluing_team = v_team,
    step = 'awaiting_clue',
    exchange_count = 0,
    pending_clue = null,
    last_outcome = 'none',
    host_line = public.mw_clue_prompt(p_game, v_team, 'second_half'),
    updated_at = now()
  where game_id = p_game;

  return jsonb_build_object('ok', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. A clue may only be used once per word.
-- -----------------------------------------------------------------------------
create or replace function public.mw_submit_clue(p_game uuid, p_text text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.game_state%rowtype;
  v_role text;
  v_name text;
  v_text text := btrim(p_text);
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if v_text = '' then
    return jsonb_build_object('ok', false, 'reason', 'empty');
  end if;

  select * into s from public.game_state where game_id = p_game for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if s.phase not in ('first_half', 'second_half') or s.step <> 'awaiting_clue' then
    return jsonb_build_object('ok', false, 'reason', 'not_awaiting_clue');
  end if;

  v_role := public.mw_clue_giver_role(s.cluing_team, s.phase);
  if not public.mw_actor_ok(p_game, v_role) then
    return jsonb_build_object('ok', false, 'reason', 'not_your_turn');
  end if;

  -- Already spent on this word (by either team) — the next side would have
  -- nothing new to solve.
  if exists (
    select 1 from public.game_plays gp
    where gp.game_id = p_game
      and gp.word_index = s.word_index
      and gp.kind = 'clue'
      and public.mw_norm_word(gp.text) = public.mw_norm_word(v_text)
  ) then
    return jsonb_build_object('ok', false, 'reason', 'clue_already_used');
  end if;

  select display_name into v_name
  from public.game_players where game_id = p_game and role = v_role;

  insert into public.game_plays
    (game_id, word_index, kind, team, role, player_name, text)
  values
    (p_game, s.word_index, 'clue', s.cluing_team, v_role,
     coalesce(v_name, 'Player ' || v_role), v_text);

  update public.game_state set
    step = 'awaiting_guess',
    pending_clue = v_text,
    host_line = (public.mw_guesser_role(s.cluing_team, s.phase)) ||
                ' — what is your guess?',
    updated_at = now()
  where game_id = p_game;

  return jsonb_build_object('ok', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Re-sync human seat names from their profile.
-- -----------------------------------------------------------------------------
-- game_players.display_name is written when a player takes a seat, so a name
-- set or corrected later never reached the stage. Any game member may call
-- this; it only ever copies a profile's own first_name onto that profile's seat.
create or replace function public.mw_refresh_seat_names(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int := 0;
  v_names   jsonb;
begin
  if not public.mw_is_game_member(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'not_member');
  end if;

  with fixed as (
    update public.game_players gp
       set display_name = p.first_name,
           first_name   = p.first_name
      from public.profiles p
     where gp.game_id = p_game
       and gp.profile_id = p.id
       and gp.is_ai = false
       and btrim(p.first_name) <> ''
       and gp.display_name <> p.first_name
    returning 1
  )
  select count(*) into v_updated from fixed;

  -- Return the live roster so the client can apply names without a re-fetch.
  select coalesce(jsonb_object_agg(role, display_name), '{}'::jsonb)
    into v_names
    from public.game_players
   where game_id = p_game;

  return jsonb_build_object('ok', true, 'updated', v_updated, 'names', v_names);
end;
$$;

grant execute on function public.mw_refresh_seat_names(uuid) to authenticated;
