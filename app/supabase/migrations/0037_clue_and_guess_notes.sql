-- =============================================================================
-- 0037_clue_and_guess_notes.sql
-- =============================================================================
-- Ronna (Sep 2026): both the clue dock and the guess dock say
-- "Something went wrong. Please try again." and the word does not register.
--
-- A miss, a Pass, and the clock all write last_outcome = 'wrong'. If that
-- value is not allowed, Postgres throws the whole send away. The phone then
-- prints the generic note and leaves the same player on the clock.
-- A clue Pass hits the same wall, which is why the clue dock shows it too.
--
-- This script is safe to run on its own (it includes the guess function).
-- Run it in the Supabase SQL editor.
-- =============================================================================

alter table public.game_state
  drop constraint if exists game_state_last_outcome_check;

alter table public.game_state
  add constraint game_state_last_outcome_check
  check (last_outcome in ('none', 'guessed', 'revealed', 'wrong'));

-- Older guess code inserted player_id. If that column was added and left
-- required, every clue and every guess is rejected.
alter table public.game_plays
  add column if not exists player_id uuid;

alter table public.game_plays
  alter column player_id drop not null;

create or replace function public.mw_norm_word(p_text text)
returns text
language sql
immutable
as $$
  select regexp_replace(
           regexp_replace(
             btrim(lower(coalesce(p_text, ''))),
             '[[:space:]]+', ' ', 'g'
           ),
           '[^a-z0-9 ]', '', 'g'
         );
$$;

create or replace function public.mw_word_matches(p_guess text, p_word text)
returns boolean
language sql
immutable
as $$
  select length(public.mw_norm_word(p_word)) > 0
     and public.mw_norm_word(p_guess) = public.mw_norm_word(p_word);
$$;

grant execute on function public.mw_norm_word(text) to authenticated;

-- Clue: a Pass / the clock must move the turn even if 'wrong' is rejected.
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
  v_text text := btrim(coalesce(p_text, ''));
  v_norm text;
  v_pass boolean;
  v_host uuid;
  v_used int;
  v_next_team text;
  v_word text;
  v_guesser text;
  v_guesser_name text;
  v_host_line text;
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
          then 'Time''s up! The word was "' || coalesce(v_word, '') || '". No points.'
          else 'Passed! The word was "' || coalesce(v_word, '') || '". No points.'
        end,
        updated_at = now()
      where game_id = p_game;
      return jsonb_build_object('ok', true, 'passed', true, 'revealed', true);
    end if;

    v_next_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
    v_host_line := case when v_norm = 'time'
      then 'Time''s up! A steal! '
      else 'Passed! A steal! '
    end || public.mw_clue_prompt(p_game, v_next_team, s.phase);

    begin
      update public.game_state set
        cluing_team = v_next_team,
        step = 'awaiting_clue',
        exchange_count = v_used,
        pending_clue = null,
        last_outcome = 'wrong',
        host_line = v_host_line,
        updated_at = now()
      where game_id = p_game;
    exception
      when check_violation then
        update public.game_state set
          cluing_team = v_next_team,
          step = 'awaiting_clue',
          exchange_count = v_used,
          pending_clue = null,
          last_outcome = 'none',
          host_line = v_host_line,
          updated_at = now()
        where game_id = p_game;
    end;
    return jsonb_build_object('ok', true, 'passed', true);
  end if;

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


-- Guess: a miss must move the turn even if 'wrong' is still rejected.
create or replace function public.mw_submit_guess(p_game uuid, p_text text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.game_state%rowtype;
  v_role    text;
  v_name    text;
  v_word    text;
  v_text    text := btrim(coalesce(p_text, ''));
  v_norm    text;
  v_pass    boolean;
  v_host    uuid;
  v_correct boolean;
  v_foul    boolean;
  v_value   int;
  v_used    int;
  v_next_team text;
  v_host_line text;
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
  if s.phase not in ('first_half', 'second_half') or s.step <> 'awaiting_guess' then
    return jsonb_build_object('ok', false, 'reason', 'not_awaiting_guess');
  end if;

  v_role := public.mw_guesser_role(s.cluing_team, s.phase);
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

  select word into v_word
  from public.game_words where game_id = p_game and word_index = s.word_index;

  if v_word is null or length(btrim(v_word)) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_secret');
  end if;

  select display_name into v_name
  from public.game_players where game_id = p_game and role = v_role;

  v_foul := (not v_pass) and s.pending_clue is not null
            and public.mw_word_matches(v_text, s.pending_clue);
  v_correct := (not v_pass) and (not v_foul) and public.mw_word_matches(v_text, v_word);

  insert into public.game_plays
    (game_id, word_index, kind, team, role, player_name, text, correct)
  values
    (p_game, s.word_index, 'guess', s.cluing_team, v_role,
     coalesce(v_name, 'Player ' || v_role),
     case when v_pass and v_norm = 'time' then 'TIME'
          when v_pass then 'PASS'
          else v_text end,
     v_correct);

  if v_correct then
    v_value := public.mw_word_value(s.word_value, s.exchange_count);
    update public.game_state set
      score_a = score_a + case when s.cluing_team = 'A' then v_value else 0 end,
      score_b = score_b + case when s.cluing_team = 'B' then v_value else 0 end,
      step = 'resolved',
      pending_clue = null,
      last_outcome = 'guessed',
      host_line = 'Team ' || s.cluing_team || ' guessed "' || v_word ||
                  '"! +' || v_value || ' points.',
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object(
      'ok', true, 'correct', true, 'word', v_word, 'word_index', s.word_index
    );
  end if;

  v_used := s.exchange_count + 1;
  if v_used >= s.max_exchanges then
    update public.game_state set
      exchange_count = v_used,
      step = 'resolved',
      pending_clue = null,
      last_outcome = 'revealed',
      host_line = 'Time''s up! The word was "' || v_word || '". No points.',
      updated_at = now()
    where game_id = p_game;
    return jsonb_build_object(
      'ok', true, 'correct', false, 'revealed', true, 'foul', v_foul,
      'word', v_word, 'word_index', s.word_index
    );
  end if;

  v_next_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
  v_host_line := case
    when v_foul then 'Foul! You can''t guess the clue. Steal! '
      || public.mw_clue_prompt(p_game, v_next_team, s.phase)
    when v_pass and v_norm = 'time' then 'Time''s up! A steal! '
      || public.mw_clue_prompt(p_game, v_next_team, s.phase)
    when v_pass then 'Passed! A steal! '
      || public.mw_clue_prompt(p_game, v_next_team, s.phase)
    else 'A steal! ' || public.mw_clue_prompt(p_game, v_next_team, s.phase)
  end;

  -- Prefer the red-flag outcome. If this database still rejects 'wrong',
  -- advance the turn with 'none' so the guess is not thrown away.
  begin
    update public.game_state set
      cluing_team = v_next_team,
      step = 'awaiting_clue',
      exchange_count = v_used,
      pending_clue = null,
      last_outcome = 'wrong',
      host_line = v_host_line,
      updated_at = now()
    where game_id = p_game;
  exception
    when check_violation then
      update public.game_state set
        cluing_team = v_next_team,
        step = 'awaiting_clue',
        exchange_count = v_used,
        pending_clue = null,
        last_outcome = 'none',
        host_line = v_host_line,
        updated_at = now()
      where game_id = p_game;
  end;

  return jsonb_build_object(
    'ok', true, 'correct', false, 'foul', v_foul,
    'word', v_word, 'word_index', s.word_index
  );
end;
$$;
