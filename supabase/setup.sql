-- Salcedo Dengue Watch: clean initial setup for a NEW Supabase project.
-- Run once in an empty project's SQL Editor. This does not import the old schema or data.

create extension if not exists pgcrypto;

create table public.roles (
  id text primary key,
  display_name text not null,
  requires_rhu boolean not null default false,
  requires_facility boolean not null default false,
  requires_barangay boolean not null default false,
  is_admin boolean not null default false,
  is_assignable boolean not null default true
);

insert into public.roles (id, display_name, requires_rhu, requires_facility, requires_barangay, is_admin, is_assignable) values
  ('pending', 'Pending setup', false, false, false, false, false),
  ('admin', 'Administrator', false, false, false, true, true),
  ('rhu_staff', 'RHU Staff', true, false, false, false, true),
  ('hospital_staff', 'Hospital/Clinic Staff', true, true, false, false, true),
  ('encoder', 'Encoder', true, false, true, false, true),
  ('bhw', 'Barangay Health Worker', true, false, true, false, true),
  ('bsi', 'Barangay Surveillance Information Officer', true, false, true, false, true);

create table public.rhu (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  region text not null default 'Eastern Samar',
  contact_person text,
  contact_number text,
  email text,
  address text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.barangays (
  id uuid primary key default gen_random_uuid(),
  rhu_id uuid not null references public.rhu(id) on delete restrict,
  name text not null,
  region text not null default 'Eastern Samar',
  population integer check (population is null or population >= 0),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (rhu_id, name),
  unique (id, rhu_id)
);

create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  rhu_id uuid not null references public.rhu(id) on delete restrict,
  name text not null,
  facility_type text not null check (facility_type in ('hospital', 'clinic', 'health_center', 'other')),
  contact_person text,
  contact_number text,
  email text,
  address text,
  barangay text,
  barangay_id uuid,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (rhu_id, name),
  unique (id, rhu_id),
  foreign key (barangay_id) references public.barangays(id) on delete set null
);

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null,
  role text not null default 'pending' references public.roles(id),
  rhu_id uuid references public.rhu(id) on delete restrict,
  facility_id uuid references public.facilities(id) on delete restrict,
  barangay_id uuid references public.barangays(id) on delete restrict,
  covered_barangay text[],
  team text[],
  active boolean not null default false,
  password_setup_required boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_facility_matches_rhu foreign key (facility_id, rhu_id)
    references public.facilities(id, rhu_id) on delete restrict,
  constraint users_barangay_matches_rhu foreign key (barangay_id, rhu_id)
    references public.barangays(id, rhu_id) on delete restrict
);

comment on column public.users.role is
  'Foreign key to public.roles.id; the Supabase Table Editor can select from the role lookup rows.';
comment on column public.users.rhu_id is
  'Required for roles marked requires_rhu in public.roles.';
comment on column public.users.facility_id is
  'Required for roles marked requires_facility in public.roles.';
comment on column public.users.barangay_id is
  'Required for roles marked requires_barangay in public.roles.';

