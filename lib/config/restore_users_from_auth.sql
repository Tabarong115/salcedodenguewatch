-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- EMERGENCY RECOVERY SCRIPT: Restore users from Supabase Auth
-- This recreates the users table from your existing authentication data
-- Run this in Supabase SQL Editor immediately

-- ============================================
-- RECREATE USERS TABLE (if it was dropped)
-- ============================================

create table if not exists public.users (
  id uuid primary key,
  email text unique not null,
  name text not null,
  role text not null default 'encoder',
  rhu_id uuid references public.rhu(id) on delete set null,
  facility_id uuid references public.facilities(id) on delete set null,
  barangay_id uuid references public.barangays(id) on delete set null,
  covered_barangay text[],
  team text[],
  active boolean default true,
  created_by uuid references public.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- RECREATE USERS FROM AUTH DATA
-- ============================================

-- This script recreates users from your existing Supabase Auth users
-- You'll need to manually set the roles and assignments after this

-- Insert all auth users as users (they will have encoder role by default)
-- You can update their roles and assignments later through the admin interface

-- Create a function to sync auth users to public.users table
create or replace function public.sync_auth_users()
returns void as $$
declare
  auth_user record;
begin
  -- Loop through all auth users and create corresponding public.users records
  for auth_user in 
    select id, email, raw_user_meta_data->>'full_name' as full_name
    from auth.users
  loop
    insert into public.users (id, email, name, role, active)
    values (
      auth_user.id,
      auth_user.email,
      COALESCE(auth_user.full_name, split_part(auth_user.email, '@', 1)),
      'encoder',  -- Default role, update as needed
      true        -- Default active status
    )
    on conflict (id) do nothing;
  end loop;
end;
$$ language plpgsql security definer;

-- Run the sync function
select public.sync_auth_users();

-- ============================================
-- ENABLE RLS POLICIES ON USERS TABLE
-- ============================================

alter table public.users enable row level security;

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

-- Allow public to read users (this will be filtered at app level)
create policy "public_read_users" on public.users
for select using (true);

-- ============================================
-- VERIFICATION
-- ============================================

-- Check if users were restored
SELECT 'Users restored successfully' as status, COUNT(*) as user_count
FROM public.users;

-- Show all restored users
SELECT id, email, name, role, active, created_at
FROM public.users
ORDER BY created_at;

-- ============================================
-- NEXT STEPS FOR YOU
-- ============================================

-- 1. Check the results above to verify your users were restored
-- 2. Login to the app with your first admin account
-- 3. Go to Admin Settings > Users 
-- 4. Update your first admin user to have 'admin' role
-- 5. Update other users with their correct roles and assignments
-- 6. Delete the sync function after recovery: DROP FUNCTION public.sync_auth_users();
