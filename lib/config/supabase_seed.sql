-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Seed non-identifying sample data for testing (fictional)
-- Run after applying schema migrations.

insert into public.settings (key, value) values
('rhu_contact', '{"phone": "+63-000-000-0000", "hours": "Mon-Fri 8:00-17:00"}'),
('privacy', '{"small_count_threshold": 5, "public_grid_size_m": 200}');

-- Create sample users (admin and encoder) - DO NOT use real emails
insert into public.users (id, email, role, covered_barangay, active)
values
  (gen_random_uuid(), 'admin@example.com', 'admin', null, true),
  (gen_random_uuid(), 'encoder1@example.com', 'encoder', array['Barangay 1','Barangay 2'], true);

-- Sample cases (public-safe fields only)
insert into public.cases (classification, report_date, symptom_onset_date, status, age_band, sex, barangay, purok, latitude, longitude, lab_result, is_submitted)
values
  ('suspected', now() - interval '3 days', now() - interval '5 days', 'pending', '20-29', 'female', 'Barangay 1', 'Purok 1', 11.1501, 125.2301, 'pending', true),
  ('probable', now() - interval '10 days', now() - interval '12 days', 'investigating', '10-14', 'male', 'Barangay 2', 'Purok 3', 11.1552, 125.2352, 'positive', true),
  ('confirmed', now() - interval '20 days', now() - interval '22 days', 'closed', '30-39', 'female', 'Barangay 4', 'Purok 2', 11.1603, 125.2403, 'positive', true);

-- Example health alerts
insert into public.health_alerts (barangay, preferred_contact, symptoms, onset_date, note, urgency)
values
  ('Barangay 1', 'sms', array['fever','headache'], now() - interval '1 day', 'Has been febrile for 2 days', 'low'),
  ('Barangay 3', 'phone', array['fever','vomiting'], now() - interval '2 days', 'Seeking advice', 'medium');
