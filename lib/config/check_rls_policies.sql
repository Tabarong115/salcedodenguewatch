-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- CHECK RLS POLICIES THAT MIGHT BLOCK USER CREATION
-- ============================================

-- Check RLS policies on users table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'users';

-- Check RLS status on users table
SELECT 
    relname as table_name,
    relrowsecurity as rls_enabled
FROM pg_class 
WHERE relname = 'users' AND relnamespace = 'public'::regnamespace;

-- Temporarily disable RLS on users table to test if this is the issue
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT 
    relname as table_name,
    relrowsecurity as rls_enabled
FROM pg_class 
WHERE relname = 'users' AND relnamespace = 'public'::regnamespace;