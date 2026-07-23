-- Prevent mw_next_word from running during halftime / game_over.
-- A second advance while step is still 'resolved' at halftime was able to
-- skip the break and desync phase (early game-over at Word 4 of 8).

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

  v_team := public.mw_starting_team(v_next);
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
