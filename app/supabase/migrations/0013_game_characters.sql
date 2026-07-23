-- ============================================================================
-- 0013_game_characters.sql
-- ============================================================================
-- Match Word — Milestone 5/6 fix
-- "Show each player's saved character on the game-show stage."
-- Run this in the Supabase SQL editor after 0012_character_accessories.sql.
--
-- Why this is needed
-- ------------------
-- The `characters` table has strict RLS: a player may only read their OWN row
-- (`auth.uid() = profile_id`). That is correct for privacy, but it means the
-- live game screen could not read the OTHER seated players' characters, so the
-- studio podiums fell back to a generic clay bust for everyone. This function
-- lets any player who is a member of a game read the (non-sensitive, cosmetic)
-- character of everyone seated in THAT game — and nothing else.
--
-- It returns only the cosmetic layer ids + display name/role/seat, never any
-- private data. Computer-filled seats (profile_id null) simply have no row here;
-- the client generates a friendly look for them locally.

create or replace function public.mw_game_characters(p_game uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'role',         gp.role,
        'seat',         gp.seat,
        'display_name', gp.display_name,
        'base',         c.base,
        'hair',         c.hair,
        'outfit',       c.outfit,
        'glasses',      c.glasses,
        'hat',          c.hat,
        'earrings',     c.earrings,
        'accessory',    c.accessory
      ) order by gp.seat
    ),
    '[]'::jsonb
  )
  from public.game_players gp
  join public.characters c on c.profile_id = gp.profile_id
  where gp.game_id = p_game
    and gp.profile_id is not null
    -- Only members of the game may read its roster of characters.
    and public.mw_is_game_member(p_game);
$$;

comment on function public.mw_game_characters(uuid) is
  'Cosmetic character layers (base/hair/outfit/glasses/hat/earrings/accessory) '
  'for every seated human in a game the caller belongs to, so the live stage '
  'can render each player''s saved character. Members-only; returns no private '
  'data. Computer seats have no row (the client draws them locally).';

grant execute on function public.mw_game_characters(uuid) to authenticated;
