-- ============================================================================
-- 0014_friends.sql
-- ============================================================================
-- Match Word — Milestone 7: "Friend Connection"
-- Run this in the Supabase SQL editor after 0013_game_characters.sql.
--
-- What this adds
-- --------------
-- After a matched game a player can send another player a friend request; when
-- both sides accept (or one accepts a pending request) they become friends and
-- can invite each other to future games. No personal information is ever
-- exchanged — the friends list shows only a display name and the cosmetic
-- character layers, exactly like the live stage does (see mw_game_characters).
--
-- Design, consistent with the rest of the app:
--   * Server-authoritative: clients never write these tables directly. Every
--     mutation goes through a SECURITY DEFINER function that checks auth.uid().
--   * A friendship is stored ONCE per pair using a canonical (low, high) key so
--     there can never be two rows / a "mutual request" race for the same pair.
--   * RLS lets a member read only their own edges; writes are functions-only.

-- ============================================================================
-- friendships  (one row per unordered pair; low < high)
-- ============================================================================
create table if not exists public.friendships (
  user_low     uuid not null references public.profiles (id) on delete cascade,
  user_high    uuid not null references public.profiles (id) on delete cascade,
  requested_by uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending'
                 check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low < user_high)
);

comment on table public.friendships is
  'Friend edges between two players. One row per unordered pair (user_low < '
  'user_high); requested_by records who sent a still-pending request. Written '
  'only through mw_* SECURITY DEFINER functions.';

create index if not exists friendships_high_idx
  on public.friendships (user_high);

alter table public.friendships enable row level security;

-- A player may READ only the edges they are part of. All writes go through the
-- SECURITY DEFINER functions below (which bypass RLS), so there are no
-- insert/update/delete policies on purpose.
drop policy if exists friendships_select_own on public.friendships;
create policy friendships_select_own on public.friendships
  for select using (auth.uid() in (user_low, user_high));

-- ============================================================================
-- game_invites  (a friend invited to a specific lobby)
-- ============================================================================
create table if not exists public.game_invites (
  id         uuid primary key default gen_random_uuid(),
  game_id    uuid not null references public.games (id) on delete cascade,
  inviter    uuid not null references public.profiles (id) on delete cascade,
  invitee    uuid not null references public.profiles (id) on delete cascade,
  status     text not null default 'pending'
               check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  unique (game_id, invitee)
);

comment on table public.game_invites is
  'A pending invitation for a friend (invitee) to join a specific lobby. '
  'Written only through mw_* functions; the invitee sees it on their games hub.';

create index if not exists game_invites_invitee_idx
  on public.game_invites (invitee, status);

alter table public.game_invites enable row level security;

drop policy if exists game_invites_select_mine on public.game_invites;
create policy game_invites_select_mine on public.game_invites
  for select using (auth.uid() in (inviter, invitee));

-- ============================================================================
-- Helper: canonical ordering of a pair so we always hit the single row.
-- ============================================================================
create or replace function public.mw_pair_low(a uuid, b uuid)
returns uuid language sql immutable as $$ select least(a, b); $$;

create or replace function public.mw_pair_high(a uuid, b uuid)
returns uuid language sql immutable as $$ select greatest(a, b); $$;

