-- Match Word — Milestone 4 follow-up
-- "Check Upcoming Games" list with player counts.
-- Run this in the Supabase SQL editor after 0004_lobby.sql.
--
-- Why this exists
-- ---------------
-- The spec's definition of done for the lobby hub calls for an upcoming-games
-- list *with player counts* so a senior can see, at a glance, how full each
-- open game is ("2 / 4 players") before joining. Rather than have the client
-- issue one count query per row (N+1) or read the seats table directly, this
-- single SECURITY DEFINER function returns each joinable public lobby together
-- with its live occupancy. Full games are excluded because they cannot be
-- joined anyway.

create or replace function public.mw_list_open_games()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(t) order by t.created_at desc),
    '[]'::jsonb
  )
  from (
    select
      g.id,
      g.code,
      g.host_id,
      g.status,
      g.is_public,
      g.max_players,
      g.created_at,
      g.started_at,
      g.expires_at,
      (
        select count(*)::int
        from public.game_players gp
        where gp.game_id = g.id
      ) as player_count
    from public.games g
    where g.is_public
      and g.status = 'lobby'
      and g.expires_at > now()
      and (
        select count(*)
        from public.game_players gp
        where gp.game_id = g.id
      ) < g.max_players
    order by g.created_at desc
    limit 20
  ) t;
$$;

comment on function public.mw_list_open_games() is
  'Joinable public lobbies (not full, not expired) with live player_count, '
  'for the "Check Upcoming Games" list.';

grant execute on function public.mw_list_open_games() to authenticated;
