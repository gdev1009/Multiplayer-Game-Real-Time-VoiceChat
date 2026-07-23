-- ============================================================================
-- 0016_subscriptions.sql
-- ============================================================================
-- Match Word — Milestone 9: Subscription entitlement mirror
-- Run after 0015_prizes.sql.
--
-- Store receipts sync into `subscriptions`. Access gating is decided in the
-- app (trial window + paid entitlement). Real StoreKit / Play Billing products
-- are configured in App Store Connect / Play Console; product id:
--   matchword_monthly_599

create table if not exists public.subscriptions (
  profile_id          uuid primary key references public.profiles (id) on delete cascade,
  product_id          text not null default 'matchword_monthly_599',
  status              text not null default 'none'
                        check (status in ('none', 'trialing', 'active', 'expired', 'grace')),
  store               text check (store is null or store in ('app_store', 'play_store', 'manual')),
  current_period_end  timestamptz,
  original_tx_id      text,
  updated_at          timestamptz not null default now()
);

comment on table public.subscriptions is
  'Server-side entitlement mirror for the monthly Match Word subscription. '
  'Written via mw_sync_subscription after a store purchase / restore.';

alter table public.subscriptions enable row level security;

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions
  for select using (auth.uid() = profile_id);

-- =============================================================================
-- mw_my_subscription
-- =============================================================================
create or replace function public.mw_my_subscription()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r public.subscriptions%rowtype;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select * into r from public.subscriptions where profile_id = uid;
  if not found then
    return jsonb_build_object(
      'ok', true,
      'status', 'none',
      'product_id', 'matchword_monthly_599',
      'current_period_end', null
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', r.status,
    'product_id', r.product_id,
    'store', r.store,
    'current_period_end', r.current_period_end,
    'original_tx_id', r.original_tx_id
  );
end;
$$;

revoke all on function public.mw_my_subscription() from public;
grant execute on function public.mw_my_subscription() to authenticated;

-- =============================================================================
-- mw_sync_subscription — upsert entitlement after purchase / restore / expire
-- =============================================================================
create or replace function public.mw_sync_subscription(
  p_status text,
  p_store text default null,
  p_period_end timestamptz default null,
  p_original_tx_id text default null,
  p_product_id text default 'matchword_monthly_599'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  if p_status not in ('none', 'trialing', 'active', 'expired', 'grace') then
    return jsonb_build_object('ok', false, 'reason', 'bad_status');
  end if;

  insert into public.subscriptions as s (
    profile_id, product_id, status, store, current_period_end, original_tx_id, updated_at
  ) values (
    uid, coalesce(p_product_id, 'matchword_monthly_599'), p_status, p_store,
    p_period_end, p_original_tx_id, now()
  )
  on conflict (profile_id) do update set
    product_id = excluded.product_id,
    status = excluded.status,
    store = excluded.store,
    current_period_end = excluded.current_period_end,
    original_tx_id = coalesce(excluded.original_tx_id, s.original_tx_id),
    updated_at = now();

  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

revoke all on function public.mw_sync_subscription(text, text, timestamptz, text, text) from public;
grant execute on function public.mw_sync_subscription(text, text, timestamptz, text, text) to authenticated;
