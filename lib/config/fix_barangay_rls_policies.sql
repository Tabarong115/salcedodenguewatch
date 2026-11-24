-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Fix barangay RLS policies to allow encoder, public, and other staff roles to read barangays
-- This script should be run on an existing database that already has the barangays table
-- DO NOT run this on a fresh database that has not been migrated yet

-- Drop existing restrictive policies
drop policy if exists "rhu_staff_read_barangays" on public.barangays;
drop policy if exists "bhw_bsi_read_barangay" on public.barangays;

-- Add public read policy for unauthenticated users (health alerts, public dashboards)
create policy "public_read_barangays" on public.barangays
  for select using (
    true
  );

-- RHU staff can read all barangays in their RHU
create policy "rhu_staff_read_barangays" on public.barangays
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and
    rhu_id = (select rhu_id from public.users where id = auth.uid())
  );

-- Encoder can read all barangays in their RHU
create policy "encoder_read_barangays" on public.barangays
  for select using (
    public.has_role(auth.uid(), 'encoder') and
    rhu_id = (select rhu_id from public.users where id = auth.uid())
  );

-- BHW/BSI can read their assigned barangay
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
