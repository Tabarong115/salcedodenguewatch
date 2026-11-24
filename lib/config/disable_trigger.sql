-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- DISABLE THE VALIDATION TRIGGER TEMPORARILY
-- This will allow manual user creation in Supabase
-- ============================================

-- Drop the trigger that's blocking user creation
DROP TRIGGER IF EXISTS validate_user_requirements_trigger ON public.users;

-- Verify the trigger is gone
SELECT 
    trigger_name, 
    action_statement, 
    event_manipulation
FROM information_schema.triggers 
WHERE trigger_name = 'validate_user_requirements_trigger';