-- =============================================================================
-- 0033_playtest_pass_five_rounds.sql
-- =============================================================================
-- Ronna Sep 2026 table playtest:
--   * 5 words per half (10 total) — 8 rounds felt too long
--   * Pass on a clue (button, spoken "pass", or the timer)
--   * mw_submit_guess uses mw_actor_ok (host may drive stand-in seats) and
--     keeps last_outcome = 'wrong' on a steal so the red flag plays
--   * Host may submit pass/time tokens so a stalled human turn cannot freeze
--     the table
--
-- Word bank is unchanged from 0032 (clue-safe curated set).

alter table public.game_state
  alter column words_per_half set default 5;

comment on column public.game_state.words_per_half is
  'Secret words per half (5 × 2 = 10 words; Ronna Sep 2026 playtest).';

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
  v_wph    int  := 5;
  v_total  int;
  v_team   text;
  i        int := 0;
  v_word   text;
  v_bank   text[] := array[
    'Ant','Apple','Apron','Artist','Attic','Autumn','Baby','Baker',
    'Balloon','Banana','Bank','Barber','Baseball','Basement','Basket','Basketball',
    'Bathroom','Beach','Bear','Bed','Bedroom','Bee','Belt','Bicycle',
    'Birthday','Blanket','Boat','Book','Bottle','Bowl','Box','Bread',
    'Bridge','Broom','Brother','Bucket','Bus','Butter','Butterfly','Button',
    'Cake','Camera','Candle','Car','Carpenter','Carrot','Castle','Cat',
    'Cave','Chair','Cheese','Chef','Chess','Chicken','Chocolate','Church',
    'City','Clock','Cloud','Coat','Coffee','Computer','Cookie','Cow',
    'Crab','Curtain','Dentist','Desert','Doctor','Dog','Dolphin','Donut',
    'Door','Dress','Drum','Duck','Eagle','Ear','Egg','Elbow',
    'Elephant','Evening','Eye','Farmer','Father','Fence','Firefighter','Fishing',
    'Flag','Flower','Flute','Fog','Foot','Football','Forest','Fork',
    'Fox','Friend','Frog','Frost','Garage','Garden','Garlic','Giraffe',
    'Glove','Goat','Golf','Grandfather','Grandmother','Grape','Guitar','Hair',
    'Hammer','Hand','Harp','Hat','Heart','Helicopter','Hockey','Holiday',
    'Honey','Horse','Hospital','Hotel','Husband','Icecream','Island','Jacket',
    'Juice','Kettle','Key','Kitchen','Kite','Knee','Knife','Ladder',
    'Lake','Lamp','Lemon','Letter','Librarian','Library','Lightning','Lion',
    'Map','Market','Mechanic','Milk','Mirror','Money','Monkey','Moon',
    'Morning','Mother','Motorcycle','Mountain','Mouse','Movie','Muffin','Museum',
    'Mushroom','Musician','Needle','Neighbor','Nose','Nurse','Ocean','Onion',
    'Oven','Owl','Painting','Pajama','Pancake','Pants','Park','Pasta',
    'Pen','Pencil','Penguin','Phone','Piano','Pie','Pig','Pillow',
    'Pilot','Pizza','Plate','Plumber','Police','Popcorn','Potato','Purse',
    'Puzzle','Rabbit','Radio','Rain','Rainbow','Restaurant','Ribbon','Rice',
    'River','Rocket','Roof','Rope','Sailor','Salt','Sandwich','Scarf',
    'School','Shark','Sheep','Ship','Shirt','Shoe','Shovel','Sister',
    'Snail','Snake','Snow','Soccer','Sock','Soldier','Song','Soup',
    'Spider','Spoon','Spring','Squirrel','Stadium','Star','Storm','Strawberry',
    'Sugar','Summer','Sun','Sweater','Swimming','Table','Taxi','Tea',
    'Teacher','Teapot','Television','Tennis','Thunder','Tiger','Tomato','Tooth',
    'Towel','Tractor','Train','Trophy','Truck','Trumpet','Tunnel','Turtle',
    'Twin','Valley','Village','Violin','Volcano','Waffle','Wagon','Wall',
    'Watch','Wedding','Whale','Wife','Wind','Window','Winter','Wolf',
    'Wrench','Zebra'
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

-- -----------------------------------------------------------------------------
-- Pass / skip a clue. Host may submit pass/time for a stalled human turn.
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
  v_norm text;
  v_pass boolean;
  v_host uuid;
  v_used int;
  v_next_team text;
  v_word text;
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
-- Guess: restore mw_actor_ok, last_outcome = wrong on steal, pass = miss.
-- -----------------------------------------------------------------------------
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
      host_line = 'Team ' || s.cluing_team || ' guessed “' || v_word ||
                  '”! +' || v_value || ' points.',
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
      host_line = 'Time''s up! The word was “' || v_word || '”. No points.',
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
    host_line = case
      when v_foul then 'Foul! You can''t guess the clue. Steal! '
        || public.mw_clue_prompt(p_game, v_next_team, s.phase)
      when v_pass and v_norm = 'time' then 'Time''s up! A steal! '
        || public.mw_clue_prompt(p_game, v_next_team, s.phase)
      when v_pass then 'Passed! A steal! '
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
