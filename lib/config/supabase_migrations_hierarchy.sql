-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Salcedo Dengue Watch - Enhanced Schema with Hierarchical Structure
-- Includes: RHU → Facilities → Barangays → Users hierarchy
-- Copy and paste this entire block into Supabase SQL Editor

-- Enable pgcrypto for UUID generation
create extension if not exists "pgcrypto";

-- ============================================
-- CLEANUP EXISTING TABLES (if they exist with old schema)
-- ============================================

-- Drop views first (they depend on tables)
drop view if exists public.public_cases_summary cascade;

-- Drop tables in reverse order of dependencies to avoid foreign key errors
drop table if exists public.response_activities cascade;
drop table if exists public.health_alerts cascade;
drop table if exists public.restricted_identity cascade;
drop table if exists public.cases cascade;
drop table if exists public.users cascade;
drop table if exists public.barangays cascade;
drop table if exists public.facilities cascade;
drop table if exists public.rhu cascade;
drop table if exists public.settings cascade;
drop table if exists public.audit_log cascade;

-- ============================================
-- HIERARCHY TABLES (New)
-- ============================================

-- REGIONAL HEALTH UNITS (RHU)
create table if not exists public.rhu (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  region text,
  contact_person text,
  contact_number text,
  email text,
  address text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- FACILITIES (Hospitals, Clinics) - belong to RHU
create table if not exists public.facilities (
  id uuid primary key default gen_random_uuid(),
  rhu_id uuid not null references public.rhu(id) on delete cascade,
  name text not null,
  facility_type text not null, -- 'hospital' or 'clinic'
  contact_person text,
  contact_number text,
  email text,
  address text,
  barangay text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(rhu_id, name)
);

-- BARANGAYS - served by RHU
create table if not exists public.barangays (
  id uuid primary key default gen_random_uuid(),
  rhu_id uuid not null references public.rhu(id) on delete cascade,
  name text not null,
  region text,
  population integer,
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(rhu_id, name)
);

-- ============================================
-- UPDATED USERS TABLE (With Hierarchy)
-- ============================================

create table if not exists public.users (
  id uuid primary key,
  email text unique not null,
  name text not null,
  role text not null default 'encoder', -- 'admin'/'rhu_staff'/'encoder'/'bhw'/'bsi'/'hospital_staff'
  rhu_id uuid references public.rhu(id) on delete set null,
  facility_id uuid references public.facilities(id) on delete set null,
  barangay_id uuid references public.barangays(id) on delete set null,
  -- For backward compatibility, keep covered_barangay if user not assigned to specific barangay_id
  covered_barangay text[],
  team text[],
  active boolean default true,
  created_by uuid references public.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- CASES TABLE (unchanged structure)
-- ============================================

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  classification text,
  report_date timestamptz,
  symptom_onset_date timestamptz,
  status text,
  age_band text,
  sex text,
  barangay text,
  barangay_id uuid references public.barangays(id) on delete set null,
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

-- RESTRICTED IDENTITY TABLE (unchanged)
create table if not exists public.restricted_identity (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references public.cases(id) on delete cascade unique,
  full_name text,
  phone text,
  address text,
  guardian text,
  created_at timestamptz default now()
);

-- ============================================
-- HEALTH ALERTS TABLE (unchanged)
-- ============================================

create table if not exists public.health_alerts (
  id uuid primary key default gen_random_uuid(),
  barangay text,
  barangay_id uuid references public.barangays(id) on delete set null,
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

-- ============================================
-- RESPONSE ACTIVITIES TABLE (unchanged)
-- ============================================

create table if not exists public.response_activities (
  id uuid primary key default gen_random_uuid(),
  activity_type text,
  activity_time timestamptz default now(),
  barangay text,
  barangay_id uuid references public.barangays(id) on delete set null,
  purok text,
  team text[],
  households_covered integer,
  notes text,
  linked_case_id uuid references public.cases(id),
  created_by uuid references public.users(id),
  created_at timestamptz default now()
);

-- ============================================
-- SETTINGS TABLE (unchanged)
-- ============================================

create table if not exists public.settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);

-- ============================================
-- AUDIT LOG TABLE (unchanged)
-- ============================================

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

-- ============================================
-- VIEWS FOR AGGREGATED DATA
-- ============================================

-- Drop view if it exists to avoid column name conflicts
drop view if exists public.public_cases_summary;

-- Public cases summary (aggregated by barangay and week)
create view public.public_cases_summary as
select
  barangay,
  date_trunc('week', report_date)::date as week_starting,
  count(*) as case_count,
  count(case when classification = 'confirmed' then 1 end) as confirmed_count,
  case
    when count(*) < 5 then true  -- suppress if < 5 cases
    else false
  end as is_suppressed
from public.cases
where is_submitted = true
group by barangay, date_trunc('week', report_date);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS on all tables
alter table public.users enable row level security;
alter table public.cases enable row level security;
alter table public.restricted_identity enable row level security;
alter table public.health_alerts enable row level security;
alter table public.response_activities enable row level security;
alter table public.settings enable row level security;
alter table public.audit_log enable row level security;
alter table public.rhu enable row level security;
alter table public.facilities enable row level security;
alter table public.barangays enable row level security;

-- ============================================
-- AUTOMATIC USER PROFILE CREATION TRIGGER
-- ============================================

-- Function to handle new user creation
create or replace function public.handle_new_user()
returns trigger as $$
declare
  default_rhu_id uuid;
  default_role text := 'encoder'; -- Default role for new users
begin
  -- Get the first RHU ID as default (if exists)
  select id into default_rhu_id from public.rhu limit 1;
  
  -- Insert new user profile with default values
  insert into public.users (id, email, name, role, rhu_id, active)
  values (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    default_role,
    default_rhu_id,
    false  -- New users start as inactive for admin approval
  );
  
  return new;
end;
$$ language plpgsql security definer;

-- Drop existing trigger if it exists
drop trigger if exists on_auth_user_created on auth.users;

-- Create trigger to call the function when a new auth user is created
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================
-- SECURITY DEFINER FUNCTIONS FOR ROLE CHECKING
-- ============================================

-- Function to get user role without RLS recursion
create or replace function public.get_user_role(user_id uuid)
returns text as $$
  select role from public.users where id = user_id limit 1;
$$ language sql security definer;

-- Function to check if user is admin
create or replace function public.is_admin(user_id uuid)
returns boolean as $$
  select exists (select 1 from public.users where id = user_id and role = 'admin');
$$ language sql security definer;

-- Function to check if user has specific role
create or replace function public.has_role(user_id uuid, role_name text)
returns boolean as $$
  select exists (select 1 from public.users where id = user_id and role = role_name);
$$ language sql security definer;

-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Users can read their own profile
create policy "user_read_self" on public.users
  for select using (
    auth.uid() = id
  );

-- Users can update their own profile
create policy "user_update_self" on public.users
  for update using (
    auth.uid() = id
  );

-- Note: For admin operations, we'll use a security definer function or app-level checks
-- to avoid infinite recursion in RLS policies

-- Allow public to read users (this will be filtered at app level)
create policy "public_read_users" on public.users
  for select using (true);

-- ============================================
-- CASES TABLE POLICIES
-- ============================================

-- Public can read aggregated/suppressed data
create policy "public_read_cases" on public.cases
  for select using (
    auth.role() = 'anon'
  );

-- Admin can read all cases
create policy "admin_read_cases" on public.cases
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read cases in their RHU
create policy "rhu_staff_read_cases" on public.cases
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    barangay_id in (
      select id from public.barangays 
      where rhu_id = (select rhu_id from public.users where id = auth.uid())
    )
  );

-- Hospital/clinic staff can read cases from their facility's barangay
create policy "facility_staff_read_cases" on public.cases
  for select using (
    public.has_role(auth.uid(), 'hospital_staff') and
    barangay = (select barangay from public.facilities where id = (select facility_id from public.users where id = auth.uid()))
  );

-- BHW/BSI can read cases in their barangay
create policy "bhw_bsi_read_cases" on public.cases
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and
    barangay_id = (select barangay_id from public.users where id = auth.uid())
  );

