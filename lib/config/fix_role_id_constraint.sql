-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- FIX ROLE_ID CONSTRAINT TO ALLOW USER CREATION
-- ============================================

-- Make role_id nullable temporarily to allow user creation
ALTER TABLE public.users 
ALTER COLUMN role_id DROP NOT NULL;

-- Verify the change
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public' AND column_name = 'role_id';