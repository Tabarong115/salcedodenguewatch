-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- COMPREHENSIVE RLS POLICY FIX FOR STAFF FEATURES
-- This fixes missing encoder read access and schema inconsistencies
-- Run this in your Supabase SQL Editor after the main migration

-- ============================================
-- HEALTH ALERTS RLS FIXES
-- ============================================

-- Drop existing health alert policies that might conflict
drop policy if exists "admin_read_alerts" on public.health_alerts;
drop policy if exists "rhu_staff_read_alerts" on public.health_alerts;
drop policy if exists "bhw_bsi_read_alerts" on public.health_alerts;
drop policy if exists "public_create_alerts" on public.health_alerts;

-- Admin can read all alerts
create policy "admin_read_alerts" on public.health_alerts
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read alerts in their RHU's barangays
create policy "rhu_staff_read_alerts" on public.health_alerts
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and (
      -- Can read alerts in their RHU's barangays
      barangay_id in (
        select id from public.barangays 
        where rhu_id = (select rhu_id from public.users where id = auth.uid())
      ) or
      -- Fallback: Can read alerts they're assigned to
      assigned_worker_id = auth.uid()
    )
  );

-- NEW: Encoders can read alerts in their barangay or assigned to them
create policy "encoder_read_alerts" on public.health_alerts
  for select using (
    public.has_role(auth.uid(), 'encoder') and (
      barangay_id = (select barangay_id from public.users where id = auth.uid()) or
      assigned_worker_id = auth.uid()
    )
  );

-- BHW/BSI can read alerts in their barangay or assigned to them
create policy "bhw_bsi_read_alerts" on public.health_alerts
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and (
      barangay_id = (select barangay_id from public.users where id = auth.uid()) or
      assigned_worker_id = auth.uid()
    )
  );

-- Anyone can create alerts (public residents)
create policy "public_create_alerts" on public.health_alerts
  for insert with check (true);

-- Admin or assigned worker can update alerts
create policy "update_alerts_admin_or_assigned" on public.health_alerts
  for update using (
    public.is_admin(auth.uid()) or
    assigned_worker_id = auth.uid()
  ) with check (
    public.is_admin(auth.uid()) or
    assigned_worker_id = auth.uid()
  );

-- ============================================
-- RESPONSE ACTIVITIES RLS FIXES
-- ============================================

-- First, add barangay_id column if it doesn't exist (for better RLS filtering)
alter table public.response_activities 
  add column if not exists barangay_id uuid references public.barangays(id) on delete set null;

-- Drop existing response activity policies
drop policy if exists "admin_read_activities" on public.response_activities;
drop policy if exists "rhu_staff_read_activities" on public.response_activities;
drop policy if exists "encoder_create_activities" on public.response_activities;

-- Admin can read all activities
create policy "admin_read_activities" on public.response_activities
  for select using (
    public.is_admin(auth.uid())
  );

-- RHU staff can read activities in their RHU's barangays
create policy "rhu_staff_read_activities" on public.response_activities
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and (
      -- Can read activities in their RHU's barangays
      barangay_id in (
        select id from public.barangays 
        where rhu_id = (select rhu_id from public.users where id = auth.uid())
      ) or
      -- Fallback: Can read activities they created
      created_by = auth.uid()
    )
  );

-- NEW: Encoders can read activities they created or in their barangay
create policy "encoder_read_activities" on public.response_activities
  for select using (
    public.has_role(auth.uid(), 'encoder') and (
      barangay_id = (select barangay_id from public.users where id = auth.uid()) or
      created_by = auth.uid()
    )
  );

-- BHW/BSI can read activities they created or in their barangay
create policy "bhw_bsi_read_activities" on public.response_activities
  for select using (
    (public.has_role(auth.uid(), 'bhw') or public.has_role(auth.uid(), 'bsi')) and (
      barangay_id = (select barangay_id from public.users where id = auth.uid()) or
      created_by = auth.uid()
    )
  );

-- Staff can create activities
create policy "encoder_create_activities" on public.response_activities
  for insert with check (
    public.has_role(auth.uid(), 'admin') or 
    public.has_role(auth.uid(), 'encoder') or 
    public.has_role(auth.uid(), 'bhw') or 
    public.has_role(auth.uid(), 'bsi') or
    public.has_role(auth.uid(), 'rhu_staff')
  );

-- Admin or creator can update activities
create policy "update_activities_admin_or_creator" on public.response_activities
  for update using (
    public.is_admin(auth.uid()) or
    created_by = auth.uid()
  ) with check (
    public.is_admin(auth.uid()) or
    created_by = auth.uid()
  );

-- ============================================
-- CONSISTENCY CHECKS AND FIXES
-- ============================================

-- Function to update barangay_id from barangay name for existing records
create or replace function public.sync_barangay_ids()
returns void as $$
begin
  -- Update health alerts barangay_id based on barangay name
  update public.health_alerts ha
  set barangay_id = (
    select id from public.barangays b 
    where b.name = ha.barangay 
    limit 1
  )
  where ha.barangay_id is null and ha.barangay is not null;

  -- Update response activities barangay_id based on barangay name
  update public.response_activities ra
  set barangay_id = (
    select id from public.barangays b 
    where b.name = ra.barangay 
    limit 1
  )
  where ra.barangay_id is null and ra.barangay is not null;
end;
$$ language plpgsql;

-- Run the sync function
select public.sync_barangay_ids();

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if policies are correctly applied
select 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies 
where tablename in ('health_alerts', 'response_activities', 'cases')
order by tablename, policyname;

-- Check if barangay_id column exists in response_activities
select column_name, data_type 
from information_schema.columns 
where table_name = 'response_activities' and column_name = 'barangay_id';
