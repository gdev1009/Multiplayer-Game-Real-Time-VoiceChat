-- Match Word — Milestone 4 hotfix
-- Fix: infinite recursion in the game_players / games SELECT policies.
-- Run this in the Supabase SQL editor after 0005_lobby_counts.sql.
--
-- Why this is needed
-- ------------------
-- The original `game_players_select_visible` policy (0004) queried
-- public.game_players from *inside* its own SELECT USING clause. Postgres
-- re-applies the same policy to that inner query, which recurses forever and
-- raises `42P17: infinite recursion detected in policy for relation
-- "game_players"`. The `games_select_visible` policy inherited the same failure
-- through its game_players sub-query.
--
-- Effect in the app: mw_create_game / mw_join_game / mw_quick_match all succeed
-- (they are SECURITY DEFINER and bypass RLS), so the room is created on the
-- server, but the very next client read — loadPlayers() / watchPlayers(), a
-- plain select on game_players — hits the recursive policy and throws, so the
-- lobby surfaces "Something went wrong. Please try again." even though the game
-- exists. The open-games list keeps working because it goes through the
-- SECURITY DEFINER mw_list_open_games() function instead of a direct select.
--
-- The fix: check membership through a SECURITY DEFINER helper. Because the
-- helper runs as its owner, RLS is not applied inside it, so the self-reference
-- no longer recurses.

-- =============================================================================
-- Helper: is the current user seated in this game? (RLS-safe membership check)
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

comment on function public.mw_is_game_member(uuid) is
  'RLS-safe membership check used by the games/game_players SELECT policies to '
  'avoid infinite recursion (runs SECURITY DEFINER so RLS is not re-applied).';

grant execute on function public.mw_is_game_member(uuid) to authenticated;

-- =============================================================================
-- Re-create the SELECT policies without any self-referential sub-query.
-- =============================================================================

-- games: members can read their game; anyone signed in can read open public
-- lobbies.
drop policy if exists "games_select_visible" on public.games;
create policy "games_select_visible"
  on public.games for select
  using (
    (is_public and status = 'lobby')
    or public.mw_is_game_member(id)
  );

-- game_players: members can read every seat in a game they belong to; anyone
-- signed in can read the seats of open public lobbies.
drop policy if exists "game_players_select_visible" on public.game_players;
create policy "game_players_select_visible"
  on public.game_players for select
  using (
    public.mw_is_game_member(game_id)
    or exists (
      select 1
      from public.games g
      where g.id = game_players.game_id
        and g.is_public
        and g.status = 'lobby'
    )
  );
