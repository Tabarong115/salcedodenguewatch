-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Salcedo Dengue Watch - Supabase Schema & RLS Policies (CORRECTED)
-- This version fixes the INSERT policy syntax errors
-- Copy and paste this entire block into Supabase SQL Editor

-- Enable pgcrypto for UUID generation
create extension if not exists "pgcrypto";

-- USERS / PROFILES TABLE
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  name text,
  role text not null default 'encoder', -- values: encoder/admin
  covered_barangay text[], -- list of barangays; null = all
  team text[],
  active boolean default true,
  created_at timestamptz default now()
);

-- CASES TABLE (public-safe fields; restricted identity in separate table)
create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  classification text,
  report_date timestamptz,
  symptom_onset_date timestamptz,
  status text,
  age_band text,
  sex text,
  barangay text,
  purok text,
  latitude double precision,
  longitude double precision,
  public_grid_lat double precision,
  public_grid_lng double precision,
  lab_test_type text,
  lab_result text,
  lab_test_date timestamptz,
  outcome text,
  outcome_date timestamptz,
  assigned_worker_id uuid references public.users(id),
  created_by uuid references public.users(id),
  is_submitted boolean default false,
  created_at timestamptz default now()
);

-- RESTRICTED IDENTITY TABLE (linked to cases; staff-only access)
create table if not exists public.restricted_identity (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references public.cases(id) on delete cascade unique,
  full_name text,
  phone text,
  address text,
  guardian text,
  created_at timestamptz default now()
);

-- HEALTH ALERTS TABLE (resident requests for follow-up)
create table if not exists public.health_alerts (
  id uuid primary key default gen_random_uuid(),
  barangay text,
  preferred_contact text,
  contact_value text,
  symptoms text[],
  onset_date timestamptz,
  note text,
  submitted_at timestamptz default now(),
  urgency text default 'low',
  assigned_worker_id uuid references public.users(id),
  followup_status text default 'new'
);

-- RESPONSE ACTIVITIES TABLE (field work logging)
create table if not exists public.response_activities (
  id uuid primary key default gen_random_uuid(),
  activity_type text,
  activity_time timestamptz default now(),
  barangay text,
  purok text,
  team text[],
  households_covered int,
  notes text,
  linked_case_id uuid references public.cases(id),
  created_by uuid references public.users(id),
  created_at timestamptz default now()
);

-- SETTINGS TABLE (admin configuration; key-value store)
create table if not exists public.settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);

-- AUDIT LOG TABLE (track all changes)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  action text,
  record_type text,
  record_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz default now()
);

-- TRIGGER FUNCTION: Log changes to audit_log
create or replace function public.log_changes() returns trigger language plpgsql as $$
begin
  if (tg_op = 'DELETE') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (auth.uid(), 'delete', tg_table_name::text, old.id, row_to_json(old)::jsonb, null);
    return old;
  elsif (tg_op = 'UPDATE') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (auth.uid(), 'update', tg_table_name::text, new.id, row_to_json(old)::jsonb, row_to_json(new)::jsonb);
    return new;
  elsif (tg_op = 'INSERT') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (auth.uid(), 'insert', tg_table_name::text, new.id, null, row_to_json(new)::jsonb);
    return new;
  end if;
  return null;
end;
$$;

-- Attach audit triggers
create trigger cases_audit after insert or update or delete on public.cases for each row execute function public.log_changes();
create trigger health_alerts_audit after insert or update or delete on public.health_alerts for each row execute function public.log_changes();
create trigger response_activities_audit after insert or update or delete on public.response_activities for each row execute function public.log_changes();

-- BEFORE TRIGGER: Enforce required fields when case is submitted and compute public grid
create or replace function public.cases_before_write() returns trigger language plpgsql as $$
begin
  if (new.is_submitted = true) then
    if new.report_date is null then
      raise exception 'report_date is required when submitting case';
    end if;
    if new.symptom_onset_date is null then
      raise exception 'symptom_onset_date is required when submitting case';
    end if;
    if new.latitude is null or new.longitude is null then
      raise exception 'latitude and longitude are required when submitting case';
    end if;
  end if;

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

create trigger cases_before_write_trigger before insert or update on public.cases for each row execute function public.cases_before_write();

-- ENABLE ROW LEVEL SECURITY (RLS)
alter table public.users enable row level security;
alter table public.cases enable row level security;
alter table public.restricted_identity enable row level security;
alter table public.health_alerts enable row level security;
alter table public.response_activities enable row level security;
alter table public.settings enable row level security;
alter table public.audit_log enable row level security;

-- ============================================================================
-- RLS POLICIES: USERS TABLE
-- ============================================================================

-- INSERT: Allow authenticated users to create themselves
create policy "insert_user_if_authenticated" on public.users 
  for insert 
  with check (auth.role() = 'authenticated');

-- SELECT: Admin or self
create policy "select_users_admin_or_self" on public.users 
  for select 
  using (
    (select role from public.users where id = auth.uid()) = 'admin' 
    or id = auth.uid()
  );

