-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- REVERT DATABASE CHANGES TO SIMPLE WORKING STATE
-- ============================================

-- Drop the problematic roles table
DROP TABLE IF EXISTS public.roles CASCADE;

-- Remove the role_id column from users table
ALTER TABLE public.users DROP COLUMN IF EXISTS role_id;

-- Re-enable RLS on users table (restore original state)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop the user management view
DROP VIEW IF EXISTS public.user_management_view;

-- Re-enable the original constraint check for role text
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('admin', 'rhu_staff', 'hospital_staff', 'encoder', 'bhw', 'bsi'));

-- Verify the users table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;