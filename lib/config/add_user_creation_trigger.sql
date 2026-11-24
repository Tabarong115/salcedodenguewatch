-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Migration to add missing user profile creation trigger
-- This fixes the issue where users cannot be added via admin interface
-- Run this in Supabase SQL Editor for existing databases

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
-- VERIFICATION
-- ============================================

-- Check if trigger was created successfully
SELECT 'User creation trigger added successfully' as status
WHERE EXISTS (
  SELECT 1 FROM information_schema.triggers 
  WHERE trigger_name = 'on_auth_user_created'
  AND event_object_table = 'users'
  AND event_object_schema = 'auth'
);

-- Show the trigger details
SELECT trigger_name, event_manipulation, action_timing, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created'
AND event_object_schema = 'auth';

-- ============================================
-- WHAT THIS FIXES
-- ============================================

-- This trigger ensures that when a new user is created in Supabase Auth
-- (either through the admin interface or self-registration),
-- a corresponding profile is automatically created in the public.users table.
-- 
-- Without this trigger, the admin user creation feature will fail because:
-- 1. The auth user is created successfully
-- 2. But no profile is created in public.users
-- 3. The update operation fails because the record doesn't exist
-- 4. The user creation appears to fail even though the auth user exists

-- With this trigger:
-- 1. Auth user is created
-- 2. Trigger automatically creates the public.users profile
-- 3. Admin interface can then update the profile with correct role/assignments
-- 4. User creation works as expected