-- UPDATE: Admin or self
create policy "update_users_admin_or_self" on public.users 
  for update 
  using (
    (select role from public.users where id = auth.uid()) = 'admin' 
    or id = auth.uid()
  ) 
  with check (
    (select role from public.users where id = auth.uid()) = 'admin' 
    or id = auth.uid()
  );

-- ============================================================================
-- RLS POLICIES: CASES TABLE
-- ============================================================================

-- INSERT: Only authenticated staff (created_by must equal current user)
create policy "insert_cases_authenticated" on public.cases 
  for insert 
  with check (
    auth.role() = 'authenticated' 
    and created_by = auth.uid()
  );

-- SELECT: Staff can see cases in their covered barangays; admin sees all
create policy "select_cases_staff" on public.cases 
  for select 
  using (
    exists (
      select 1 from public.users u 
      where u.id = auth.uid() 
      and u.active = true 
      and (
        u.role = 'admin' 
        OR (
          u.role = 'encoder' 
          AND (u.covered_barangay IS NULL OR barangay = any(u.covered_barangay))
        )
      )
    )
  );

-- UPDATE: Admin, assigned worker, or creator
create policy "update_cases_admin_or_assigned" on public.cases 
  for update 
  using (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR assigned_worker_id = auth.uid() 
    OR created_by = auth.uid()
  ) 
  with check (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR assigned_worker_id = auth.uid() 
    OR created_by = auth.uid()
  );

-- ============================================================================
-- RLS POLICIES: RESTRICTED_IDENTITY TABLE
-- ============================================================================

-- SELECT: Only if user can see the linked case
create policy "select_restricted_identity_if_can_see_case" on public.restricted_identity 
  for select 
  using (
    exists (
      select 1 from public.cases c 
      join public.users u on u.id = auth.uid() 
      where c.id = case_id 
      and (
        u.role = 'admin' 
        OR (
          u.role = 'encoder' 
          AND (u.covered_barangay IS NULL OR c.barangay = any(u.covered_barangay))
        )
      )
    )
  );

-- INSERT: Only authenticated active staff
create policy "insert_restricted_identity_staff" on public.restricted_identity 
  for insert 
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
  );

-- ============================================================================
-- RLS POLICIES: HEALTH_ALERTS TABLE
-- ============================================================================

-- INSERT: Allow anonymous users (public residents)
create policy "insert_health_alerts_anon" on public.health_alerts 
  for insert 
  with check (true);

-- SELECT: Only authenticated staff (admin or encoder)
create policy "select_health_alerts_staff" on public.health_alerts 
  for select 
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and (u.role = 'admin' OR u.role = 'encoder'))
  );

-- UPDATE: Admin or assigned worker
create policy "update_health_alerts_admin_or_assigned" on public.health_alerts 
  for update 
  using (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR assigned_worker_id = auth.uid()
  ) 
  with check (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR assigned_worker_id = auth.uid()
  );

-- ============================================================================
-- RLS POLICIES: RESPONSE_ACTIVITIES TABLE
-- ============================================================================

-- INSERT: Only authenticated active staff
create policy "insert_response_activities_staff" on public.response_activities 
  for insert 
  with check (
    exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
  );

-- SELECT: Only authenticated staff (admin or encoder)
create policy "select_response_activities_staff" on public.response_activities 
  for select 
  using (
    exists (select 1 from public.users u where u.id = auth.uid() and (u.role = 'admin' OR u.role = 'encoder'))
  );

-- UPDATE: Admin or creator
create policy "update_response_activities_admin_or_creator" on public.response_activities 
  for update 
  using (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR created_by = auth.uid()
  ) 
  with check (
    (select role from public.users where id = auth.uid()) = 'admin' 
    OR created_by = auth.uid()
  );

-- ============================================================================
-- RLS POLICIES: SETTINGS TABLE (admin-only)
-- ============================================================================

-- SELECT: Admin only
create policy "select_settings_admin" on public.settings 
  for select 
  using ((select role from public.users where id = auth.uid()) = 'admin');

-- INSERT: Admin only
create policy "insert_settings_admin" on public.settings 
  for insert 
  with check ((select role from public.users where id = auth.uid()) = 'admin');

-- UPDATE: Admin only
create policy "update_settings_admin" on public.settings 
  for update 
  using ((select role from public.users where id = auth.uid()) = 'admin') 
  with check ((select role from public.users where id = auth.uid()) = 'admin');

-- ============================================================================
-- RLS POLICIES: AUDIT_LOG TABLE (admin-only, read-only)
-- ============================================================================

-- SELECT: Admin only
create policy "select_audit_log_admin" on public.audit_log 
  for select 
  using ((select role from public.users where id = auth.uid()) = 'admin');

-- ============================================================================
-- PUBLIC SUMMARY VIEW (aggregated, safe for public display)
-- ============================================================================

create or replace view public.public_cases_summary as
select
  barangay,
  date_trunc('week', report_date)::date as week_start,
  count(*) as cases,
  (count(*) < 5) as suppressed
from public.cases
where report_date is not null and is_submitted = true
group by barangay, date_trunc('week', report_date);

-- Grant public read access to the summary view
grant select on public.public_cases_summary to anon;

-- ============================================================================
-- DONE: All tables, triggers, and RLS policies are now created.
-- ============================================================================
