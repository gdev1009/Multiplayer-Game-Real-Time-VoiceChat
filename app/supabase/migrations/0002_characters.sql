-- Match Word — Milestone 3 schema
-- Character Creation System: store each player's assembled character.
-- Run this in the Supabase SQL editor after 0001_init.sql.

-- =============================================================================
-- characters  (one paper-doll character per profile)
-- =============================================================================
create table if not exists public.characters (
  profile_id    uuid primary key references public.profiles (id) on delete cascade,
  display_name  text not null,
  base          text,   -- layer option ids (null/None handled gracefully)
  base_color    text,   -- skin-tone tint applied to the chosen body
  hair          text,
  hair_color    text,   -- tint id applied to the neutral hair PNG
  eyes          text,
  eye_color     text,   -- tint id applied to the neutral eyes PNG
  glasses       text,
  outfit        text,
  updated_at    timestamptz not null default now()
);

-- Backfill for projects created before the colour columns existed.
alter table public.characters add column if not exists base_color text;
alter table public.characters add column if not exists hair_color text;
alter table public.characters add column if not exists eye_color  text;

comment on table public.characters is
  'A player''s assembled paper-doll character. Layer columns store option ids; '
  'null means the player chose None for that layer.';

-- =============================================================================
-- Row Level Security — a user may only see and change their own character.
-- =============================================================================
alter table public.characters enable row level security;

drop policy if exists "characters_select_own" on public.characters;
create policy "characters_select_own"
  on public.characters for select
  using (auth.uid() = profile_id);

drop policy if exists "characters_insert_own" on public.characters;
create policy "characters_insert_own"
  on public.characters for insert
  with check (auth.uid() = profile_id);

drop policy if exists "characters_update_own" on public.characters;
create policy "characters_update_own"
  on public.characters for update
  using (auth.uid() = profile_id)
  with check (auth.uid() = profile_id);
