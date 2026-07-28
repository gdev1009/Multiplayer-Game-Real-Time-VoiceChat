-- ============================================================================
-- 0022_phase1_win_trophies.sql
-- ============================================================================
-- Phase 1 (Ronna Jul 2026): clay trophy for each game win; novelty "store"
-- prizes deferred. Win count stays on profiles.games_won — the client shows
-- one clay cup per win on sign-in and in the Prize Room.

-- Catalog: reusable clay win cup (art can be swapped later).
insert into public.prize_catalog (id, kind, title, description, asset_path, sort_order)
values
  ('trophy-win-cup', 'trophy', 'Win Trophy',
   'A clay trophy for every Match Word win.',
   'assets/images/trophies/trophy-first-win.png', 5)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  asset_path = excluded.asset_path,
  sort_order = excluded.sort_order;

-- Mark novelty prizes as Phase 2 (kept in catalog; hidden from phase-1 room).
comment on table public.prize_catalog is
  'Trophies and novelty prizes. Phase 1 surfaces trophies only; kind=prize is Phase 2.';

-- =============================================================================
-- mw_my_prize_room  — trophies only in Phase 1 (+ games_won for win cups)
-- =============================================================================
create or replace function public.mw_my_prize_room()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  played int;
  won int;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select games_played, games_won into played, won
  from public.profiles where id = uid;

  return jsonb_build_object(
    'ok', true,
    'games_played', coalesce(played, 0),
    'games_won', coalesce(won, 0),
    'items', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'kind', c.kind,
          'title', c.title,
          'description', c.description,
          'asset_path', c.asset_path,
          'sort_order', c.sort_order,
          'earned', (a.prize_id is not null),
          'earned_at', a.earned_at
        ) order by c.sort_order
      ), '[]'::jsonb)
      from public.prize_catalog c
      left join public.player_awards a
        on a.prize_id = c.id and a.profile_id = uid
      where c.kind = 'trophy'
    )
  );
end;
$$;

-- =============================================================================
-- mw_record_match_result  — stats + trophies; no novelty prizes in Phase 1
-- =============================================================================
create or replace function public.mw_record_match_result(p_won boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  played int;
  won int;
  newly text[] := '{}';
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  update public.profiles
  set games_played = games_played + 1,
      games_won    = games_won + case when p_won then 1 else 0 end
  where id = uid
  returning games_played, games_won into played, won;

  -- Clay win cup unlocked on first win (count = games_won on the client).
  if p_won and won >= 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-win-cup')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-win-cup'); end if;
  end if;

  -- First-win milestone plaque
  if p_won and won = 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-first-win')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-first-win'); end if;
  end if;

  -- Games-played milestone trophies
  if played = 10 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-10-games')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-10-games'); end if;
  elsif played = 50 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-50-games')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-50-games'); end if;
  end if;

  -- Novelty prizes (sports car / vacation / TV) deferred to Phase 2.

  return jsonb_build_object(
    'ok', true,
    'games_played', played,
    'games_won', won,
    'new_awards', to_jsonb(newly)
  );
end;
$$;