create table public.cases (
  id uuid primary key default gen_random_uuid(),
  classification text not null check (classification in ('suspected', 'probable', 'confirmed')),
  report_date timestamptz,
  symptom_onset_date timestamptz,
  status text not null default 'pending' check (status in ('pending', 'investigation', 'closed')),
  age_band text check (age_band is null or age_band in ('0-4', '5-9', '10-14', '15-19', '20-29', '30-39', '40-49', '50-59', '60+')),
  sex text check (sex is null or sex in ('male', 'female', 'other', 'unknown')),
  barangay text not null,
  barangay_id uuid references public.barangays(id) on delete restrict,
  purok text,
  latitude double precision,
  longitude double precision,
  location_accuracy double precision,
  public_grid_lat double precision,
  public_grid_lng double precision,
  lab_test_type text,
  lab_result text check (lab_result is null or lab_result in ('pending', 'positive', 'negative', 'inconclusive')),
  lab_test_date timestamptz,
  outcome text check (outcome is null or outcome in ('recovered', 'death', 'unknown', 'ongoing')),
  outcome_date timestamptz,
  assigned_worker_id uuid references public.users(id) on delete set null,
  created_by uuid not null references public.users(id) on delete restrict,
  is_submitted boolean not null default false,
  is_duplicate_of uuid references public.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep a coarsened location for the public map; never publish the case's
-- precise latitude/longitude through a public view.
create or replace function public.set_case_public_grid()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.latitude is not null and new.longitude is not null then
    new.public_grid_lat := round(new.latitude::numeric, 3)::double precision;
    new.public_grid_lng := round(new.longitude::numeric, 3)::double precision;
  else
    new.public_grid_lat := null;
    new.public_grid_lng := null;
  end if;
  return new;
end;
$$;
create trigger cases_set_public_grid
before insert or update of latitude, longitude on public.cases
for each row execute function public.set_case_public_grid();

create table public.restricted_identity (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null unique references public.cases(id) on delete cascade,
  full_name text not null,
  phone text,
  address text,
  guardian_contact text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.health_alerts (
  id uuid primary key default gen_random_uuid(),
  barangay text not null,
  barangay_id uuid references public.barangays(id) on delete restrict,
  reporter_name text,
  reporter_address text,
  reporter_age smallint check (reporter_age between 1 and 120),
  reporter_sex text check (reporter_sex in ('female', 'male', 'other', 'prefer_not_to_say')),
  preferred_contact text check (preferred_contact in ('phone', 'text', 'visit')),
  contact_value text,
  symptoms text[] not null default '{}',
  onset_date timestamptz not null,
  note text,
  submitted_at timestamptz not null default now(),
  urgency_flag boolean not null default false,
  assigned_worker_id uuid references public.users(id) on delete set null,
  followup_status text not null default 'new' check (followup_status in ('new', 'acknowledged', 'contacted', 'confirmed', 'referred', 'closed')),
  follow_up_notes text,
  follow_up_updated_at timestamptz,
  reference_number text not null unique
);

create table public.response_activities (
  id uuid primary key default gen_random_uuid(),
  activity_type text not null,
  activity_date timestamptz not null default now(),
  barangay text not null,
  barangay_id uuid references public.barangays(id) on delete restrict,
  purok text,
  team text[] not null default '{}',
  households_covered integer check (households_covered is null or households_covered >= 0),
  area_covered_sqm double precision check (area_covered_sqm is null or area_covered_sqm >= 0),
  findings text,
  notes text,
  status text not null default 'completed',
  linked_case_id uuid references public.cases(id) on delete set null,
  created_by uuid not null references public.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.settings (
  key text primary key,
  value text not null,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  action text not null,
  record_type text not null,
  record_id uuid,
  created_at timestamptz not null default now()
);

insert into public.settings (key, value, is_public) values
  ('rhu_contact_name', 'Salcedo Rural Health Unit', true),
  ('rhu_contact_phone', 'RHU contact number not configured', true),
  ('rhu_contact_hours', 'Contact the RHU for current operating hours', true),
  ('emergency_text', 'For severe symptoms, go immediately to the nearest hospital or call emergency services.', true),
  ('public_map_grid_size', '500', false),
  ('aggregation_threshold', '3', false),
  ('data_retention_days', '2555', false),
  ('outbreak_threshold_weekly', '10', false),
  ('outbreak_threshold_barangay', '3', false)
on conflict (key) do nothing;

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

create trigger rhu_contact_phone_sync
after insert or update of contact_number on public.rhu
for each row execute function public.sync_rhu_contact_setting();

create index cases_barangay_date_idx on public.cases (barangay_id, report_date desc);
create index cases_assigned_worker_idx on public.cases (assigned_worker_id);
create index health_alerts_barangay_status_idx on public.health_alerts (barangay_id, followup_status);
create index response_activities_barangay_date_idx on public.response_activities (barangay_id, activity_date desc);
create index users_scope_idx on public.users (role, rhu_id, facility_id, barangay_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger rhu_set_updated_at before update on public.rhu
for each row execute function public.set_updated_at();
create trigger barangays_set_updated_at before update on public.barangays
for each row execute function public.set_updated_at();
create trigger facilities_set_updated_at before update on public.facilities
for each row execute function public.set_updated_at();
create trigger users_set_updated_at before update on public.users
for each row execute function public.set_updated_at();
create trigger cases_set_updated_at before update on public.cases
for each row execute function public.set_updated_at();
create trigger identity_set_updated_at before update on public.restricted_identity
for each row execute function public.set_updated_at();

create or replace function public.log_audit_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare changed_id uuid;
begin
  if tg_op = 'DELETE' then
    changed_id := old.id;
  else
    changed_id := new.id;
  end if;
  insert into public.audit_log (user_id, action, record_type, record_id)
  values (
    (select u.id from public.users u where u.id = (select auth.uid())),
    lower(tg_op),
    tg_table_name,
    changed_id
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger audit_cases after insert or update or delete on public.cases
for each row execute function public.log_audit_event();
create trigger audit_health_alerts after insert or update or delete on public.health_alerts
for each row execute function public.log_audit_event();
create trigger audit_response_activities after insert or update or delete on public.response_activities
for each row execute function public.log_audit_event();
create trigger audit_users after update or delete on public.users
for each row execute function public.log_audit_event();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.users (id, email, name, role, active)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(new.email, ''), '@', 1)),
    'pending',
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- SECURITY DEFINER helpers avoid recursive RLS reads of public.users.
create or replace function public.current_user_role()
returns text language sql stable security definer set search_path = '' as $$
  select u.role from public.users u where u.id = (select auth.uid()) and u.active
$$;

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

create trigger health_alerts_bhw_confirmation_only
before update of followup_status on public.health_alerts
for each row execute function public.require_bhw_alert_confirmation();

create or replace function public.current_user_rhu_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.rhu_id from public.users u where u.id = (select auth.uid()) and u.active
$$;

create or replace function public.current_user_facility_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.facility_id from public.users u where u.id = (select auth.uid()) and u.active
$$;

create or replace function public.current_user_barangay_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select u.barangay_id from public.users u where u.id = (select auth.uid()) and u.active
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.current_user_role() = 'admin', false)
$$;

create or replace function public.can_access_barangay(target_id uuid, target_name text default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select
    public.is_admin()
    -- This app serves Salcedo municipality. RHU staff are its municipal
    -- clinical authority, so their operational data scope covers every
    -- barangay even when a row is not linked to their RHU record.
    or public.current_user_role() = 'rhu_staff'
    or (
      public.current_user_role() in ('encoder', 'bhw', 'bsi')
      and target_id = public.current_user_barangay_id()
    )
    or (
      public.current_user_role() = 'hospital_staff'
      and exists (
        select 1 from public.facilities f
        where f.id = public.current_user_facility_id()
          and ((target_id is not null and f.barangay_id = target_id)
            or (target_name is not null and f.barangay = target_name))
      )
    )
$$;

create or replace function public.enforce_user_role_scope()
returns trigger language plpgsql set search_path = '' as $$
declare selected_role public.roles%rowtype;
begin
  select * into selected_role from public.roles where id = new.role;
  if not found then raise exception 'Unknown user role'; end if;
  if new.active and new.role = 'pending' then
    raise exception 'Assign a non-pending role before activating this user';
  end if;

  -- Inactive profiles are drafts: let administrators assign role and scope
  -- fields in separate Table Editor saves. Only enforce completeness when the
  -- profile is activated, when all required values must be present together.
  if not new.active then
    -- If the RHU changes on a draft, drop any old child scope that belongs to
    -- another RHU so the composite foreign keys remain valid while editing.
    if tg_op = 'UPDATE' and new.rhu_id is distinct from old.rhu_id then
      if new.facility_id is not null and not exists (
        select 1 from public.facilities f
        where f.id = new.facility_id and f.rhu_id = new.rhu_id
      ) then
        new.facility_id := null;
      end if;
      if new.barangay_id is not null and not exists (
        select 1 from public.barangays b
        where b.id = new.barangay_id and b.rhu_id = new.rhu_id
      ) then
        new.barangay_id := null;
      end if;
    end if;
    return new;
  end if;

  if selected_role.requires_rhu and new.rhu_id is null then raise exception 'RHU assignment is required for this role'; end if;
  if selected_role.requires_facility and new.facility_id is null then raise exception 'Facility assignment is required for this role'; end if;
  if selected_role.requires_barangay and new.barangay_id is null then raise exception 'Barangay assignment is required for this role'; end if;
  if not selected_role.requires_rhu then
    new.rhu_id := null;
    new.facility_id := null;
    new.barangay_id := null;
  else
    if not selected_role.requires_facility then new.facility_id := null; end if;
    if not selected_role.requires_barangay then new.barangay_id := null; end if;
  end if;
  return new;
end;
$$;

create trigger users_enforce_role_scope
before insert or update of role, rhu_id, facility_id, barangay_id, active on public.users
for each row execute function public.enforce_user_role_scope();

create or replace function public.complete_user_setup()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.users
  set password_setup_required = false
  where id = (select auth.uid()) and (active or password_setup_required);
  if not found then raise exception 'Active user profile not found'; end if;
end;
$$;

-- Public dashboard view exposes only weekly buckets meeting the suppression threshold.
create or replace view public.public_cases_summary
with (security_barrier = true) as
select c.barangay,
       date_trunc('week', c.report_date)::date as week_starting,
       count(*)::integer as case_count,
       case
         when count(*) filter (where c.classification = 'confirmed') >= 3
         then count(*) filter (where c.classification = 'confirmed')::integer
         else null
       end as confirmed_count,
       false as is_suppressed
from public.cases c
where c.is_submitted and c.is_duplicate_of is null and c.report_date is not null
group by c.barangay, date_trunc('week', c.report_date)
having count(*) >= 3;

-- Public map controls read metadata independently from case rows.
create or replace view public.public_barangay_names
with (security_barrier = true) as
select b.id, b.name from public.barangays b;

-- Municipality-level totals include every submitted, dated, non-duplicate
-- case. Barangay counts remain suppressed below three cases per barangay-week.
create or replace function public.get_public_dashboard_summary()
returns table (
  total_cases integer,
  affected_barangays integer,
  registered_barangays integer,
  this_week_cases integer,
  this_week_affected_barangays integer,
  has_this_week_data boolean,
  has_reportable_data boolean,
  week_starting date
)
language sql stable security definer set search_path = '' as $$
  with eligible_cases as (
    select c.barangay,
           date_trunc('week', c.report_date at time zone 'UTC')::date as week_starting
    from public.cases c
    where c.is_submitted
      and c.is_duplicate_of is null
      and c.report_date is not null
  ),
  weekly_counts as (
    select e.barangay, e.week_starting, count(*)::integer as case_count
    from eligible_cases e
    group by e.barangay, e.week_starting
  ),
  current_week as (
    select date_trunc('week', now() at time zone 'UTC')::date as week_starting
  )
  select
    (select count(*)::integer from eligible_cases),
    (select count(distinct w.barangay)::integer from weekly_counts w where w.case_count >= 3),
    (select count(*)::integer from public.barangays),
    (select count(*)::integer from eligible_cases e where e.week_starting = (select c.week_starting from current_week c)),
    (select count(distinct w.barangay)::integer from weekly_counts w
      where w.week_starting = (select c.week_starting from current_week c) and w.case_count >= 3),
    exists (select 1 from eligible_cases e where e.week_starting = (select c.week_starting from current_week c)),
    exists (select 1 from eligible_cases),
    (select c.week_starting from current_week c);
$$;

revoke all on function public.get_public_dashboard_summary() from public, anon, authenticated;
grant execute on function public.get_public_dashboard_summary() to anon, authenticated;

-- Public markers summarize cases by barangay. Use the public barangay
-- reference point where available, otherwise a coarsened center of reported
-- locations. Groups below three cases are never returned.
create or replace function public.get_public_case_map(
  p_start_date date default null,
  p_end_date date default null,
  p_barangay text default null
)
returns table (
  latitude double precision,
  longitude double precision,
  barangay text,
  map_category text,
  case_count integer
)
language sql stable security definer set search_path = '' as $$
  with eligible_cases as (
    select c.barangay_id, c.barangay, c.latitude, c.longitude,
           b.latitude as barangay_latitude, b.longitude as barangay_longitude
    from public.cases c
    left join public.barangays b on b.id = c.barangay_id
    where c.is_submitted
      and c.is_duplicate_of is null
      and c.report_date is not null
      and (p_start_date is null or (c.report_date at time zone 'UTC')::date >= p_start_date)
      and (p_end_date is null or (c.report_date at time zone 'UTC')::date < p_end_date)
      and (p_barangay is null or c.barangay = p_barangay)
      and ((b.latitude is not null and b.longitude is not null)
        or (c.latitude is not null and c.longitude is not null))
  ),
  barangay_groups as (
    select
      coalesce(max(e.barangay_latitude), round(avg(e.latitude)::numeric / 0.01) * 0.01)::double precision as latitude,
      coalesce(max(e.barangay_longitude), round(avg(e.longitude)::numeric / 0.01) * 0.01)::double precision as longitude,
      e.barangay,
      count(*)::integer as case_count
    from eligible_cases e
    group by e.barangay_id, e.barangay
    having count(*) >= 3
  )
  select g.latitude, g.longitude, g.barangay, 'public_cluster'::text, g.case_count
  from barangay_groups g;
$$;

alter table public.roles enable row level security;
alter table public.rhu enable row level security;
alter table public.barangays enable row level security;
alter table public.facilities enable row level security;
alter table public.users enable row level security;
alter table public.cases enable row level security;
alter table public.restricted_identity enable row level security;
alter table public.health_alerts enable row level security;
alter table public.response_activities enable row level security;
alter table public.settings enable row level security;
alter table public.audit_log enable row level security;

create policy roles_authenticated_read on public.roles for select to authenticated using (true);
create policy rhu_scoped_read on public.rhu for select to authenticated
  using (public.is_admin() or id = public.current_user_rhu_id());
create policy rhu_admin_write on public.rhu for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy barangays_public_read on public.barangays for select to anon using (true);
create policy barangays_admin_write on public.barangays for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy barangays_rhu_staff_read on public.barangays for select to authenticated
  using (public.current_user_role() = 'rhu_staff');
create policy barangays_encoder_rhu_read on public.barangays for select to authenticated
  using (public.current_user_role() = 'encoder' and rhu_id = public.current_user_rhu_id());
create policy barangays_assigned_read on public.barangays for select to authenticated
  using (public.current_user_role() in ('bhw', 'bsi') and id = public.current_user_barangay_id());
create policy barangays_facility_read on public.barangays for select to authenticated
  using (public.current_user_role() = 'hospital_staff' and exists (
    select 1 from public.facilities f where f.id = public.current_user_facility_id()
      and (f.barangay_id = public.barangays.id or f.barangay = public.barangays.name)
  ));
create policy facilities_scoped_read on public.facilities for select to authenticated
  using (public.is_admin()
    or (public.current_user_role() = 'rhu_staff' and rhu_id = public.current_user_rhu_id())
    or (public.current_user_role() = 'hospital_staff' and id = public.current_user_facility_id()));
create policy facilities_admin_write on public.facilities for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy users_self_or_scoped_read on public.users for select to authenticated using (
  id = (select auth.uid()) or public.is_admin()
  or (public.current_user_role() = 'rhu_staff' and rhu_id = public.current_user_rhu_id())
);
create policy users_admin_update on public.users for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy cases_scoped_read on public.cases for select to authenticated
  using (public.can_access_barangay(barangay_id, barangay));
create policy cases_scoped_insert on public.cases for insert to authenticated
  with check (created_by = (select auth.uid()) and public.can_access_barangay(barangay_id, barangay));
create policy cases_scoped_update on public.cases for update to authenticated
  using (public.can_access_barangay(barangay_id, barangay))
  with check (public.can_access_barangay(barangay_id, barangay));

create policy identity_admin_or_rhu_read on public.restricted_identity for select to authenticated
  using (public.is_admin() or (public.current_user_role() = 'rhu_staff' and exists (
    select 1 from public.cases c where c.id = case_id and public.can_access_barangay(c.barangay_id, c.barangay)
  )));
create policy identity_admin_or_rhu_insert on public.restricted_identity for insert to authenticated
  with check ((public.is_admin() or public.current_user_role() = 'rhu_staff') and exists (
    select 1 from public.cases c where c.id = case_id and public.can_access_barangay(c.barangay_id, c.barangay)
  ));
create policy identity_admin_or_rhu_update on public.restricted_identity for update to authenticated
  using (public.is_admin() or (public.current_user_role() = 'rhu_staff' and exists (
    select 1 from public.cases c where c.id = case_id and public.can_access_barangay(c.barangay_id, c.barangay)
  )))
  with check (public.is_admin() or (public.current_user_role() = 'rhu_staff' and exists (
    select 1 from public.cases c where c.id = case_id and public.can_access_barangay(c.barangay_id, c.barangay)
  )));

create policy alerts_public_insert on public.health_alerts for insert to anon, authenticated with check (true);
create policy alerts_scoped_read on public.health_alerts for select to authenticated
  using (public.can_access_barangay(barangay_id, barangay));
create policy alerts_scoped_update on public.health_alerts for update to authenticated
  using (public.can_access_barangay(barangay_id, barangay))
  with check (public.can_access_barangay(barangay_id, barangay));

create policy activities_scoped_read on public.response_activities for select to authenticated
  using (public.can_access_barangay(barangay_id, barangay));
create policy activities_scoped_insert on public.response_activities for insert to authenticated
  with check (created_by = (select auth.uid()) and public.can_access_barangay(barangay_id, barangay));
create policy activities_scoped_update on public.response_activities for update to authenticated
  using (created_by = (select auth.uid()) or public.is_admin())
  with check (created_by = (select auth.uid()) or public.is_admin());

create policy settings_public_read on public.settings for select to anon, authenticated using (is_public);
create policy settings_admin_all on public.settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy audit_admin_read on public.audit_log for select to authenticated using (public.is_admin());

grant usage on schema public to anon, authenticated;
revoke create on schema public from public;
revoke all on public.roles, public.rhu, public.barangays, public.facilities, public.users,
  public.cases, public.restricted_identity, public.health_alerts, public.response_activities,
  public.settings, public.audit_log, public.public_cases_summary, public.public_barangay_names from anon, authenticated;
grant select on public.public_cases_summary to anon, authenticated;
grant select on public.public_barangay_names to anon, authenticated;
revoke all on function public.get_public_case_map(date, date, text) from public, anon, authenticated;
grant execute on function public.get_public_case_map(date, date, text) to anon, authenticated;
grant update (status, outcome, outcome_date) on public.cases to authenticated;
grant select (id, name, region) on public.barangays to anon;
grant select (key, value) on public.settings to anon;
grant insert (barangay, barangay_id, reporter_name, reporter_address, reporter_age,
  reporter_sex, preferred_contact, contact_value, symptoms,
  onset_date, note, urgency_flag, reference_number, submitted_at)
  on public.health_alerts to anon, authenticated;
grant select on public.roles, public.rhu, public.barangays, public.facilities, public.users,
  public.cases, public.restricted_identity, public.health_alerts, public.response_activities,
  public.settings, public.audit_log to authenticated;
grant insert on public.cases, public.response_activities,
  public.restricted_identity to authenticated;
grant update (classification, report_date, symptom_onset_date, status, age_band, sex,
  barangay, barangay_id, purok, latitude, longitude, location_accuracy, public_grid_lat,
  public_grid_lng, lab_test_type, lab_result, lab_test_date, outcome, outcome_date,
  assigned_worker_id, is_submitted, is_duplicate_of, updated_at) on public.cases to authenticated;
grant update (barangay, barangay_id, preferred_contact, contact_value, symptoms, onset_date,
  note, urgency_flag, assigned_worker_id, followup_status, follow_up_notes,
  follow_up_updated_at) on public.health_alerts to authenticated;
grant update (reporter_name, reporter_address, reporter_age, reporter_sex)
  on public.health_alerts to authenticated;
grant update (activity_type, activity_date, barangay, barangay_id, purok, team,
  households_covered, area_covered_sqm, findings, notes, status, linked_case_id)
  on public.response_activities to authenticated;
grant update (full_name, phone, address, guardian_contact, updated_at)
  on public.restricted_identity to authenticated;
grant insert, update, delete on public.rhu, public.barangays, public.facilities, public.settings to authenticated;
grant update (name, role, rhu_id, facility_id, barangay_id, covered_barangay, team,
  active, password_setup_required, updated_at) on public.users to authenticated;

revoke all on public.users, public.restricted_identity, public.audit_log from anon;
revoke insert, update, delete on public.users from anon, authenticated;
revoke insert, update, delete on public.roles from anon, authenticated;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.current_user_rhu_id() to authenticated;
grant execute on function public.current_user_facility_id() to authenticated;
grant execute on function public.current_user_barangay_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.can_access_barangay(uuid, text) to authenticated;
revoke all on function public.current_user_role() from public, anon;
revoke all on function public.current_user_rhu_id() from public, anon;
revoke all on function public.current_user_facility_id() from public, anon;
revoke all on function public.current_user_barangay_id() from public, anon;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.can_access_barangay(uuid, text) from public, anon;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.enforce_user_role_scope() from public, anon, authenticated;
revoke all on function public.log_audit_event() from public, anon, authenticated;
revoke all on function public.complete_user_setup() from public, anon;
grant execute on function public.complete_user_setup() to authenticated;

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

-- Do not copy service-role keys into Flutter. Deploy the admin-create-user Edge Function separately.
