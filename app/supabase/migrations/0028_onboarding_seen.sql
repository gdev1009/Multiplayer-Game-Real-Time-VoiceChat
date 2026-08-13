-- First-launch walkthrough flag (Ronna Aug 2026).
alter table public.profiles
  add column if not exists onboarding_seen boolean not null default false;

comment on column public.profiles.onboarding_seen is
  'True after the player finishes or skips the first-launch walkthrough.';
