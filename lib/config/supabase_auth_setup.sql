-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- PRODUCTION AUTHENTICATION SETUP
-- ============================================
-- This script sets up Supabase Auth for production use
-- Run this in Supabase SQL Editor after the main migration

-- ============================================
-- STEP 1: ENABLE EMAIL CONFIRMATION
-- ============================================
-- Note: This must be done in Supabase Dashboard > Authentication > Settings
-- Enable "Confirm email" setting
-- Set "Email confirmation delay" to 0 (immediate)

-- ============================================
-- STEP 2: CREATE USER PROFILE SYNC TRIGGER
-- ============================================
-- This trigger automatically creates a user profile in the users table
-- when a new user is created in Supabase Auth

-- Function to handle new user creation
create or replace function public.handle_new_user()
returns trigger as $$
declare
  default_rhu_id uuid;
  default_role text := 'encoder'; -- Default role for new users
begin
  -- Get the first available RHU as default (or null if none exists)
  select id into default_rhu_id from public.rhu limit 1;
  
  -- Check if user already has a profile (avoid duplicate insert)
  if exists (select 1 from public.users where id = new.id) then
    return new;
  end if;
  
  -- Create user profile with default values
  insert into public.users (
    id,
    email,
    name,
    role,
    rhu_id,
    active,
    created_at
  ) values (
    new.id,
    new.email,
    split_part(new.email, '@', 1), -- Use email prefix as default name
    default_role,
    default_rhu_id,
    false, -- Start as inactive until admin approves
    now()
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
-- STEP 3: CREATE USER MANAGEMENT FUNCTIONS
-- ============================================

-- Function to approve/activate a user account
create or replace function public.activate_user_account(user_id uuid)
returns boolean as $$
begin
  update public.users
  set active = true,
      updated_at = now()
  where id = user_id;
  
  return found;
end;
$$ language plpgsql security definer;

-- Function to deactivate a user account
create or replace function public.deactivate_user_account(user_id uuid)
returns boolean as $$
begin
  update public.users
  set active = false,
      updated_at = now()
  where id = user_id;
  
  return found;
end;
$$ language plpgsql security definer;

-- Function to update user role
create or replace function public.update_user_role(user_id uuid, new_role text)
returns boolean as $$
begin
  -- Validate role
  if new_role not in ('admin', 'rhu_staff', 'encoder', 'bhw', 'bsi', 'hospital_staff') then
    raise exception 'Invalid role: %', new_role;
  end if;
  
  update public.users
  set role = new_role,
      updated_at = now()
  where id = user_id;
  
  return found;
end;
$$ language plpgsql security definer;

-- Function to assign user to RHU
create or replace function public.assign_user_to_rhu(user_id uuid, rhu_id uuid)
returns boolean as $$
begin
  update public.users
  set rhu_id = rhu_id,
      updated_at = now()
  where id = user_id;
  
  return found;
end;
$$ language plpgsql security definer;

-- Function to assign user to barangay
create or replace function public.assign_user_to_barangay(user_id uuid, barangay_id uuid)
returns boolean as $$
begin
  update public.users
  set barangay_id = barangay_id,
      updated_at = now()
  where id = user_id;
  
  return found;
end;
$$ language plpgsql security definer;

-- ============================================
-- STEP 4: CREATE ADMIN-ONLY POLICIES FOR USER MANAGEMENT
-- ============================================

-- Allow admins to read all users
create policy "admin_read_all_users" on public.users
  for select using (
    public.is_admin(auth.uid())
  );

-- Allow admins to insert users (for manual user creation)
create policy "admin_insert_users" on public.users
  for insert with check (
    public.is_admin(auth.uid())
  );

-- Allow admins to update users
create policy "admin_update_users" on public.users
  for update using (
    public.is_admin(auth.uid())
  );

-- Allow admins to delete users
create policy "admin_delete_users" on public.users
  for delete using (
    public.is_admin(auth.uid())
  );

-- ============================================
-- STEP 5: CREATE HELPER VIEW FOR USER MANAGEMENT
-- ============================================

-- Create a view that joins auth.users with public.users for admin dashboard
create or replace view public.user_management_view as
select 
  u.id,
  u.email,
  u.email_confirmed_at,
  u.created_at as auth_created_at,
  u.last_sign_in_at,
  p.name,
  p.role,
  p.rhu_id,
  p.facility_id,
  p.barangay_id,
  p.covered_barangay,
  p.team,
  p.active,
  p.created_at as profile_created_at,
  p.updated_at,
  r.name as rhu_name,
  f.name as facility_name,
  b.name as barangay_name
from auth.users u
left join public.users p on u.id = p.id
left join public.rhu r on p.rhu_id = r.id
left join public.facilities f on p.facility_id = f.id
left join public.barangays b on p.barangay_id = b.id;

-- Grant read access to this view for admins
grant select on public.user_management_view to authenticated;
create policy "admin_read_user_management" on public.user_management_view
  for select using (
    public.is_admin(auth.uid())
  );

-- ============================================
-- STEP 6: CREATE INITIAL ADMIN USER (MANUAL PROCESS)
-- ============================================
-- IMPORTANT: This should be done manually by the project owner
-- through Supabase Dashboard, not through this script

-- Instructions for creating the first admin user:
-- 1. Go to Supabase Dashboard > Authentication > Users
-- 2. Click "Add user" > "Create new user"
-- 3. Enter email and password for the admin
-- 4. Make sure "Auto confirm user" is CHECKED for the first admin only
-- 5. After creation, run the following SQL to set up their profile:

-- Replace 'YOUR_ADMIN_UUID' with the actual UUID from the auth.users table
-- update public.users
-- set 
--   name = 'Admin Name',
--   role = 'admin',
--   active = true,
--   rhu_id = (select id from public.rhu limit 1)
-- where id = 'YOUR_ADMIN_UUID';

-- ============================================
-- STEP 7: EMAIL TEMPLATE CONFIGURATION
-- ============================================
-- These should be configured in Supabase Dashboard > Authentication > Email Templates

-- Confirm signup template should include:
-- "Welcome to Salcedo Dengue Watch! Please confirm your email address to activate your account."

-- Reset password template should include:
-- "You requested a password reset for your Salcedo Dengue Watch account."

-- ============================================
-- STEP 8: SECURITY POLICY UPDATES
-- ============================================

-- Update users table policy to ensure users can only see themselves unless admin
drop policy if exists "user_read_self" on public.users;
create policy "user_read_self" on public.users
  for select using (
    auth.uid() = id or public.is_admin(auth.uid())
  );

-- Update users table policy to ensure users can only update themselves unless admin
drop policy if exists "user_update_self" on public.users;
create policy "user_update_self" on public.users
  for update using (
    auth.uid() = id or public.is_admin(auth.uid())
  );

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if trigger is working:
-- select * from information_schema.triggers 
-- where event_object_table = 'users';

-- Check user management view:
-- select * from public.user_management_view limit 5;

-- Check active users:
-- select * from public.users where active = true;

-- Check unconfirmed email users:
-- select * from auth.users where email_confirmed_at is null;