-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Migration to add location coordinates to RHU and Facilities tables
-- This enables map focusing when these locations are selected
-- Run this in Supabase SQL Editor

-- ============================================
-- ADD LOCATION COLUMNS TO RHU TABLE
-- ============================================

-- Add latitude column to RHU table
ALTER TABLE public.rhu 
ADD COLUMN IF NOT EXISTS latitude double precision;

-- Add longitude column to RHU table  
ALTER TABLE public.rhu 
ADD COLUMN IF NOT EXISTS longitude double precision;

-- ============================================
-- ADD LOCATION COLUMNS TO FACILITIES TABLE
-- ============================================

-- Add latitude column to facilities table
ALTER TABLE public.facilities 
ADD COLUMN IF NOT EXISTS latitude double precision;

-- Add longitude column to facilities table
ALTER TABLE public.facilities 
ADD COLUMN IF NOT EXISTS longitude double precision;

-- ============================================
-- UPDATE EXISTING RECORDS WITH DEFAULT COORDINATES
-- ============================================

-- Note: These are placeholder coordinates for Salcedo, Eastern Samar
-- In production, admins should update these with actual coordinates
-- using the admin interface with the map picker

-- Update existing RHU records with Salcedo coordinates
UPDATE public.rhu
SET latitude = 11.14922, longitude = 125.66287
WHERE latitude IS NULL AND longitude IS NULL;

-- Update existing facility records with Salcedo coordinates
UPDATE public.facilities
SET latitude = 11.14922, longitude = 125.66287
WHERE latitude IS NULL AND longitude IS NULL;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check RHU table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'rhu' 
AND table_schema = 'public'
AND column_name IN ('latitude', 'longitude');

-- Check facilities table structure  
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'facilities' 
AND table_schema = 'public'
AND column_name IN ('latitude', 'longitude');

-- Verify the columns were added successfully
SELECT 'RHU columns added successfully' as status
WHERE EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'rhu' AND column_name = 'latitude'
);

SELECT 'Facilities columns added successfully' as status  
WHERE EXISTS (
  SELECT 1 FROM information_schema.columns 
  WHERE table_name = 'facilities' AND column_name = 'latitude'
);
