-- IP layer for silent free-trial abuse prevention (one trial per device or IP).
create unique index if not exists device_trials_ip_address_uidx
  on public.device_trials (ip_address)
  where ip_address is not null;

comment on table public.device_trials is
  'One free trial per device_id and per ip_address. Written by claim-trial Edge Function.';
