SUPABASE SETUP GUIDE — Complete Step-by-Step

> **Current setup:** This document describes the previous schema and is retained for reference. For a new Supabase project, use [`supabase/README.md`](supabase/README.md) and its canonical migration. Do not run the historical SQL from `lib/config/`.

This guide walks you through creating a Supabase project, applying migrations, seeding data, and configuring the app for production use. Every step has copy-paste code ready to go.

═══════════════════════════════════════════════════════════════════════════════
PART 1: CREATE SUPABASE PROJECT & AUTH
═══════════════════════════════════════════════════════════════════════════════

1.1) Go to https://app.supabase.com and sign in with your email.

1.2) Click "New project" → "New project" (not "+ New" at the top).

1.3) Fill in:
   - Project name: salcedo-dengue-watch
   - Database password: (choose a strong password, save it)
   - Region: Asia Pacific (Singapore) or closest to your users
   - Click "Create new project"

1.4) Wait ~3-5 minutes for the project to initialize. You'll see a green checkmark.

1.5) Once ready, go to Settings → API.
   - Copy "Project URL" (looks like: https://xxxxx.supabase.co)
   - Copy the "anon public" key
   - Save both in a text file. You'll need them later for the app.
   - DO NOT copy or use the "service_role" (secret) key in the app.

═══════════════════════════════════════════════════════════════════════════════
PART 2: APPLY DATABASE MIGRATIONS (CREATE TABLES & POLICIES)
═══════════════════════════════════════════════════════════════════════════════

2.1) In Supabase console, click "SQL Editor" (left sidebar).

2.2) Click "+ New Query" to open a blank SQL editor.

2.3) Copy and paste ALL the SQL code below into the SQL editor. Then click "Run".

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BEGIN: COPY THIS ENTIRE SQL BLOCK AND PASTE INTO SUPABASE SQL EDITOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

-- RLS POLICIES: USERS TABLE
create policy "insert_user_if_authenticated" on public.users for insert using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "select_users_admin_or_self" on public.users for select using (
  (select role from public.users where id = auth.uid()) = 'admin' or id = auth.uid()
);

create policy "update_users_admin_or_self" on public.users for update using (
  (select role from public.users where id = auth.uid()) = 'admin' or id = auth.uid()
) with check (
  (select role from public.users where id = auth.uid()) = 'admin' or id = auth.uid()
);

-- RLS POLICIES: CASES TABLE
create policy "insert_cases_authenticated" on public.cases for insert using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated' and created_by = auth.uid());

create policy "select_cases_staff" on public.cases for select using (
  exists (
    select 1 from public.users u where u.id = auth.uid() and u.active = true and (
      u.role = 'admin' OR (
        u.role = 'encoder' AND (
          u.covered_barangay IS NULL OR barangay = any(u.covered_barangay)
        )
      )
    )
  )
);

create policy "update_cases_admin_or_assigned" on public.cases for update using (
  (select role from public.users where id = auth.uid()) = 'admin' OR assigned_worker_id = auth.uid() OR created_by = auth.uid()
) with check (
  (select role from public.users where id = auth.uid()) = 'admin' OR assigned_worker_id = auth.uid() OR created_by = auth.uid()
);

-- RLS POLICIES: RESTRICTED_IDENTITY TABLE
create policy "select_restricted_identity_if_can_see_case" on public.restricted_identity for select using (
  exists (
    select 1 from public.cases c join public.users u on u.id = auth.uid() where c.id = case_id and (
      u.role = 'admin' OR (u.role = 'encoder' AND (u.covered_barangay IS NULL OR c.barangay = any(u.covered_barangay)))
    )
  )
);

create policy "insert_restricted_identity_staff" on public.restricted_identity for insert using (
  exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
) with check (
  exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
);

-- RLS POLICIES: HEALTH_ALERTS TABLE
create policy "insert_health_alerts_anon" on public.health_alerts for insert using (true) with check (true);

create policy "select_health_alerts_staff" on public.health_alerts for select using (
  exists (select 1 from public.users u where u.id = auth.uid() and (u.role = 'admin' OR u.role = 'encoder'))
);

-- RLS POLICIES: RESPONSE_ACTIVITIES TABLE
create policy "insert_response_activities_staff" on public.response_activities for insert using (
  exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
) with check (
  exists (select 1 from public.users u where u.id = auth.uid() and u.active = true)
);

create policy "select_response_activities_staff" on public.response_activities for select using (
  exists (select 1 from public.users u where u.id = auth.uid() and (u.role = 'admin' OR u.role = 'encoder'))
);

