-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- ============================================
-- IMPROVE USERS TABLE STRUCTURE
-- ============================================

-- Step 1: Create a role enum type if it doesn't exist
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'rhu_staff', 'hospital_staff', 'encoder', 'bhw', 'bsi');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Step 2: Add a check constraint for valid roles
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('admin', 'rhu_staff', 'hospital_staff', 'encoder', 'bhw', 'bsi'));

-- Step 3: Add check constraints for foreign keys based on role
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_role_rhu_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_role_rhu_check 
CHECK (
    (role = 'admin') OR 
    (rhu_id IS NOT NULL)
);

-- Step 4: Add check constraint for facility_id (only required for hospital_staff)
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_role_facility_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_role_facility_check 
CHECK (
    (role != 'hospital_staff') OR 
    (facility_id IS NOT NULL)
);

-- Step 5: Add check constraint for barangay_id (only required for encoder, bhw, bsi)
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_role_barangay_check;

ALTER TABLE public.users 
ADD CONSTRAINT users_role_barangay_check 
CHECK (
    (role NOT IN ('encoder', 'bhw', 'bsi')) OR 
    (barangay_id IS NOT NULL)
);

-- Step 6: Set a default role if needed
ALTER TABLE public.users 
ALTER COLUMN role SET DEFAULT 'encoder';

-- Step 7: Add helpful comments
COMMENT ON COLUMN public.users.role IS 'User role: admin, rhu_staff, hospital_staff, encoder, bhw, bsi';
COMMENT ON COLUMN public.users.rhu_id IS 'Required for all roles except admin';
COMMENT ON COLUMN public.users.facility_id IS 'Required only for hospital_staff role';
COMMENT ON COLUMN public.users.barangay_id IS 'Required only for encoder, bhw, bsi roles';
COMMENT ON COLUMN public.users.active IS 'User account status (true = active, false = inactive)';

-- Step 8: Create a view for easier user management
CREATE OR REPLACE VIEW public.user_management_view AS
SELECT 
    u.id,
    u.email,
    u.name,
    u.role,
    u.active,
    u.created_at,
    u.updated_at,
    r.name as rhu_name,
    f.name as facility_name,
    b.name as barangay_name
FROM public.users u
LEFT JOIN public.rhu r ON u.rhu_id = r.id
LEFT JOIN public.facilities f ON u.facility_id = f.id  
LEFT JOIN public.barangays b ON u.barangay_id = b.id
ORDER BY u.created_at DESC;

-- Step 9: Create a function to validate user data based on role
CREATE OR REPLACE FUNCTION public.validate_user_role_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate RHU assignment
    IF NEW.role != 'admin' AND NEW.rhu_id IS NULL THEN
        RAISE EXCEPTION 'RHU assignment is required for role: %', NEW.role;
    END IF;
    
    -- Validate facility assignment for hospital staff
    IF NEW.role = 'hospital_staff' AND NEW.facility_id IS NULL THEN
        RAISE EXCEPTION 'Facility assignment is required for hospital_staff role';
    END IF;
    
    -- Validate barangay assignment for encoder, bhw, bsi
    IF NEW.role IN ('encoder', 'bhw', 'bsi') AND NEW.barangay_id IS NULL THEN
        RAISE EXCEPTION 'Barangay assignment is required for role: %', NEW.role;
    END IF;
    
    -- Clear unnecessary foreign keys for admin
    IF NEW.role = 'admin' THEN
        NEW.rhu_id := NULL;
        NEW.facility_id := NULL;
        NEW.barangay_id := NULL;
    END IF;
    
    -- Clear unnecessary foreign keys for non-hospital staff
    IF NEW.role != 'hospital_staff' THEN
        NEW.facility_id := NULL;
    END IF;
    
    -- Clear unnecessary foreign keys for non-barangay roles
    IF NEW.role NOT IN ('encoder', 'bhw', 'bsi') THEN
        NEW.barangay_id := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 10: Create trigger for automatic validation
DROP TRIGGER IF EXISTS validate_user_data_trigger ON public.users;
CREATE TRIGGER validate_user_data_trigger
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_user_role_data();

-- Step 11: Update existing users to fix any data inconsistencies
UPDATE public.users 
SET 
    rhu_id = NULL,
    facility_id = NULL, 
    barangay_id = NULL
WHERE role = 'admin';

UPDATE public.users 
SET facility_id = NULL 
WHERE role != 'hospital_staff';

UPDATE public.users 
SET barangay_id = NULL 
WHERE role NOT IN ('encoder', 'bhw', 'bsi');