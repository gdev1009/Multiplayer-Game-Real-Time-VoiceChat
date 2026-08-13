-- Paid membership product id: $6.99 CAD / month (Ronna Aug 2026).
alter table public.subscriptions
  alter column product_id set default 'matchword_monthly_699';

comment on column public.subscriptions.product_id is
  'Store product. Current paid plan: matchword_monthly_699 ($6.99 CAD/mo).';

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
      'product_id', 'matchword_monthly_699',
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

create or replace function public.mw_sync_subscription(
  p_status text,
  p_store text default null,
  p_period_end timestamptz default null,
  p_original_tx_id text default null,
  p_product_id text default 'matchword_monthly_699'
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
    uid, coalesce(p_product_id, 'matchword_monthly_699'), p_status, p_store,
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
