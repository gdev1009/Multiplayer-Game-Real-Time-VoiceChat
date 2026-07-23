-- Match Word — Milestone 5 schema
-- Core Gameplay Engine: server-authoritative turns, steals, auto-reveal,
-- scoring, and the first-half / halftime / second-half role switch.
-- Run this in the Supabase SQL editor after 0006_lobby_rls_fix.sql.
--
-- Design notes
-- ------------
-- * The authoritative rules live here and are mirrored 1:1 by the pure-Dart
--   engine in app/lib/features/game/game_engine.dart (and its tests), so the
--   client can render optimistically while the server stays the source of
--   truth. Keep the two in lock-step when either changes.
-- * A game (from 0004_lobby.sql) that is 'in_progress' gets exactly one
--   game_state row plus a dealt list of game_words. Every clue and guess is
--   appended to game_plays (the shared real-time feed).
-- * All writes are server-authoritative: clients only ever read these tables
--   (RLS SELECT policies via mw_is_game_member); the SECURITY DEFINER functions
--   below are the only write path.
-- * Roles: Team A = seats 0/2 (A1/A2), Team B = seats 1/3 (B1/B2). In the first
--   half role '1' gives clues and role '2' guesses; at halftime they switch.

-- =============================================================================
-- Membership helper (mirrors 0006_lobby_rls_fix.sql).
-- Defined here with `create or replace` so this migration is self-sufficient
-- and can be applied even if 0006 has not run yet. It is RLS-safe (SECURITY
-- DEFINER, so RLS is not re-applied inside it) and is used by the SELECT
-- policies below. Running it again after 0006 is a harmless no-op.
-- =============================================================================
create or replace function public.mw_is_game_member(p_game uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.game_players gp
    where gp.game_id = p_game
      and gp.profile_id = auth.uid()
  );
$$;

grant execute on function public.mw_is_game_member(uuid) to authenticated;

-- =============================================================================
-- game_state  (one row per in-progress game — the live match snapshot)
-- =============================================================================
create table if not exists public.game_state (
  game_id        uuid primary key references public.games (id) on delete cascade,
  phase          text not null default 'first_half'
                   check (phase in ('first_half', 'halftime', 'second_half', 'game_over')),
  word_index     int  not null default 0,
  cluing_team    text not null default 'A' check (cluing_team in ('A', 'B')),
  step           text not null default 'awaiting_clue'
                   check (step in ('awaiting_clue', 'awaiting_guess', 'resolved')),
  exchange_count int  not null default 0,
  score_a        int  not null default 0,
  score_b        int  not null default 0,
  pending_clue   text,
  last_outcome   text not null default 'none'
                   check (last_outcome in ('none', 'guessed', 'revealed')),
  host_line      text not null default '',
  words_per_half int  not null default 4,
  max_exchanges  int  not null default 5,
  word_value     int  not null default 5,
  updated_at     timestamptz not null default now()
);

comment on table public.game_state is
  'Live, server-authoritative snapshot of an in-progress Match Word game. '
  'Mirrors the Dart MatchState in app/lib/features/game/game_engine.dart.';

-- =============================================================================
-- game_words  (the secret words dealt for a game, in play order)
-- =============================================================================
create table if not exists public.game_words (
  game_id    uuid not null references public.games (id) on delete cascade,
  word_index int  not null,
  word       text not null,
  primary key (game_id, word_index)
);

-- =============================================================================
-- game_plays  (the shared feed: one row per clue or guess)
-- =============================================================================
create table if not exists public.game_plays (
  id          uuid primary key default gen_random_uuid(),
  game_id     uuid not null references public.games (id) on delete cascade,
  word_index  int  not null,
  kind        text not null check (kind in ('clue', 'guess')),
  team        text not null check (team in ('A', 'B')),
  role        text not null check (role in ('A1', 'A2', 'B1', 'B2')),
  player_name text not null,
  text        text not null,
  correct     boolean,
  created_at  timestamptz not null default now()
);

create index if not exists game_plays_game_idx
  on public.game_plays (game_id, created_at);

-- =============================================================================
-- Rules helpers (kept identical to the Dart MatchEngine).
-- =============================================================================

-- The team that opens a given word — teams alternate who starts.
create or replace function public.mw_starting_team(p_word_index int)
returns text language sql immutable as $$
  select case when p_word_index % 2 = 0 then 'A' else 'B' end;
$$;

-- Clue-giver role for a team in a phase (role switch at halftime).
create or replace function public.mw_clue_giver_role(p_team text, p_phase text)
returns text language sql immutable as $$
  select p_team || case when p_phase = 'second_half' then '2' else '1' end;
$$;

-- Guesser role for a team in a phase.
create or replace function public.mw_guesser_role(p_team text, p_phase text)
returns text language sql immutable as $$
  select p_team || case when p_phase = 'second_half' then '1' else '2' end;
$$;

-- Case/whitespace-insensitive word comparison.
create or replace function public.mw_word_matches(p_guess text, p_word text)
returns boolean language sql immutable as $$
  select length(btrim(lower(p_word))) > 0
     and regexp_replace(btrim(lower(p_guess)), '\s+', ' ', 'g')
       = regexp_replace(btrim(lower(p_word)),  '\s+', ' ', 'g');
