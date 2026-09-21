-- =============================================================================
-- 0034_clear_outcome_on_clue.sql
-- =============================================================================
-- Second-half stall (Ronna, Sep 2026): after a steal, last_outcome stayed
-- 'wrong'. The next clue moved the step to awaiting_guess but left that flag,
-- so the client treated the new guesser as having just missed and asked them
-- again. A normal clue now clears the outcome and names the guesser.
--
-- Pass / time behavior is unchanged from 0033 (host may submit those tokens).
-- Run this in the Supabase SQL editor if migrations are applied by hand.

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
  v_norm text;
  v_pass boolean;
  v_host uuid;
  v_used int;
  v_next_team text;
  v_word text;
  v_guesser text;
  v_guesser_name text;
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
  v_norm := public.mw_norm_word(v_text);
  v_pass := v_norm in ('pass', 'passed', 'skip', 'time');

  if not public.mw_actor_ok(p_game, v_role) then
    if not v_pass then
      return jsonb_build_object('ok', false, 'reason', 'not_your_turn');
    end if;
    select host_id into v_host from public.games where id = p_game;
    if v_host is distinct from auth.uid() then
      return jsonb_build_object('ok', false, 'reason', 'not_your_turn');
    end if;
  end if;

  select display_name into v_name
  from public.game_players where game_id = p_game and role = v_role;

  if v_pass then
    insert into public.game_plays
      (game_id, word_index, kind, team, role, player_name, text)
    values
      (p_game, s.word_index, 'clue', s.cluing_team, v_role,
       coalesce(v_name, 'Player ' || v_role),
       case when v_norm = 'time' then 'TIME' else 'PASS' end);

    select word into v_word
    from public.game_words where game_id = p_game and word_index = s.word_index;

    v_used := s.exchange_count + 1;
    if v_used >= s.max_exchanges then
      update public.game_state set
        exchange_count = v_used,
        step = 'resolved',
        pending_clue = null,
        last_outcome = 'revealed',
        host_line = case when v_norm = 'time'
          then 'Time''s up! The word was “' || coalesce(v_word, '') || '”. No points.'
          else 'Passed! The word was “' || coalesce(v_word, '') || '”. No points.'
        end,
        updated_at = now()
      where game_id = p_game;
      return jsonb_build_object('ok', true, 'passed', true, 'revealed', true);
    end if;

    v_next_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
    update public.game_state set
      cluing_team = v_next_team,
      step = 'awaiting_clue',
      exchange_count = v_used,
      pending_clue = null,
      last_outcome = 'wrong',
      host_line = case when v_norm = 'time'
        then 'Time''s up! A steal! '
        else 'Passed! A steal! '
      end || public.mw_clue_prompt(p_game, v_next_team, s.phase),
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object('ok', true, 'passed', true);
  end if;

  -- Already spent on this word (by either team).
  if exists (
    select 1 from public.game_plays gp
    where gp.game_id = p_game
      and gp.word_index = s.word_index
      and gp.kind = 'clue'
      and public.mw_norm_word(gp.text) = v_norm
      and public.mw_norm_word(gp.text) not in ('pass', 'passed', 'skip', 'time')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'clue_already_used');
  end if;

  insert into public.game_plays
    (game_id, word_index, kind, team, role, player_name, text)
  values
    (p_game, s.word_index, 'clue', s.cluing_team, v_role,
     coalesce(v_name, 'Player ' || v_role), v_text);

  v_guesser := public.mw_guesser_role(s.cluing_team, s.phase);
  select display_name into v_guesser_name
  from public.game_players where game_id = p_game and role = v_guesser;

  update public.game_state set
    step = 'awaiting_guess',
    pending_clue = v_text,
    last_outcome = 'none',
    host_line = coalesce(nullif(btrim(v_guesser_name), ''), 'Player ' || v_guesser)
                || ', what is your guess?',
    updated_at = now()
  where game_id = p_game;

  return jsonb_build_object('ok', true);
end;
$$;
