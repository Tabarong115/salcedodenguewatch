-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- CREATE ROLES TABLE WITH FOREIGN KEY RELATIONSHIPS
-- ============================================

-- Step 1: Create the roles table
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    requires_rhu BOOLEAN DEFAULT true,
    requires_facility BOOLEAN DEFAULT false,
    requires_barangay BOOLEAN DEFAULT false,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Insert the standard roles
INSERT INTO public.roles (name, display_name, description, requires_rhu, requires_facility, requires_barangay, is_admin) VALUES
('admin', 'Administrator', 'Full system access with no restrictions', false, false, false, true),
('rhu_staff', 'RHU Staff', 'RHU-level staff with access to assigned RHU data', true, false, false, false),
('hospital_staff', 'Hospital/Clinic Staff', 'Medical staff at hospitals and clinics', true, true, false, false),
('encoder', 'Encoder', 'Data encoder assigned to specific barangay', true, false, true, false),
('bhw', 'Barangay Health Worker', 'Health worker assigned to specific barangay', true, false, true, false),
('bsi', 'Barangay Surveillance Information Officer', 'Surveillance officer assigned to specific barangay', true, false, true, false)
ON CONFLICT (name) DO NOTHING;

-- Step 3: Add the role_id column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS role_id UUID REFERENCES public.roles(id);

-- Step 4: Migrate existing role data to role_id
UPDATE public.users u
SET role_id = r.id
FROM public.roles r
WHERE u.role = r.name AND u.role_id IS NULL;

-- Step 5: Make role_id NOT NULL after migration (if migration was successful)
-- First check if all users have role_id
DO $$
DECLARE
    users_without_role INTEGER;
BEGIN
    SELECT COUNT(*) INTO users_without_role 
    FROM public.users 
    WHERE role_id IS NULL;
    
    IF users_without_role = 0 THEN
        ALTER TABLE public.users 
        ALTER COLUMN role_id SET NOT NULL;
        RAISE NOTICE 'All users have role_id, column set to NOT NULL';
    ELSE
        RAISE NOTICE 'Some users still lack role_id, column remains nullable';
    END IF;
END $$;

-- Step 6: Add helpful comments
COMMENT ON TABLE public.roles IS 'Defines user roles and their requirements';
COMMENT ON COLUMN public.roles.name IS 'Internal role identifier (admin, rhu_staff, etc.)';
COMMENT ON COLUMN public.roles.display_name IS 'Human-readable role name for UI';
COMMENT ON COLUMN public.roles.requires_rhu IS 'Whether this role requires RHU assignment';
COMMENT ON COLUMN public.roles.requires_facility IS 'Whether this role requires facility assignment';
COMMENT ON COLUMN public.roles.requires_barangay IS 'Whether this role requires barangay assignment';
COMMENT ON COLUMN public.roles.is_admin IS 'Whether this role has admin privileges';
COMMENT ON COLUMN public.users.role_id IS 'Foreign key to roles table - now creates dropdown in Supabase UI';

-- Step 7: Drop existing view if it exists and create new view
DROP VIEW IF EXISTS public.user_management_view;

CREATE VIEW public.user_management_view AS
SELECT 
    u.id,
    u.email,
    u.name,
    r.display_name as role_name,
    r.name as role_key,
    u.active,
    u.created_at,
    u.updated_at,
    u.rhu_id,
    rh.name as rhu_name,
    u.facility_id,
    f.name as facility_name,
    u.barangay_id,
    b.name as barangay_name
FROM public.users u
LEFT JOIN public.roles r ON u.role_id = r.id
LEFT JOIN public.rhu rh ON u.rhu_id = rh.id
LEFT JOIN public.facilities f ON u.facility_id = f.id  
LEFT JOIN public.barangays b ON u.barangay_id = b.id
ORDER BY u.created_at DESC;

-- Step 8: Create a function to validate user data based on role requirements
CREATE OR REPLACE FUNCTION public.validate_user_role_requirements()
RETURNS TRIGGER AS $$
DECLARE
    role_requirements RECORD;
BEGIN
    -- Get role requirements
    SELECT * INTO role_requirements 
    FROM public.roles 
    WHERE id = NEW.role_id;
    
    -- If no role requirements found, allow the operation
    IF NOT FOUND THEN
        RETURN NEW;
    END IF;
    
    -- Validate RHU requirement
    IF role_requirements.requires_rhu AND NEW.rhu_id IS NULL THEN
        RAISE EXCEPTION 'RHU assignment is required for role: %', role_requirements.display_name;
    END IF;
    
    -- Validate facility requirement
    IF role_requirements.requires_facility AND NEW.facility_id IS NULL THEN
        RAISE EXCEPTION 'Facility assignment is required for role: %', role_requirements.display_name;
    END IF;
    
    -- Validate barangay requirement
    IF role_requirements.requires_barangay AND NEW.barangay_id IS NULL THEN
        RAISE EXCEPTION 'Barangay assignment is required for role: %', role_requirements.display_name;
    END IF;
    
    -- Clean up unnecessary foreign keys
    IF NOT role_requirements.requires_rhu THEN
        NEW.rhu_id := NULL;
    END IF;
    
    IF NOT role_requirements.requires_facility THEN
        NEW.facility_id := NULL;
    END IF;
    
    IF NOT role_requirements.requires_barangay THEN
        NEW.barangay_id := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 9: Create trigger for automatic validation
DROP TRIGGER IF EXISTS validate_user_requirements_trigger ON public.users;
CREATE TRIGGER validate_user_requirements_trigger
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_user_role_requirements();

-- Step 10: Enable RLS on roles table
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Create policy for roles (read-only for authenticated users)
CREATE POLICY "Authenticated users can view roles" 
ON public.roles FOR SELECT 
USING (auth.role() = 'authenticated');

-- Admin can manage roles
CREATE POLICY "Admins can manage roles" 
ON public.roles FOR ALL 
USING (auth.jwt() ->> 'role' = 'admin');

-- Step 11: Update existing users to fix any data inconsistencies based on new role requirements
UPDATE public.users
SET 
    rhu_id = NULL,
    facility_id = NULL, 
    barangay_id = NULL
WHERE role_id IN (SELECT id FROM public.roles WHERE requires_rhu = false);

UPDATE public.users
SET facility_id = NULL 
WHERE role_id IN (SELECT id FROM public.roles WHERE requires_facility = false);

UPDATE public.users
SET barangay_id = NULL 
WHERE role_id IN (SELECT id FROM public.roles WHERE requires_barangay = false);