-- Encoders can create/update cases
create policy "encoder_create_cases" on public.cases
  for insert with check (
    public.has_role(auth.uid(), 'admin') or 
    public.has_role(auth.uid(), 'encoder') or 
    public.has_role(auth.uid(), 'bhw') or 
    public.has_role(auth.uid(), 'bsi')
  );

create policy "encoder_update_cases" on public.cases
  for update using (
    public.has_role(auth.uid(), 'admin') or 
    public.has_role(auth.uid(), 'encoder') or
    created_by = auth.uid()
  );

-- ============================================
-- RESTRICTED IDENTITY POLICIES (Staff-only)
-- ============================================

-- Admin can read all restricted identities
create policy "admin_read_restricted" on public.restricted_identity
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read restricted identities for their RHU
create policy "rhu_staff_read_restricted" on public.restricted_identity
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    case_id in (
      select c.id from public.cases c
      where c.barangay_id in (
        select id from public.barangays 
        where rhu_id = (select rhu_id from public.users where id = auth.uid())
      )
    )
  );

-- BHW/BSI can read restricted identities for their barangay
create policy "bhw_bsi_read_restricted" on public.restricted_identity
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and
    case_id in (
      select c.id from public.cases c
      where c.barangay_id = (select barangay_id from public.users where id = auth.uid())
    )
  );

