-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Fix: Add missing RLS policy for encoders to read cases
-- This policy allows encoders to read cases they created or are assigned to
-- Run this in your Supabase SQL Editor

-- Drop existing encoder policies to avoid conflicts
drop policy if exists "encoder_create_cases" on public.cases;
drop policy if exists "encoder_update_cases" on public.cases;

-- Updated policy: Encoders can create cases
create policy "encoder_create_cases" on public.cases
  for insert with check (
    public.has_role(auth.uid(), 'admin') or
    public.has_role(auth.uid(), 'encoder') or
    public.has_role(auth.uid(), 'bhw') or
    public.has_role(auth.uid(), 'bsi')
  );

-- NEW POLICY: Encoders can read cases they created or are assigned to
create policy "encoder_read_cases" on public.cases
  for select using (
    public.has_role(auth.uid(), 'admin') or
    public.has_role(auth.uid(), 'rhu_staff') or
    public.has_role(auth.uid(), 'encoder') and (
      created_by = auth.uid() or  -- Cases they created
      assigned_worker_id = auth.uid()  -- Cases assigned to them
    ) or
    public.has_role(auth.uid(), 'bhw') and (
      created_by = auth.uid() or
      assigned_worker_id = auth.uid()
    ) or
    public.has_role(auth.uid(), 'bsi') and (
      created_by = auth.uid() or
      assigned_worker_id = auth.uid()
    )
  );

-- Updated policy: Encoders can update cases they created
create policy "encoder_update_cases" on public.cases
  for update using (
    public.has_role(auth.uid(), 'admin') or
    public.has_role(auth.uid(), 'encoder') and created_by = auth.uid() or
    public.has_role(auth.uid(), 'bhw') and created_by = auth.uid() or
    public.has_role(auth.uid(), 'bsi') and created_by = auth.uid()
  );

-- Additional fix: Ensure RHU staff can read all cases in their RHU's barangays
drop policy if exists "rhu_staff_read_cases" on public.cases;

create policy "rhu_staff_read_cases" on public.cases
  for select using (
    public.has_role(auth.uid(), 'rhu_staff') and (
      -- Can read all cases in their RHU's barangays
      barangay_id in (
        select id from public.barangays
        where rhu_id = (select rhu_id from public.users where id = auth.uid())
      ) or
      -- Fallback: Can read cases they created or are assigned to
      created_by = auth.uid() or
      assigned_worker_id = auth.uid()
    )
  );
