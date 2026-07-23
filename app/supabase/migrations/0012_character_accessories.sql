-- Match Word — Milestone 3 (rebuild) schema
-- Character Creation now uses the artist's real art with new accessory layers:
--   hat        — headwear (cap / knit / brim / sun hat)
--   earrings   — jewellery
--   accessory  — a held item (bag / walking cane / walker)
-- Run this in the Supabase SQL editor after 0002_characters.sql.
--
-- The older colour/eyes columns (base_color, hair_color, eyes, eye_color) are
-- left in place for backward compatibility; the rebuilt builder no longer
-- writes to them (the real art is full-colour, so there is nothing to tint).

alter table public.characters add column if not exists hat        text;
alter table public.characters add column if not exists earrings   text;
alter table public.characters add column if not exists accessory  text;

comment on column public.characters.hat is
  'Headwear option id (cap / knit / brim / sun hat), or null for none.';
comment on column public.characters.earrings is
  'Earrings option id, or null for none.';
comment on column public.characters.accessory is
  'Held-item option id (bag / cane / walker), or null for none.';