-- ============================================================================
-- mw_send_friend_request(p_other) → { ok, status }
-- Creates a pending request. If the other player already has a pending request
-- out to me, we become friends immediately (the "mutual request" case).
-- ============================================================================
create or replace function public.mw_send_friend_request(p_other uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
  v_row  public.friendships;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if p_other is null or p_other = v_me then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
  end if;
  if not exists (select 1 from public.profiles where id = p_other) then
    return jsonb_build_object('ok', false, 'reason', 'no_such_player');
  end if;

  v_low  := public.mw_pair_low(v_me, p_other);
  v_high := public.mw_pair_high(v_me, p_other);

  select * into v_row from public.friendships
  where user_low = v_low and user_high = v_high;

  if v_row.user_low is null then
    insert into public.friendships (user_low, user_high, requested_by, status)
    values (v_low, v_high, v_me, 'pending');
    return jsonb_build_object('ok', true, 'status', 'pending');
  end if;

  if v_row.status = 'accepted' then
    return jsonb_build_object('ok', true, 'status', 'accepted', 'already', true);
  end if;

  -- A pending row exists. If the other side asked first, accept it (mutual).
  if v_row.requested_by = p_other then
    update public.friendships
    set status = 'accepted', updated_at = now()
    where user_low = v_low and user_high = v_high;
    return jsonb_build_object('ok', true, 'status', 'accepted');
  end if;

  -- Otherwise it's my own pending request already on file.
  return jsonb_build_object('ok', true, 'status', 'pending', 'already', true);
end;
$$;

grant execute on function public.mw_send_friend_request(uuid) to authenticated;

-- ============================================================================
-- mw_respond_friend_request(p_other, p_accept) → { ok }
-- Accept or decline a request the OTHER player sent me.
-- ============================================================================
create or replace function public.mw_respond_friend_request(
  p_other uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
  v_row  public.friendships;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if p_other is null or p_other = v_me then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
  end if;

  v_low  := public.mw_pair_low(v_me, p_other);
  v_high := public.mw_pair_high(v_me, p_other);

  select * into v_row from public.friendships
  where user_low = v_low and user_high = v_high;

  -- Must be a still-pending request the other player sent to me.
  if v_row.user_low is null
     or v_row.status <> 'pending'
     or v_row.requested_by <> p_other then
    return jsonb_build_object('ok', false, 'reason', 'no_request');
  end if;

  if p_accept then
    update public.friendships
    set status = 'accepted', updated_at = now()
    where user_low = v_low and user_high = v_high;
  else
    delete from public.friendships
    where user_low = v_low and user_high = v_high;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.mw_respond_friend_request(uuid, boolean)
  to authenticated;

-- ============================================================================
-- mw_remove_friend(p_other) → { ok }
-- Removes a friendship (or withdraws a request I sent) with the other player.
-- ============================================================================
create or replace function public.mw_remove_friend(p_other uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  v_low  := public.mw_pair_low(v_me, p_other);
  v_high := public.mw_pair_high(v_me, p_other);

  delete from public.friendships
  where user_low = v_low and user_high = v_high;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.mw_remove_friend(uuid) to authenticated;

-- ============================================================================
-- mw_list_friends() → jsonb[]  (accepted friends, with cosmetic character only)
-- ============================================================================
create or replace function public.mw_list_friends()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',           o.id,
        'display_name', o.first_name,
        'base',         c.base,
        'hair',         c.hair,
        'outfit',       c.outfit,
        'glasses',      c.glasses,
        'hat',          c.hat,
        'earrings',     c.earrings,
        'accessory',    c.accessory
      ) order by lower(o.first_name)
    ),
    '[]'::jsonb
  )
  from public.friendships f
  join public.profiles o
    on o.id = case when f.user_low = auth.uid() then f.user_high else f.user_low end
  left join public.characters c on c.profile_id = o.id
  where f.status = 'accepted'
    and auth.uid() in (f.user_low, f.user_high);
$$;

grant execute on function public.mw_list_friends() to authenticated;

-- ============================================================================
-- mw_list_friend_requests() → jsonb[]  (incoming pending requests)
-- ============================================================================
create or replace function public.mw_list_friend_requests()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',           o.id,
        'display_name', o.first_name,
        'base',         c.base,
        'hair',         c.hair,
        'outfit',       c.outfit,
        'glasses',      c.glasses,
        'hat',          c.hat,
        'earrings',     c.earrings,
        'accessory',    c.accessory
      ) order by f.created_at desc
    ),
    '[]'::jsonb
  )
  from public.friendships f
  join public.profiles o on o.id = f.requested_by
  left join public.characters c on c.profile_id = o.id
  where f.status = 'pending'
    and f.requested_by <> auth.uid()
    and auth.uid() in (f.user_low, f.user_high);