-- RLS POLICIES: SETTINGS TABLE (admin-only)
create policy "select_settings_admin" on public.settings for select using (
  (select role from public.users where id = auth.uid()) = 'admin'
);

create policy "insert_settings_admin" on public.settings for insert using (
  (select role from public.users where id = auth.uid()) = 'admin'
) with check (
  (select role from public.users where id = auth.uid()) = 'admin'
);

create policy "update_settings_admin" on public.settings for update using (
  (select role from public.users where id = auth.uid()) = 'admin'
) with check (
  (select role from public.users where id = auth.uid()) = 'admin'
);

-- RLS POLICIES: AUDIT_LOG TABLE (admin-only, read-only)
create policy "select_audit_log_admin" on public.audit_log for select using (
  (select role from public.users where id = auth.uid()) = 'admin'
);

-- PUBLIC SUMMARY VIEW (aggregated, safe for public display)
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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END: COPY AND PASTE COMPLETE SQL BLOCK ABOVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2.4) If the query completes without errors, you'll see a green checkmark and "Success" message.
   If there are errors, check the error message and fix any syntax issues.

═══════════════════════════════════════════════════════════════════════════════
PART 3: SEED SAMPLE DATA (Optional, for testing)
═══════════════════════════════════════════════════════════════════════════════

3.1) Click "+ New Query" again in SQL Editor.

3.2) Copy and paste the SQL block below. Then click "Run".

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BEGIN: SAMPLE DATA SQL BLOCK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Insert settings
insert into public.settings (key, value) values
('rhu_contact', '{"phone": "+63 (0)912 345-6789", "hours": "Mon-Fri 8:00-17:00", "emergency": "+63 911 999-9999"}'),
('privacy', '{"small_count_threshold": 5, "public_grid_size_m": 200}'),
('outbreak_thresholds', '{"weekly_increase_pct": 100, "min_cases": 5}')
on conflict (key) do nothing;

-- Sample cases (fictional data for testing)
-- Note: You'll need to replace these UUIDs with actual user IDs from Auth after creating staff users
insert into public.cases (
  classification, report_date, symptom_onset_date, status, 
  age_band, sex, barangay, purok, latitude, longitude, 
  lab_result, is_submitted, created_by
) values
('suspected', now() - interval '3 days', now() - interval '5 days', 'pending', '20-29', 'female', 'Barangay 1', 'Purok 1', 11.1501, 125.2301, 'pending', true, null),
('probable', now() - interval '10 days', now() - interval '12 days', 'investigating', '10-14', 'male', 'Barangay 2', 'Purok 3', 11.1552, 125.2352, 'positive', true, null),
('confirmed', now() - interval '20 days', now() - interval '22 days', 'closed', '30-39', 'female', 'Barangay 4', 'Purok 2', 11.1603, 125.2403, 'positive', true, null),
('suspected', now() - interval '1 day', now() - interval '2 days', 'pending', '15-19', 'male', 'Barangay 1', 'Purok 2', 11.1505, 125.2305, 'pending', true, null);

-- Sample health alerts (anonymous resident submissions)
insert into public.health_alerts (barangay, preferred_contact, contact_value, symptoms, onset_date, note, urgency) values
('Barangay 1', 'sms', '+63 912 345-0001', array['fever','headache'], now() - interval '1 day', 'Has been febrile for 2 days', 'low'),
('Barangay 3', 'phone', '+63 912 345-0002', array['fever','vomiting'], now() - interval '2 days', 'Seeking advice on symptoms', 'medium');

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END: SAMPLE DATA SQL BLOCK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

═══════════════════════════════════════════════════════════════════════════════
PART 4: CREATE AUTH USERS (STAFF)
═══════════════════════════════════════════════════════════════════════════════

4.1) Go to Authentication → Users (left sidebar in Supabase).

4.2) Click "Invite user" or "Add user".

4.3) Enter an email (use a test email like admin@example.com) and a password.
   Click "Send invite" (or auto-confirm, depending on settings).

4.4) The user is created. Click on the user row to see their UUID (User ID).
   Copy this UUID — you'll need it in the next step.

4.5) Repeat for more staff users (encoders). Example:
   - admin@example.com (role: admin)
   - encoder1@example.com (role: encoder, covers Barangay 1 & 2)
   - encoder2@example.com (role: encoder, covers Barangay 3 & 4)

═══════════════════════════════════════════════════════════════════════════════
PART 5: ADD STAFF TO public.users TABLE
═══════════════════════════════════════════════════════════════════════════════

5.1) For each Auth user you created, insert a matching row in public.users.
   Go back to SQL Editor, click "+ New Query", and paste:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BEGIN: INSERT STAFF SQL (example)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