-- ============================================
-- HEALTH ALERTS POLICIES
-- ============================================

-- Admin can read all alerts
create policy "admin_read_alerts" on public.health_alerts
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read alerts in their RHU
create policy "rhu_staff_read_alerts" on public.health_alerts
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    barangay_id in (
      select id from public.barangays 
      where rhu_id = (select rhu_id from public.users where id = auth.uid())
    )
  );

-- BHW/BSI can read alerts in their barangay
create policy "bhw_bsi_read_alerts" on public.health_alerts
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and
    barangay_id = (select barangay_id from public.users where id = auth.uid())
  );

-- Anyone can create alerts
create policy "public_create_alerts" on public.health_alerts
  for insert with check (true);

-- ============================================
-- RESPONSE ACTIVITIES POLICIES
-- ============================================

-- Admin can read all activities
create policy "admin_read_activities" on public.response_activities
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read activities in their RHU
create policy "rhu_staff_read_activities" on public.response_activities
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    barangay_id in (
      select id from public.barangays 
      where rhu_id = (select rhu_id from public.users where id = auth.uid())
    )
  );

-- Encoders can create activities
create policy "encoder_create_activities" on public.response_activities
  for insert with check (
    public.has_role(auth.uid(), 'admin') or 
    public.has_role(auth.uid(), 'encoder') or 
    public.has_role(auth.uid(), 'bhw') or 
    public.has_role(auth.uid(), 'bsi')
  );

-- ============================================
-- RHU TABLE POLICIES
-- ============================================

-- Admin can manage RHUs
create policy "admin_read_rhu" on public.rhu
  for select using (
    public.is_admin(auth.uid())
  );

create policy "admin_manage_rhu" on public.rhu
  for insert with check (
    public.is_admin(auth.uid())
  );

create policy "admin_update_rhu" on public.rhu
  for update using (
    public.is_admin(auth.uid())
  );

create policy "admin_delete_rhu" on public.rhu
  for delete using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read their RHU
create policy "rhu_staff_read_own" on public.rhu
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    id = (select rhu_id from public.users where id = auth.uid())
  );

-- ============================================
-- FACILITIES TABLE POLICIES
-- ============================================

-- Admin can manage facilities
create policy "admin_read_facilities" on public.facilities
  for select using (
    public.is_admin(auth.uid())
  );

create policy "admin_manage_facilities" on public.facilities
  for insert with check (
    public.is_admin(auth.uid())
  );

create policy "admin_update_facilities" on public.facilities
  for update using (
    public.is_admin(auth.uid())
  );

create policy "admin_delete_facilities" on public.facilities
  for delete using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read facilities in their RHU
create policy "rhu_staff_read_facilities" on public.facilities
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    rhu_id = (select rhu_id from public.users where id = auth.uid())
  );

-- Facility staff can read their own facility
create policy "facility_staff_read_own" on public.facilities
  for select using (
    public.has_role(auth.uid(), 'hospital_staff') and
    id = (select facility_id from public.users where id = auth.uid())
  );

-- ============================================
-- BARANGAYS TABLE POLICIES
-- ============================================

-- Public (unauthenticated) can read barangay names for health alerts and public dashboards
create policy "public_read_barangays" on public.barangays
  for select using (
    true
  );

-- Admin can manage barangays
create policy "admin_read_barangays" on public.barangays
  for select using (
    public.is_admin(auth.uid())
  );

create policy "admin_manage_barangays" on public.barangays
  for insert with check (
    public.is_admin(auth.uid())
  );

create policy "admin_update_barangays" on public.barangays
  for update using (
    public.is_admin(auth.uid())
  );

