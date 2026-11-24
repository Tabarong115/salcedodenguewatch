-- Public health alert reporter details and follow-up workflow for an existing database.
-- Run after 20260929130000_activity_map_sync.sql in the Supabase SQL Editor.

begin;

alter table public.health_alerts
  add column if not exists reporter_name text,
  add column if not exists reporter_address text,
  add column if not exists reporter_age smallint,
  add column if not exists reporter_sex text;

alter table public.health_alerts alter column preferred_contact drop not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'health_alerts_reporter_age_check') then
    alter table public.health_alerts add constraint health_alerts_reporter_age_check
      check (reporter_age is null or reporter_age between 1 and 120);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'health_alerts_reporter_sex_check') then
    alter table public.health_alerts add constraint health_alerts_reporter_sex_check
      check (reporter_sex is null or reporter_sex in ('female', 'male', 'other', 'prefer_not_to_say'));
  end if;
end;
$$;

-- The barangay worker records a field confirmation after verifying the report.
alter table public.health_alerts drop constraint if exists health_alerts_followup_status_check;
alter table public.health_alerts add constraint health_alerts_followup_status_check
  check (followup_status in ('new', 'acknowledged', 'contacted', 'confirmed', 'referred', 'closed'));

create or replace function public.require_bhw_alert_confirmation()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.followup_status = 'confirmed'
     and coalesce(public.current_user_role(), '') not in ('bhw', 'bsi') then
    raise exception 'A BHW/BSI with access to this barangay must confirm the health alert';
  end if;
  return new;
end;
$$;

drop trigger if exists health_alerts_bhw_confirmation_only on public.health_alerts;
create trigger health_alerts_bhw_confirmation_only
before update of followup_status on public.health_alerts
for each row execute function public.require_bhw_alert_confirmation();

-- Reporter identity is visible only through existing authenticated staff RLS.
grant insert (reporter_name, reporter_address, reporter_age, reporter_sex)
  on public.health_alerts to anon, authenticated;
grant update (reporter_name, reporter_address, reporter_age, reporter_sex)
  on public.health_alerts to authenticated;

-- Populate the public RHU contact setting from the configured RHU profile.
-- When no phone has been entered, publish a useful instruction instead of a fake number.
update public.settings s
set value = coalesce(
  (select nullif(trim(r.contact_number), '')
   from public.rhu r
   where nullif(trim(r.contact_number), '') is not null
   order by r.created_at
   limit 1),
  'RHU contact number not configured'
),
updated_at = now()
where s.key = 'rhu_contact_phone'
  and (upper(s.value) = 'PLACEHOLDER_PHONE' or trim(s.value) = '');

update public.settings
set value = 'Contact the RHU for current operating hours', updated_at = now()
where key = 'rhu_contact_hours' and upper(value) = 'PLACEHOLDER_HOURS';

insert into public.settings (key, value, is_public)
select 'rhu_contact_phone', coalesce(
  (select nullif(trim(r.contact_number), '')
   from public.rhu r
   where nullif(trim(r.contact_number), '') is not null
   order by r.created_at
   limit 1),
  'RHU contact number not configured'
), true
where not exists (select 1 from public.settings where key = 'rhu_contact_phone');

create or replace function public.sync_rhu_contact_setting()
returns trigger language plpgsql security definer set search_path = '' as $$
declare selected_phone text;
begin
  select nullif(trim(r.contact_number), '') into selected_phone
  from public.rhu r
  where nullif(trim(r.contact_number), '') is not null
  order by r.created_at
  limit 1;

  insert into public.settings (key, value, is_public)
  values ('rhu_contact_phone', coalesce(selected_phone, 'RHU contact number not configured'), true)
  on conflict (key) do update
    set value = excluded.value, is_public = true, updated_at = now();
  return new;
end;
$$;

drop trigger if exists rhu_contact_phone_sync on public.rhu;
create trigger rhu_contact_phone_sync
after insert or update of contact_number on public.rhu
for each row execute function public.sync_rhu_contact_setting();

-- Postgres Changes drives the in-app staff alert banner/list refresh while staff are online.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'health_alerts'
     ) then
    alter publication supabase_realtime add table public.health_alerts;
  end if;
end;
$$;

commit;
