-- =============================================================================
-- 0021 — Persist last_outcome = 'wrong' on steals so Guy's red-flag clip plays
-- =============================================================================
-- Online steals previously wrote last_outcome = 'none' (and the column check
-- didn't even allow 'wrong'), so the client never switched off the listening
-- pose. Green-flag "guessed" worked; red-flag "wrong" did not.

alter table public.game_state
  drop constraint if exists game_state_last_outcome_check;

alter table public.game_state
  add constraint game_state_last_outcome_check
  check (last_outcome in ('none', 'guessed', 'revealed', 'wrong'));

create or replace function public.mw_submit_guess(p_game uuid, p_text text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  s public.game_state%rowtype;
  v_role text;
  v_text text := public.mw_norm_word(p_text);
  v_word text;
  v_correct boolean;
  v_foul    boolean;
  v_used int;
  v_next_team text;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if v_text is null or v_text = '' then
    return jsonb_build_object('ok', false, 'reason', 'empty');
  end if;

  select * into s from public.game_state where game_id = p_game for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_state');
  end if;
  if s.step is distinct from 'awaiting_guess' then
    return jsonb_build_object('ok', false, 'reason', 'not_awaiting_guess');
  end if;

  v_role := public.mw_guesser_role(s.cluing_team, s.phase);
  if not public.mw_is_player_role(p_game, v_role) then
    return jsonb_build_object('ok', false, 'reason', 'not_your_turn');
  end if;

  select word into v_word
  from public.game_words
  where game_id = p_game and word_index = s.word_index;
  if v_word is null then
    return jsonb_build_object('ok', false, 'reason', 'no_secret');
  end if;

  -- Repeating the clue is a foul — never counts as a correct guess.
  v_foul := s.pending_clue is not null
            and public.mw_word_matches(v_text, s.pending_clue);
  v_correct := (not v_foul) and public.mw_word_matches(v_text, v_word);

  insert into public.game_plays(
    game_id, word_index, kind, team, role, player_id, player_name, text, correct
  ) values (
    p_game, s.word_index, 'guess', s.cluing_team, v_role, uid,
    coalesce((select display_name from public.profiles where id = uid), 'Player'),
    v_text, v_correct
  );

  if v_correct then
    update public.game_state set
      score_a = score_a + case when s.cluing_team = 'A' then s.word_value else 0 end,
      score_b = score_b + case when s.cluing_team = 'B' then s.word_value else 0 end,
      step = 'resolved',
      pending_clue = null,
      last_outcome = 'guessed',
      host_line = 'Team ' || s.cluing_team || ' guessed “' || v_word || '”! +'
                  || s.word_value || ' points.',
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object(
      'ok', true, 'correct', true, 'foul', false,
      'word', v_word, 'word_index', s.word_index
    );
  end if;

  v_used := s.exchange_count + 1;
  if v_used >= s.max_exchanges then
    update public.game_state set
      exchange_count = v_used,
      step = 'resolved',
      pending_clue = null,
      last_outcome = 'revealed',
      host_line = 'Time’s up! The word was “' || v_word || '”. No points.',
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object(
      'ok', true, 'correct', false, 'revealed', true, 'foul', v_foul,
      'word', v_word, 'word_index', s.word_index
    );
  end if;

  v_next_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
  update public.game_state set
    cluing_team = v_next_team,
    step = 'awaiting_clue',
    exchange_count = v_used,
    pending_clue = null,
    last_outcome = 'wrong',
    host_line = case when v_foul
      then 'Foul! You can''t guess the clue. Steal! '
           || public.mw_clue_prompt(p_game, v_next_team, s.phase)
      else 'A steal! ' || public.mw_clue_prompt(p_game, v_next_team, s.phase)
    end,
    updated_at = now()
  where game_id = p_game;
  return jsonb_build_object(
    'ok', true, 'correct', false, 'foul', v_foul,
    'word', v_word, 'word_index', s.word_index
  );
end;
$$;