$$;

-- Current point value of the word given exchanges spent (floor 1).
create or replace function public.mw_word_value(p_base int, p_exchanges int)
returns int language sql immutable as $$
  select greatest(1, p_base - p_exchanges);
$$;

-- The host's "give a clue" prompt for a team/phase.
create or replace function public.mw_clue_prompt(p_game uuid, p_team text, p_phase text)
returns text language plpgsql stable as $$
declare
  v_role text := public.mw_clue_giver_role(p_team, p_phase);
  v_name text;
begin
  select display_name into v_name
  from public.game_players
  where game_id = p_game and role = v_role;
  v_name := coalesce(v_name, 'Player ' || v_role);
  return v_name || ', give a one-word clue.';
end;
$$;

-- =============================================================================
-- Begin play: deal words and create the game_state for an in-progress game.
-- Idempotent — a second call is a no-op once state exists. Host only.
-- Returns: { ok } or { ok:false, reason }
-- =============================================================================
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
  v_wph    int  := 4;   -- words per half
  v_total  int;
  v_team   text;
  i        int;
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

  -- Already dealt? Idempotent success.
  if exists (select 1 from public.game_state where game_id = p_game) then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  v_total := v_wph * 2;

  -- Deal `v_total` distinct words in random order.
  for i in 0 .. v_total - 1 loop
    v_word := (
      select w from unnest(v_bank) as w
      order by md5(w || p_game::text || i::text)
      offset i limit 1
    );
    insert into public.game_words (game_id, word_index, word)
    values (p_game, i, v_word);
  end loop;

  v_team := public.mw_starting_team(0);
  insert into public.game_state
    (game_id, phase, word_index, cluing_team, step, words_per_half, host_line)
  values
    (p_game, 'first_half', 0, v_team, 'awaiting_clue', v_wph,
     public.mw_clue_prompt(p_game, v_team, 'first_half'));

  return jsonb_build_object('ok', true);
end;
$$;

-- =============================================================================
-- Internal: the seat/role the current user may act as on the clock, or null.
-- Verifies the caller is the on-the-clock player for `p_expected_step`. The
-- host may also act for a computer (AI) seat so play never stalls.
-- =============================================================================
create or replace function public.mw_actor_ok(p_game uuid, p_role text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_profile uuid;
  v_is_ai   boolean;
  v_host    uuid;
begin
  select profile_id, is_ai into v_profile, v_is_ai
  from public.game_players
  where game_id = p_game and role = p_role;

  if v_profile = v_uid then
    return true;
  end if;

  -- Host may drive computer-filled seats.
  select host_id into v_host from public.games where id = p_game;
  return coalesce(v_is_ai, false) and v_host = v_uid;
end;
$$;

-- =============================================================================
-- Submit a one-word clue. Caller must be the on-the-clock clue-giver.
-- Returns: { ok } or { ok:false, reason }
-- =============================================================================
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

-- =============================================================================
-- Submit a guess. Caller must be the on-the-clock guesser. Resolves the word:
-- score on a match, steal to the other team on a miss, or auto-reveal once the
-- exchange limit is reached.
-- Returns: { ok, correct } or { ok:false, reason }
-- =============================================================================
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
  v_text    text := btrim(p_text);
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
    return jsonb_build_object('ok', true, 'correct', false);
  end if;

  -- Steal: the other team gets a fresh clue for reduced value.
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

-- =============================================================================
-- Advance off the resolved beat to the next word, halftime, or game-over.
-- Any member may call it (or a client timer); a no-op unless step = 'resolved'.
-- Returns: { ok, phase }
-- =============================================================================
create or replace function public.mw_next_word(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.game_state%rowtype;
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

-- =============================================================================
-- Leave halftime and deal the first word of the second half (roles switched).
-- Host only. Returns: { ok }
-- =============================================================================
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

  v_team := public.mw_starting_team(s.word_index);
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

-- =============================================================================
-- Row Level Security — SELECT only for members; writes via the functions above.
-- =============================================================================
alter table public.game_state enable row level security;
alter table public.game_words enable row level security;
alter table public.game_plays enable row level security;

drop policy if exists "game_state_select_member" on public.game_state;
create policy "game_state_select_member"
  on public.game_state for select
  using (public.mw_is_game_member(game_id));

drop policy if exists "game_words_select_member" on public.game_words;
create policy "game_words_select_member"
  on public.game_words for select
  using (public.mw_is_game_member(game_id));

drop policy if exists "game_plays_select_member" on public.game_plays;
create policy "game_plays_select_member"
  on public.game_plays for select
  using (public.mw_is_game_member(game_id));

-- Realtime: push live state + feed updates to seated players.
alter publication supabase_realtime add table public.game_state;
alter publication supabase_realtime add table public.game_plays;

-- Least-privilege execute grants.
grant execute on function public.mw_begin_play(uuid)            to authenticated;
grant execute on function public.mw_submit_clue(uuid, text)     to authenticated;
grant execute on function public.mw_submit_guess(uuid, text)    to authenticated;
grant execute on function public.mw_next_word(uuid)             to authenticated;
grant execute on function public.mw_begin_second_half(uuid)     to authenticated;
