-- Vary studio-player names per game (not always Buddy / Rosie / Pearl by seat).
-- Names are a deterministic shuffle of a larger pool keyed by game id, skipping
-- names already taken by seated humans.

create or replace function public.mw_fill_seats(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_host      uuid;
  v_max       int;
  v_status    text;
  v_seat      int;
  v_added     int := 0;
  v_pool      text[] := array[
    'Sunny', 'Rosie', 'Buddy', 'Pearl', 'Gus', 'Mabel', 'Otis', 'Ada',
    'Walter', 'Rosa', 'Frank', 'Helen', 'Betty', 'Joe', 'Doris', 'Sam',
    'Nancy', 'Bill', 'Grace', 'Tom', 'Linda', 'Arthur', 'Margaret', 'Max'
  ];
  v_taken     text[] := array[]::text[];
  v_shuffled  text[];
  v_name      text;
  v_i         int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select host_id, max_players, status
    into v_host, v_max, v_status
  from public.games where id = p_game;

  if v_host is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_host <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'not_host');
  end if;
  if v_status <> 'lobby' then
    return jsonb_build_object('ok', false, 'reason', 'not_in_lobby');
  end if;

  select coalesce(array_agg(lower(display_name)), array[]::text[])
    into v_taken
  from public.game_players
  where game_id = p_game;

  -- Deterministic per-game order so the same lobby always fills the same cast,
  -- but different games get different names.
  select array_agg(n order by md5(p_game::text || ':' || n))
    into v_shuffled
  from unnest(v_pool) as n;

  v_i := 1;
  for v_seat in 0 .. v_max - 1 loop
    if not exists (
      select 1 from public.game_players gp
      where gp.game_id = p_game and gp.seat = v_seat
    ) then
      v_name := null;
      while v_i <= coalesce(array_length(v_shuffled, 1), 0) loop
        if not (lower(v_shuffled[v_i]) = any (v_taken)) then
          v_name := v_shuffled[v_i];
          v_i := v_i + 1;
          exit;
        end if;
        v_i := v_i + 1;
      end loop;
      if v_name is null then
        v_name := 'Player' || (v_seat + 1)::text;
      end if;

      insert into public.game_players
        (game_id, profile_id, display_name, first_name, is_ai, seat, team, role)
      values
        (p_game, null, v_name, v_name, true, v_seat,
         public.mw_seat_team(v_seat), public.mw_seat_role(v_seat));
      v_taken := array_append(v_taken, lower(v_name));
      v_added := v_added + 1;
    end if;
  end loop;

  update public.games set updated_at = now() where id = p_game;
  return jsonb_build_object('ok', true, 'added', v_added);
end;
$$;
