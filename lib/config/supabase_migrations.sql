-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Supabase schema and Row Level Security (RLS) policies
-- Run this in the Supabase SQL Editor after creating a new project.
-- Review comments and adapt roles/fields to your deployment.

-- Enable pgcrypto for UUID generation (if not already enabled)
create extension if not exists "pgcrypto";

-- USERS / PROFILES
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  role text not null default 'encoder', -- values: public/encoder/admin
  covered_barangay text[], -- list of barangays this user may access; null = all
  active boolean default true,
  created_at timestamptz default now()
);

-- CASES (public-safe fields separated from restricted identity)
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
  -- public generalized coordinates for map privacy (rounded/jittered)
  public_grid_lat double precision,
  public_grid_lng double precision,
  longitude double precision,
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

-- Restricted identity (separate table to reduce accidental exposure)
create table if not exists public.restricted_identity (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references public.cases(id) unique,
  full_name text,
  phone text,
  address text,
  guardian text,
  created_at timestamptz default now()
);

-- Health alerts from residents
create table if not exists public.health_alerts (
  id uuid primary key default gen_random_uuid(),
  barangay text,
  preferred_contact text,
  symptoms text[],
  onset_date timestamptz,
  note text,
  submitted_at timestamptz default now(),
  urgency text,
  assigned_worker_id uuid references public.users(id),
  followup_status text default 'new'
);

-- Response activities
create table if not exists public.response_activities (
  id uuid primary key default gen_random_uuid(),
  activity_type text,
  activity_time timestamptz default now(),
  barangay text,
  purok text,
  team text[],
  households_covered int,
  notes text,
  linked_case_id uuid references public.cases(id)
);

-- Settings key/value store
create table if not exists public.settings (
  key text primary key,
  value jsonb,
  updated_at timestamptz default now()
);

-- Audit log for changes (do not store raw sensitive fields here)
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

-- Trigger function to insert audit entries
create or replace function public.log_changes() returns trigger language plpgsql as $$
begin
  if (tg_op = 'DELETE') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (current_setting('jwt.claims.user_id', true)::uuid, 'delete', tg_table_name::text, old.id, row_to_json(old)::jsonb, null);
    return old;
  elsif (tg_op = 'UPDATE') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (current_setting('jwt.claims.user_id', true)::uuid, 'update', tg_table_name::text, new.id, row_to_json(old)::jsonb, row_to_json(new)::jsonb);
    return new;
  elsif (tg_op = 'INSERT') then
    insert into public.audit_log(user_id, action, record_type, record_id, before, after)
    values (current_setting('jwt.claims.user_id', true)::uuid, 'insert', tg_table_name::text, new.id, null, row_to_json(new)::jsonb);
    return new;
  end if;
  return null;
end;
$$;

-- Attach audit trigger to tables (avoid attaching to restricted_identity if you prefer)
create trigger cases_audit after insert or update or delete on public.cases for each row execute function public.log_changes();
create trigger health_alerts_audit after insert or update or delete on public.health_alerts for each row execute function public.log_changes();
create trigger response_activities_audit after insert or update or delete on public.response_activities for each row execute function public.log_changes();

-- BEFORE trigger: enforce required fields when a case is submitted and compute public generalized grid
create or replace function public.cases_before_write() returns trigger language plpgsql as $$
begin
  -- If the record is being submitted, ensure required fields exist
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

  -- Compute public generalized grid coordinates for public map (rounded to 3 decimals)
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

-- ROW LEVEL SECURITY (RLS)
-- Enable RLS on tables that contain sensitive or staff-only data.
alter table public.users enable row level security;
alter table public.cases enable row level security;
alter table public.restricted_identity enable row level security;
alter table public.health_alerts enable row level security;
alter table public.response_activities enable row level security;

-- USERS: allow authenticated users to insert their profile row (application should insert matching uuid)
create policy "insert_user_if_authenticated" on public.users for insert using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- USERS: select/modify only by admin or the user themselves
create policy "select_users_admin_or_self" on public.users for select using (
  (exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.role = 'admin'))
  or id = auth.uid()::uuid
);
create policy "update_users_admin_or_self" on public.users for update using (
  (exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.role = 'admin'))
  or id = auth.uid()::uuid
) with check (
  (exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.role = 'admin'))
  or id = auth.uid()::uuid
);

-- CASES: allow authenticated staff to insert (must be recorded as created_by = auth.uid())
create policy "insert_cases_authenticated" on public.cases for insert using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated' and created_by = auth.uid()::uuid);

-- CASES: select policy - admins can see all; encoders can see rows for their covered barangays or rows they created/assigned
create policy "select_cases_staff" on public.cases for select using (
  exists (
    select 1 from public.users u where u.id = auth.uid()::uuid and u.active = true and (
      u.role = 'admin' OR (
        u.role = 'encoder' AND (
          u.covered_barangay IS NULL OR barangay = any(u.covered_barangay)
        )
      )
    )
  )
);

-- CASES: update/delete restricted to admins or assigned worker or created_by
create policy "update_cases_admin_or_assigned" on public.cases for update using (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.role = 'admin')
  OR assigned_worker_id = auth.uid()::uuid
  OR created_by = auth.uid()::uuid
)
with check (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.role = 'admin')
  OR assigned_worker_id = auth.uid()::uuid
  OR created_by = auth.uid()::uuid
);

-- RESTRICTED_IDENTITY: only staff who can see the linked case can see identity
create policy "select_restricted_identity_linked_case" on public.restricted_identity for select using (
  exists (
    select 1 from public.cases c join public.users u on u.id = auth.uid()::uuid where c.id = case_id and (
      u.role = 'admin' OR (u.role = 'encoder' AND (u.covered_barangay IS NULL OR c.barangay = any(u.covered_barangay)))
    )
  )
);

create policy "insert_restricted_identity_staff" on public.restricted_identity for insert using (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.active = true)
)
with check (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.active = true)
);

-- HEALTH_ALERTS: allow public inserts (anonymous) and staff to see assigned alerts
alter table public.health_alerts enable row level security;
create policy "insert_health_alerts_anon" on public.health_alerts for insert using (true) with check (true);
create policy "select_health_alerts_staff" on public.health_alerts for select using (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and (u.role = 'admin' OR u.role = 'encoder'))
);

-- RESPONSE ACTIVITIES: staff-only operations
create policy "insert_response_activities_staff" on public.response_activities for insert using (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.active = true)
) with check (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and u.active = true)
);
create policy "select_response_activities_staff" on public.response_activities for select using (
  exists (select 1 from public.users u where u.id = auth.uid()::uuid and (u.role = 'admin' OR u.role = 'encoder'))
);

-- PUBLIC SUMMARY VIEW: aggregated counts by barangay and week with suppression flag
create or replace view public.public_cases_summary as
select
  barangay,
  date_trunc('week', report_date) as week,
  count(*) as cases,
  bool_and(is_submitted) as all_submitted,
  (count(*) < 5) as suppressed
from public.cases
where report_date is not null
group by barangay, date_trunc('week', report_date);

-- Grant read permission on the summary view to the anon role (public web client)
grant select on public.public_cases_summary to anon;

-- NOTE:
-- - The policies above are a starting point. Test them with your real Supabase Auth users and adjust logic for covered areas.
-- - The audit trigger uses `jwt.claims.user_id` which requires a mapping in your JWT. Supabase provides `auth.uid()` in policies; the trigger reads current_setting('jwt.claims.user_id') if present.
-- - Keep the service_role key secure; never embed it in the mobile app. Use server-side functions for privileged tasks.
