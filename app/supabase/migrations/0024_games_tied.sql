-- =============================================================================
-- 0024_games_tied.sql
-- =============================================================================
-- Prize Room shows wins | ties | losses. Track ties on profiles and accept a
-- win/tie/loss outcome from the client (ties were previously counted as losses).

alter table public.profiles
  add column if not exists games_tied int not null default 0;

comment on column public.profiles.games_tied is
  'Matches that ended in a tie for this player (mw_record_match_result).';

-- Drop Phase-1 boolean overload so clients use the outcome form.
drop function if exists public.mw_record_match_result(boolean);

-- =============================================================================
-- mw_my_prize_room  — include games_tied
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
  tied int;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select games_played, games_won, games_tied into played, won, tied
  from public.profiles where id = uid;

  return jsonb_build_object(
    'ok', true,
    'games_played', coalesce(played, 0),
    'games_won', coalesce(won, 0),
    'games_tied', coalesce(tied, 0),
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
-- mw_record_match_result(p_outcome)  — 'win' | 'tie' | 'loss'
-- =============================================================================
create or replace function public.mw_record_match_result(p_outcome text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  played int;
  won int;
  tied int;
  newly text[] := '{}';
  outcome text := lower(coalesce(p_outcome, 'loss'));
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  if outcome not in ('win', 'tie', 'loss') then
    outcome := 'loss';
  end if;

  update public.profiles
  set games_played = games_played + 1,
      games_won    = games_won + case when outcome = 'win' then 1 else 0 end,
      games_tied   = games_tied + case when outcome = 'tie' then 1 else 0 end
  where id = uid
  returning games_played, games_won, games_tied into played, won, tied;

  if outcome = 'win' and won >= 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-win-cup')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-win-cup'); end if;
  end if;

  if outcome = 'win' and won = 1 then
    insert into public.player_awards (profile_id, prize_id)
    values (uid, 'trophy-first-win')
    on conflict do nothing;
    if found then newly := array_append(newly, 'trophy-first-win'); end if;
  end if;

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

  return jsonb_build_object(
    'ok', true,
    'games_played', played,
    'games_won', won,
    'games_tied', tied,
    'new_awards', to_jsonb(newly)
  );
end;
$$;

revoke all on function public.mw_record_match_result(text) from public;
grant execute on function public.mw_record_match_result(text) to authenticated;
