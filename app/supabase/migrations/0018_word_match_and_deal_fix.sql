-- =============================================================================
-- 0018 — Harden word matching + deal distinct secrets
--
-- Correct guesses (e.g. "Mountain") were rejected when the secret row was
-- missing (null → always-false match) or when punctuation slipped in. The old
-- deal loop could also pick the same bank word twice.
-- =============================================================================

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

-- Deal distinct words shuffled by game id (no offset-into-rehash collisions).
create or replace function public.mw_begin_play(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_host   uuid;
  v_status text;
  v_wph    int  := 4;
  v_total  int;
  v_team   text;
  i        int := 0;
  v_word   text;
  v_bank   text[] := array[
    'Kitchen','Garden','Window','Blanket','Teapot','Pillow','Candle','Mirror',
    'Apple','Butter','Cookie','Coffee','Honey','Lemon','Pancake','Popcorn',
    'Sunshine','Rainbow','Mountain','River','Flower','Meadow','Snowman','Breeze',
    'Puppy','Kitten','Rabbit','Robin','Butterfly','Squirrel','Penguin','Turtle',
    'Grandma','Postcard','Bicycle','Picnic','Quilt','Puzzle','Melody','Birthday'
  ];
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
  if v_status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'reason', 'not_started');
  end if;

  if exists (select 1 from public.game_state where game_id = p_game) then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  v_total := v_wph * 2;

  for v_word in
    select w
    from unnest(v_bank) as w
    order by md5(w || p_game::text)
    limit v_total
  loop
    insert into public.game_words (game_id, word_index, word)
    values (p_game, i, v_word);
    i := i + 1;
  end loop;

  if i < v_total then
    return jsonb_build_object('ok', false, 'reason', 'deal_failed');
  end if;

  v_team := public.mw_starting_team(0);
  insert into public.game_state
    (game_id, phase, word_index, cluing_team, step, words_per_half, host_line)
  values
    (p_game, 'first_half', 0, v_team, 'awaiting_clue', v_wph,
     public.mw_clue_prompt(p_game, v_team, 'first_half'));

  return jsonb_build_object('ok', true);
end;
$$;

-- Same rules as 0007, plus a hard fail when the secret row is missing so a
-- guess can never be silently marked wrong against a null word.
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
  v_correct boolean;
  v_value   int;
  v_used    int;
  v_next_team text;
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
  if not public.mw_actor_ok(p_game, v_role) then
    return jsonb_build_object('ok', false, 'reason', 'not_your_turn');
  end if;

  select word into v_word
  from public.game_words where game_id = p_game and word_index = s.word_index;

  if v_word is null or length(btrim(v_word)) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_secret');
  end if;

  select display_name into v_name
  from public.game_players where game_id = p_game and role = v_role;

  v_correct := public.mw_word_matches(v_text, v_word);

  insert into public.game_plays
    (game_id, word_index, kind, team, role, player_name, text, correct)
  values
    (p_game, s.word_index, 'guess', s.cluing_team, v_role,
     coalesce(v_name, 'Player ' || v_role), v_text, v_correct);

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
    return jsonb_build_object('ok', true, 'correct', true);
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
    return jsonb_build_object('ok', true, 'correct', false, 'revealed', true);
  end if;

  v_next_team := case when s.cluing_team = 'A' then 'B' else 'A' end;
  update public.game_state set
    cluing_team = v_next_team,
    step = 'awaiting_clue',
    exchange_count = v_used,
    pending_clue = null,
    last_outcome = 'none',
    host_line = 'A steal! ' || public.mw_clue_prompt(p_game, v_next_team, s.phase),
    updated_at = now()
  where game_id = p_game;
  return jsonb_build_object('ok', true, 'correct', false);
end;
$$;