create policy "admin_delete_barangays" on public.barangays
  for delete using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read barangays in their RHU
create policy "rhu_staff_read_barangays" on public.barangays
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    rhu_id = (select rhu_id from public.users where id = auth.uid())
  );

-- Encoder can read barangays in their RHU
create policy "encoder_read_barangays" on public.barangays
  for select using (
    public.has_role(auth.uid(), 'encoder') and
    rhu_id = (select rhu_id from public.users where id = auth.uid())
  );

-- BHW/BSI can read their barangay
create policy "bhw_bsi_read_barangay" on public.barangays
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and
    id = (select barangay_id from public.users where id = auth.uid())
  );

-- Hospital staff can read barangays associated with their facility's RHU
create policy "hospital_staff_read_barangays" on public.barangays
  for select using (
    public.has_role(auth.uid(), 'hospital_staff') and
    rhu_id = (select rhu_id from public.facilities where id = (select facility_id from public.users where id = auth.uid()))
  );

-- ============================================
-- SETTINGS & AUDIT LOG POLICIES (Admin only)
-- ============================================

create policy "admin_read_settings" on public.settings
  for select using (
    public.is_admin(auth.uid())
  );

create policy "admin_manage_settings" on public.settings
  for insert with check (
    public.is_admin(auth.uid())
  );

create policy "admin_update_settings" on public.settings
  for update using (
    public.is_admin(auth.uid())
  );

create policy "admin_read_audit" on public.audit_log
  for select using (
    public.is_admin(auth.uid())
  );

-- ============================================
-- SECURITY DEFINER FUNCTIONS FOR ROLE CHECKING
-- ============================================

-- ============================================
-- TRIGGERS FOR AUDIT LOGGING & AUTO-FIELDS
-- ============================================

-- Log changes to audit_log table
create or replace function public.log_changes()
returns trigger as $$
begin
  insert into public.audit_log (user_id, action, record_type, record_id, before, after)
  values (auth.uid(), tg_op, tg_table_name, new.id, row_to_json(old), row_to_json(new));
  return new;
end;
$$ language plpgsql security definer;

-- Attach trigger to main tables
drop trigger if exists log_cases_changes on public.cases;
create trigger log_cases_changes after insert or update or delete on public.cases
  for each row execute function public.log_changes();

drop trigger if exists log_users_changes on public.users;
create trigger log_users_changes after insert or update or delete on public.users
  for each row execute function public.log_changes();

drop trigger if exists log_alerts_changes on public.health_alerts;
create trigger log_alerts_changes after insert or update or delete on public.health_alerts
  for each row execute function public.log_changes();

-- ============================================
-- SEED DATA (Optional - for testing)
-- ============================================

-- Insert default admin RHU
insert into public.rhu (name, region, contact_person, contact_number, email, address, latitude, longitude)
values (
  'Salcedo RHU',
  'Eastern Samar',
  'Dr. Maria Santos',
  '09123456789',
  'rhu@salcedo.gov.ph',
  'Salcedo, Eastern Samar',
  11.14922,  -- Salcedo, Eastern Samar coordinates
  125.66287
) on conflict do nothing;

-- Insert sample barangays with coordinates
insert into public.barangays (rhu_id, name, region, population, latitude, longitude)
select id, 'Barangay 1', 'Eastern Samar', 5000, 11.1550, 125.2350
from public.rhu where name = 'Salcedo RHU'
on conflict do nothing;

insert into public.barangays (rhu_id, name, region, population, latitude, longitude)
select id, 'Barangay 2', 'Eastern Samar', 4500, 11.1450, 125.2250
from public.rhu where name = 'Salcedo RHU'
on conflict do nothing;

insert into public.barangays (rhu_id, name, region, population, latitude, longitude)
select id, 'Barangay 3', 'Eastern Samar', 3800, 11.1600, 125.2400
from public.rhu where name = 'Salcedo RHU'
on conflict do nothing;

-- Insert sample facility with coordinates
insert into public.facilities (rhu_id, name, facility_type, contact_person, contact_number, email, address, barangay, latitude, longitude)
select id, 'Salcedo Health Center', 'clinic', 'Nurse Rosa', '09987654321', 'hc@salcedo.gov.ph', 'Salcedo', 'Barangay 1', 11.1520, 125.2320
from public.rhu where name = 'Salcedo RHU'
on conflict do nothing;
