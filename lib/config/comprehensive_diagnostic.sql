-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- COMPREHENSIVE DATABASE DIAGNOSTIC
-- Check all potential blockers for user creation
-- ============================================

-- Check all triggers on users table
SELECT 
    tgname as trigger_name, 
    tgenabled as enabled,
    tgtype as trigger_type,
    tgrelid::regclass as table_name
FROM pg_trigger 
WHERE tgrelid::regclass IN ('users', 'auth.users');

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

-- Check all constraints on users table
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    kcu.column_name
FROM information_schema.table_constraints AS tc
LEFT JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'users' AND tc.table_schema = 'public';

-- Check for any functions that might be interfering
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_name LIKE '%user%';

-- Check current users table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Try to create a test user to see the exact error
DO $$
BEGIN
    -- This will show us the exact error if user creation fails
    PERFORM auth.jwt_secret();
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Auth error: %', SQLERRM;
END $$;