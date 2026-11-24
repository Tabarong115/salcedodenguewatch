-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- DATABASE DIAGNOSTIC SCRIPT
-- Run this to check current database state
-- ============================================

-- Check users table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if roles table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'roles'
);

-- Check roles table structure if it exists
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'roles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check existing users
SELECT id, email, name, role, role_id, active, created_at 
FROM public.users 
LIMIT 5;

-- Check existing roles
SELECT * FROM public.roles;

-- Check for triggers on users table
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table, 
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'users';

-- Check for constraints on users table
SELECT 
    constraint_name, 
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'users' AND table_schema = 'public';

-- Check foreign key constraints specifically
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'users' AND tc.table_schema = 'public'
    AND tc.constraint_type = 'FOREIGN KEY';

-- Check if the validation trigger exists
SELECT 
    trigger_name, 
    action_statement, 
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name = 'validate_user_requirements_trigger';