$$;

grant execute on function public.mw_list_friend_requests() to authenticated;

-- ============================================================================
-- mw_invite_friend(p_game, p_friend) → { ok }
-- The host/member of a lobby invites an accepted friend to it.
-- ============================================================================
create or replace function public.mw_invite_friend(p_game uuid, p_friend uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if not public.mw_is_game_member(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'not_a_member');
  end if;
  if not exists (
    select 1 from public.games
    where id = p_game and status = 'lobby' and expires_at > now()
  ) then
    return jsonb_build_object('ok', false, 'reason', 'game_closed');
  end if;

  -- Must actually be friends.
  v_low  := public.mw_pair_low(v_me, p_friend);
  v_high := public.mw_pair_high(v_me, p_friend);
  if not exists (
    select 1 from public.friendships
    where user_low = v_low and user_high = v_high and status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'not_friends');
  end if;

  insert into public.game_invites (game_id, inviter, invitee, status)
  values (p_game, v_me, p_friend, 'pending')
  on conflict (game_id, invitee)
  do update set inviter = excluded.inviter,
                status = 'pending',
                created_at = now();

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.mw_invite_friend(uuid, uuid) to authenticated;

-- ============================================================================
-- mw_list_my_invites() → jsonb[]  (pending invites to still-open lobbies)
-- ============================================================================
create or replace function public.mw_list_my_invites()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'game_id',      g.id,
        'code',         g.code,
        'inviter_name', p.first_name,
        'created_at',   i.created_at
      ) order by i.created_at desc
    ),
    '[]'::jsonb
  )
  from public.game_invites i
  join public.games g on g.id = i.game_id
  join public.profiles p on p.id = i.inviter
  where i.invitee = auth.uid()
    and i.status = 'pending'
    and g.status = 'lobby'
    and g.expires_at > now();
$$;

grant execute on function public.mw_list_my_invites() to authenticated;

-- ============================================================================
-- mw_respond_invite(p_game, p_accept) → { ok, game_id, seat }
-- Accepting seats me into the lobby (reusing mw_seat_or_bump); declining marks
-- the invite so it drops off my list.
-- ============================================================================
create or replace function public.mw_respond_invite(p_game uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_seat int;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;
  if not exists (
    select 1 from public.game_invites
    where game_id = p_game and invitee = v_me and status = 'pending'
  ) then
    return jsonb_build_object('ok', false, 'reason', 'no_invite');
  end if;

  if not p_accept then
    update public.game_invites set status = 'declined'
    where game_id = p_game and invitee = v_me;
    return jsonb_build_object('ok', true, 'declined', true);
  end if;

  if not exists (
    select 1 from public.games
    where id = p_game and status = 'lobby' and expires_at > now()
  ) then
    return jsonb_build_object('ok', false, 'reason', 'game_closed');
  end if;

  v_seat := public.mw_seat_or_bump(p_game);
  if v_seat < 0 then
    return jsonb_build_object('ok', false, 'reason', 'game_full');
  end if;

  update public.game_invites set status = 'accepted'
  where game_id = p_game and invitee = v_me;

  return jsonb_build_object('ok', true, 'game_id', p_game, 'seat', v_seat);
end;
$$;

grant execute on function public.mw_respond_invite(uuid, boolean) to authenticated;

-- ============================================================================
-- Realtime: let a signed-in player see new incoming invites live on their hub.
-- (Safe to run repeatedly — skip if already in the publication.)
-- ============================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'game_invites'
  ) then
    alter publication supabase_realtime add table public.game_invites;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'friendships'
  ) then
    alter publication supabase_realtime add table public.friendships;
  end if;
end;
$$;
