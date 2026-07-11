-- Match Word — Milestone 4 enhancement
-- "See who's already in the game before you join."
-- Run this in the Supabase SQL editor after 0007_gameplay.sql.
--
-- Why this is needed
-- ------------------
-- Joining by code used to seat the player immediately, so they only saw the
-- roster *after* landing in the room. Players want to confirm they're joining
-- the right game — and land on the same team as their friend — *before*
-- committing. This read-only function returns the current roster for a code
-- without seating anyone, so the client can show a preview + "Join" confirm.
--
-- It is SECURITY DEFINER (bypasses RLS) so a not-yet-member can read the seats
-- of a private game they hold the code for. It only ever reveals a game that is
-- still an open lobby, and returns just the display names, teams, and seats —
-- no profile ids or other personal data.

create or replace function public.mw_peek_game(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_game    public.games%rowtype;
  v_players jsonb;
  v_taken   int;
  v_mine    boolean;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select * into v_game
  from public.games
  where code = p_code and status = 'lobby' and expires_at > now()
  order by created_at desc
  limit 1;

  if v_game.id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  -- The seats, in play order, with only the safe-to-show fields.
  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'seat', gp.seat,
        'team', gp.team,
        'role', gp.role,
        'display_name', gp.display_name,
        'is_host', gp.is_host,
        'is_ai', gp.is_ai
      ) order by gp.seat
    ), '[]'::jsonb),
    count(*),
    bool_or(gp.profile_id = v_uid)
  into v_players, v_taken, v_mine
  from public.game_players gp
  where gp.game_id = v_game.id;

  return jsonb_build_object(
    'ok', true,
    'game_id', v_game.id,
    'code', v_game.code,
    'max_players', v_game.max_players,
    'seats_taken', v_taken,
    'already_member', coalesce(v_mine, false),
    'players', v_players
  );
end;
$$;

comment on function public.mw_peek_game(text) is
  'Read-only roster preview for a 4-digit code: returns the open lobby''s seats '
  '(names, teams, roles) without seating the caller, so the client can show a '
  '"who''s already here" confirm step before joining.';

grant execute on function public.mw_peek_game(text) to authenticated;