insert into public.users (id, email, name, role, covered_barangay, active) values
('PUT-ADMIN-UUID-HERE', 'admin@example.com', 'Admin User', 'admin', null, true),
('PUT-ENCODER1-UUID-HERE', 'encoder1@example.com', 'Encoder 1', 'encoder', array['Barangay 1','Barangay 2'], true),
('PUT-ENCODER2-UUID-HERE', 'encoder2@example.com', 'Encoder 2', 'encoder', array['Barangay 3','Barangay 4'], true);

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END: INSERT STAFF SQL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

5.2) Replace PUT-ADMIN-UUID-HERE, PUT-ENCODER1-UUID-HERE, etc. with the actual UUIDs from step 4.4.

5.3) Click "Run".

═══════════════════════════════════════════════════════════════════════════════
PART 6: CONFIGURE THE FLUTTER APP
═══════════════════════════════════════════════════════════════════════════════

6.1) In your project folder (salcedo_dengue_watch), navigate to lib/config/.

6.2) Copy supabase_config.dart.template to supabase_config.dart:

   On Windows (PowerShell):
   copy lib\config\supabase_config.dart.template lib\config\supabase_config.dart

   On Mac/Linux:
   cp lib/config/supabase_config.dart.template lib/config/supabase_config.dart

6.3) Open lib/config/supabase_config.dart in a text editor.

6.4) Fill in the Project URL and anon key from Part 1.5:

   const String supabaseUrl = 'https://xxxxx.supabase.co';
   const String supabaseAnonKey = 'eyJhbGc...';

6.5) Save the file. DO NOT commit this file to git if using version control (add to .gitignore).

═══════════════════════════════════════════════════════════════════════════════
PART 7: FETCH DEPENDENCIES & RUN THE APP
═══════════════════════════════════════════════════════════════════════════════

7.1) Open a terminal/command prompt in the salcedo_dengue_watch folder.

7.2) Fetch Flutter dependencies:

   flutter pub get

7.3) Run the app (web version first for easy testing):

   flutter run -d edge

   Or for Android emulator/device:

   flutter run

7.4) The app launches. Test login with a staff user (admin@example.com, password).

7.5) Create a case and verify it saves to Supabase:
   - Open Supabase console → Table Editor → cases
   - You should see the new case row appear (in real-time or after refresh)

═══════════════════════════════════════════════════════════════════════════════
PART 8: VERIFY PRIVACY & ACCESS CONTROL
═══════════════════════════════════════════════════════════════════════════════

8.1) Test as Public User (no login):
   - Open app, go to Activity Map → verify you can see aggregated summary only
   - No staff-only fields (exact coordinates, names, etc.) appear

8.2) Test as Encoder1 (covers Barangay 1 & 2):
   - Sign in with encoder1@example.com
   - Create/view cases only in Barangay 1 or 2
   - Try to access a Barangay 4 case (should fail or show no data due to RLS)

8.3) Test as Admin:
   - Sign in with admin@example.com
   - View all cases regardless of barangay
   - Access admin settings

8.4) Verify Restricted Identity:
   - In Supabase SQL Editor, query:
     select * from public.restricted_identity;
   - Only staff can see results; public/anon cannot

═══════════════════════════════════════════════════════════════════════════════
PART 9: CHECKLIST BEFORE GOING LIVE
═══════════════════════════════════════════════════════════════════════════════

- [ ] Project created and initialized
- [ ] All migrations applied (tables, triggers, RLS policies)
- [ ] Sample data seeded
- [ ] Staff auth users created in Auth
- [ ] Staff rows inserted in public.users
- [ ] App config updated with Project URL and anon key
- [ ] App fetches dependencies and runs
- [ ] Public view shows aggregated data only (no names/coordinates)
- [ ] Encoder access restricted by barangay (RLS verified)
- [ ] Admin can view all data
- [ ] Audit log records changes
- [ ] Dates/locations required when submitting cases
- [ ] Privacy notice shown to residents before health alert submission

═══════════════════════════════════════════════════════════════════════════════
NEXT STEPS
═══════════════════════════════════════════════════════════════════════════════

1. Complete Part 1-7 above.
2. Test the app flows described in Part 8.
3. Once verified, export your supabase_config.dart separately (not in git).
4. Share the app for beta testing with RHU staff.
5. Collect feedback and adjust privacy settings/UI as needed.

If you encounter issues:
- Check Supabase logs: Settings → Logs
- Verify RLS policies: Table Editor → Policies
- Test queries in SQL Editor before running in app
- Ensure all user UUIDs match between Auth and public.users

Questions? Refer to Supabase docs: https://supabase.com/docs
