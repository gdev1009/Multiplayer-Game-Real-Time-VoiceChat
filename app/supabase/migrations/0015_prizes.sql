-- ============================================================================
-- 0015_prizes.sql
-- ============================================================================
-- Match Word — Milestone 8: Prize Room & Trophy System
-- Run after 0014_friends.sql.
--
-- Catalog of trophies/prizes + per-player awards. Stats (games_played /
-- games_won) live on profiles. Awarding is server-authoritative via
-- mw_record_match_result.

-- =============================================================================
-- profiles: play stats
-- =============================================================================
alter table public.profiles
  add column if not exists games_played integer not null default 0,
  add column if not exists games_won    integer not null default 0;

comment on column public.profiles.games_played is
  'Matches finished by this player (Awarded by mw_record_match_result).';
comment on column public.profiles.games_won is
  'Matches this player finished on the winning team.';

-- =============================================================================
-- prize_catalog  (static list — trophies and novelty prizes)
-- =============================================================================
create table if not exists public.prize_catalog (
  id          text primary key,
  kind        text not null check (kind in ('trophy', 'prize')),
  title       text not null,
  description text not null default '',
  asset_path  text not null,
  sort_order  integer not null default 0
);

comment on table public.prize_catalog is
  'All trophies and novelty prizes. IDs are stable so client art can be swapped.';

alter table public.prize_catalog enable row level security;

drop policy if exists prize_catalog_select on public.prize_catalog;
create policy prize_catalog_select on public.prize_catalog
  for select to authenticated using (true);

insert into public.prize_catalog (id, kind, title, description, asset_path, sort_order)
values
  ('trophy-first-win', 'trophy', 'First Win',
   'Won your very first Match Word game.',
   'assets/images/trophies/trophy-first-win.png', 10),
  ('trophy-10-games', 'trophy', '10 Games',
   'Played 10 matches end to end.',
   'assets/images/trophies/trophy-10-games.png', 20),
  ('trophy-50-games', 'trophy', '50 Games',
   'Played 50 matches — a true studio regular.',
   'assets/images/trophies/trophy-50-games.png', 30),
  ('prize-sports-car', 'prize', 'Clay Sports Car',
   'A shiny novelty car for your shelf.',
   'assets/images/prizes/prize-sports-car.png', 110),
  ('prize-vacation', 'prize', 'Beach Getaway',
   'A sunny little vacation souvenir.',
   'assets/images/prizes/prize-vacation.png', 120),
  ('prize-tv', 'prize', 'Living-Room TV',
   'A cozy novelty TV for movie nights.',
   'assets/images/prizes/prize-tv.png', 130)
on conflict (id) do nothing;

-- =============================================================================
-- player_awards  (one row per player × catalog item)
-- =============================================================================
create table if not exists public.player_awards (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  prize_id   text not null references public.prize_catalog (id) on delete cascade,
  earned_at  timestamptz not null default now(),
  primary key (profile_id, prize_id)
);

comment on table public.player_awards is
  'Trophies and prizes a player has earned. Written only via mw_* functions.';

create index if not exists player_awards_profile_idx
  on public.player_awards (profile_id);

alter table public.player_awards enable row level security;

drop policy if exists player_awards_select_own on public.player_awards;
create policy player_awards_select_own on public.player_awards
  for select using (auth.uid() = profile_id);

-- =============================================================================
-- mw_my_prize_room  — catalog + which items the caller has earned
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
    )
  );
end;
$$;

revoke all on function public.mw_my_prize_room() from public;
grant execute on function public.mw_my_prize_room() to authenticated;

-- =============================================================================
-- mw_record_match_result  — bump stats + grant milestone trophies/prizes
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

  -- First win
  if p_won and won = 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-first-win')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-first-win'); end if;
  end if;

  -- Games-played trophies
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

  -- Novelty prizes unlock with early milestone wins (placeholder cadence).
  if p_won and won = 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'prize-sports-car')
    on conflict do nothing;
  end if;
  if played = 10 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'prize-vacation')
    on conflict do nothing;
  end if;
  if played = 50 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'prize-tv')
    on conflict do nothing;
  end if;

  return jsonb_build_object(
    'ok', true,
    'games_played', played,
    'games_won', won,
    'new_awards', to_jsonb(newly)
  );
end;
$$;

revoke all on function public.mw_record_match_result(boolean) from public;
grant execute on function public.mw_record_match_result(boolean) to authenticated;
