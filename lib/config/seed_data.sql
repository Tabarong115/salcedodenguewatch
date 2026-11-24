-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Salcedo Dengue Watch - Seed Data
-- This script creates fictional sample data for testing
-- DO NOT use this data for real patient records

-- Insert sample users (staff accounts)
-- Note: In production, these would be created through Supabase Auth
INSERT INTO users (email, name, role, barangay_coverage, team, is_active) VALUES
('admin@salcedo.doh.gov.ph', 'Maria Santos', 'admin', ARRAY['Barangay 1', 'Barangay 2', 'Barangay 3', 'Barangay 4', 'Barangay 5'], 'Team A', true),
('encoder1@salcedo.doh.gov.ph', 'Juan Cruz', 'encoder', ARRAY['Barangay 1', 'Barangay 2'], 'Team A', true),
('encoder2@salcedo.doh.gov.ph', 'Ana Reyes', 'encoder', ARRAY['Barangay 3', 'Barangay 4'], 'Team B', true),
('encoder3@salcedo.doh.gov.ph', 'Pedro Mendoza', 'encoder', ARRAY['Barangay 5'], 'Team C', true);

-- Get user IDs for assignments (you'll need to run this separately and replace the UUIDs)
-- For now, we'll use a placeholder approach

-- Insert sample cases (fictional data only)
INSERT INTO cases (classification, report_date, symptom_onset_date, status, age_band, sex, barangay, purok, latitude, longitude, lab_test_type, lab_result, lab_test_date, outcome, outcome_date, is_submitted) VALUES
('suspected', '2026-08-25', '2026-08-23', 'pending', '5-9', 'male', 'Barangay 1', 'Purok 1', 11.2345, 125.1234, 'NS1 Antigen Test', 'pending', NULL, 'ongoing', NULL, true),
('probable', '2026-08-26', '2026-08-24', 'investigation', '20-29', 'female', 'Barangay 2', 'Purok 2', 11.2356, 125.1245, 'PCR Test', 'positive', '2026-08-27', 'recovered', '2026-09-01', true),
('confirmed', '2026-08-27', '2026-08-25', 'closed', '15-19', 'male', 'Barangay 3', 'Purok 3', 11.2367, 125.1256, 'PCR Test', 'positive', '2026-08-28', 'recovered', '2026-09-02', true),
('suspected', '2026-08-28', '2026-08-26', 'pending', '30-39', 'female', 'Barangay 1', 'Purok 4', 11.2378, 125.1267, 'NS1 Antigen Test', 'pending', NULL, 'ongoing', NULL, true),
('probable', '2026-08-29', '2026-08-27', 'investigation', '10-14', 'male', 'Barangay 4', 'Purok 1', 11.2389, 125.1278, 'PCR Test', 'inconclusive', '2026-08-30', 'ongoing', NULL, true),
('confirmed', '2026-08-30', '2026-08-28', 'closed', '40-49', 'female', 'Barangay 2', 'Purok 3', 11.2400, 125.1289, 'PCR Test', 'positive', '2026-08-31', 'recovered', '2026-09-03', true),
('suspected', '2026-08-31', '2026-08-29', 'pending', '0-4', 'male', 'Barangay 5', 'Purok 2', 11.2411, 125.1300, 'NS1 Antigen Test', 'pending', NULL, 'ongoing', NULL, true),
('probable', '2026-09-01', '2026-08-30', 'investigation', '25-34', 'female', 'Barangay 3', 'Purok 5', 11.2422, 125.1311, 'PCR Test', 'pending', NULL, 'ongoing', NULL, true);

-- Insert sample restricted identity (fictional data only)
-- In a real implementation, you would get the case IDs from the previous insert
-- For now, this shows the structure

-- INSERT INTO restricted_identity (case_id, full_name, phone, address, guardian_contact) VALUES
-- (case_id_1, 'Sample Patient One', '09171234567', '123 Main St, Barangay 1', 'Maria Santos - 09181234567'),
-- (case_id_2, 'Sample Patient Two', '09182345678', '456 Oak Ave, Barangay 2', 'Juan Cruz - 09192345678');

-- Insert sample health alerts
INSERT INTO health_alerts (barangay, preferred_contact, symptoms, onset_date, note, submitted_at, urgency_flag, follow_up_status, reference_number) VALUES
('Barangay 1', 'phone', ARRAY['Fever', 'Headache', 'Joint/Muscle pain'], '2026-08-25', 'Experiencing fever for 3 days', '2026-08-25T10:30:00', false, 'acknowledged', 'ALT-1725123456789'),
('Barangay 2', 'text', ARRAY['Fever', 'Rash'], '2026-08-26', 'Rash appeared yesterday', '2026-08-26T14:15:00', false, 'new', 'ALT-1726123456789'),
('Barangay 3', 'visit', ARRAY['Fever', 'Nausea/Vomiting', 'Bleeding'], '2026-08-27', 'Some bleeding from gums', '2026-08-27T09:00:00', true, 'contacted', 'ALT-1727123456789'),
('Barangay 4', 'phone', ARRAY['Fever', 'Eye pain'], '2026-08-28', 'Eye pain since yesterday', '2026-08-28T16:45:00', false, 'new', 'ALT-1728123456789'),
('Barangay 5', 'text', ARRAY['Fever', 'Headache'], '2026-08-29', 'Mild fever and headache', '2026-08-29T11:20:00', false, 'acknowledged', 'ALT-1729123456789');

-- Insert sample response activities
INSERT INTO response_activities (activity_type, activity_date, barangay, purok, team, households_covered, area_covered_sqm, findings, notes) VALUES
('search_and_destroy', '2026-08-26T08:00:00', 'Barangay 1', 'Purok 1', 'Team A', 25, 500.0, 'Found 5 breeding sites in drums and containers', 'Residents educated on covering water containers'),
('cleanup_drive', '2026-08-27T07:30:00', 'Barangay 2', 'Purok 2', 'Team A', 30, 750.0, 'General cleanup conducted, no major breeding sites found', 'Community participation was good'),
('inspection', '2026-08-28T09:00:00', 'Barangay 3', 'Purok 3', 'Team B', 20, 400.0, 'Inspected 20 households, found 3 potential breeding sites', 'Follow-up inspection scheduled'),
('larval_source_reduction', '2026-08-29T08:30:00', 'Barangay 4', 'Purok 1', 'Team B', 15, 350.0, 'Removed standing water from several containers', 'Applied larvicide to identified sites'),
('health_education', '2026-08-30T14:00:00', 'Barangay 5', 'Purok 2', 'Team C', 40, NULL, 'Conducted 4S strategy education session', 'Community meeting attended by 40 residents'),
('fogging_spraying', '2026-08-31T05:00:00', 'Barangay 1', 'Purok 1-3', 'Team A', 50, 1000.0, 'Fogging conducted in hotspot area', 'Precautions advised to residents');

-- Update some settings with realistic placeholder values
UPDATE settings SET value = 'Salcedo Rural Health Unit' WHERE key = 'rhu_contact_name';
UPDATE settings SET value = '(055) 123-4567' WHERE key = 'rhu_contact_phone';
UPDATE settings SET value = 'Monday-Friday 8:00 AM - 5:00 PM' WHERE key = 'rhu_contact_hours';
UPDATE settings SET value = 'For emergencies, call 911 or go to the nearest hospital immediately.' WHERE key = 'emergency_text';

-- Note: To use this seed data:
-- 1. First set up your Supabase project
-- 2. Run the database_schema.sql script
-- 3. Run this seed_data.sql script
-- 4. Create actual Supabase Auth users for the staff accounts
-- 5. Update the user IDs in the cases table if needed