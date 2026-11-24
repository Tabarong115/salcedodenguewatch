-- LEGACY: Historical schema/setup script; do not use to bootstrap the new Supabase project.
-- Canonical fresh-project schema: supabase/setup.sql
-- Fresh-project and staff invitation instructions: supabase/README.md

-- Salcedo Dengue Watch - Supabase Database Schema
-- Run this in the Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (stores RHU staff information)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'encoder')),
    barangay_coverage TEXT[], -- Array of barangays this user can access
    team TEXT, -- Team assignment (e.g., "Team A", "Team B")
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cases table (main dengue case records)
CREATE TABLE cases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    classification TEXT NOT NULL CHECK (classification IN ('suspected', 'probable', 'confirmed')),
    report_date DATE NOT NULL,
    symptom_onset_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'investigation', 'closed')),
    age_band TEXT CHECK (age_band IN ('0-4', '5-9', '10-14', '15-19', '20-29', '30-39', '40-49', '50-59', '60+')),
    sex TEXT CHECK (sex IN ('male', 'female')),
    barangay TEXT NOT NULL,
    purok TEXT, -- Grid/sitio/purok for privacy protection
    -- Exact location (staff only)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    location_accuracy DECIMAL(10, 2),
    -- Laboratory information
    lab_test_type TEXT,
    lab_result TEXT CHECK (lab_result IN ('pending', 'positive', 'negative', 'inconclusive')),
    lab_test_date DATE,
    -- Clinical outcome
    outcome TEXT CHECK (outcome IN ('recovered', 'death', 'unknown', 'ongoing')),
    outcome_date DATE,
    -- Assignment
    assigned_worker_id UUID REFERENCES users(id),
    -- Metadata
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_submitted BOOLEAN DEFAULT false, -- Draft vs submitted
    is_duplicate_of UUID REFERENCES cases(id) -- For duplicate tracking
);

-- Restricted identity table (separate from cases for privacy)
CREATE TABLE restricted_identity (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id UUID UNIQUE NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    guardian_contact TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Health alerts table (resident follow-up requests)
CREATE TABLE health_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    barangay TEXT NOT NULL,
    preferred_contact TEXT NOT NULL CHECK (preferred_contact IN ('phone', 'text', 'visit')),
    symptoms TEXT[], -- Array of selected symptoms
    onset_date DATE NOT NULL,
    note TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    urgency_flag BOOLEAN DEFAULT false,
    assigned_worker_id UUID REFERENCES users(id),
    follow_up_status TEXT DEFAULT 'new' CHECK (follow_up_status IN ('new', 'acknowledged', 'contacted', 'referred', 'closed')),
    follow_up_notes TEXT,
    follow_up_updated_at TIMESTAMP WITH TIME ZONE,
    reference_number TEXT UNIQUE NOT NULL
);

-- Response activities table (field work logging)
CREATE TABLE response_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_type TEXT NOT NULL CHECK (activity_type IN (
        'search_and_destroy', 
        'cleanup_drive', 
        'inspection', 
        'larval_source_reduction', 
        'fogging_spraying', 
        'health_education', 
        'referral'
    )),
    activity_date TIMESTAMP WITH TIME ZONE NOT NULL,
    barangay TEXT NOT NULL,
    purok TEXT,
    team TEXT NOT NULL,
    households_covered INTEGER,
    area_covered_sqm DECIMAL(10, 2),
    findings TEXT,
    notes TEXT,
    linked_case_cluster_id UUID, -- Reference to a group of related cases
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table (app configuration)
CREATE TABLE settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit log table (tracks all changes)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action TEXT NOT NULL,
    record_type TEXT NOT NULL,
    record_id UUID NOT NULL,
    before_value JSONB,
    after_value JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address TEXT
);

-- Insert default settings
INSERT INTO settings (key, value) VALUES
('rhu_contact_name', 'Salcedo Rural Health Unit'),
('rhu_contact_phone', 'PLACEHOLDER_PHONE'),
('rhu_contact_hours', 'PLACEHOLDER_HOURS'),
('emergency_text', 'For severe symptoms, go immediately to the nearest hospital or call emergency services.'),
('public_map_grid_size', '500'), -- meters
('aggregation_threshold', '5'), -- minimum cases to show
('data_retention_days', '2555'), -- 7 years
('outbreak_threshold_weekly', '10'),
('outbreak_threshold_barangay', '3');

-- Create indexes for performance
CREATE INDEX idx_cases_barangay ON cases(barangay);
CREATE INDEX idx_cases_report_date ON cases(report_date);
CREATE INDEX idx_cases_status ON cases(status);
CREATE INDEX idx_cases_assigned_worker ON cases(assigned_worker_id);
CREATE INDEX idx_health_alerts_barangay ON health_alerts(barangay);
CREATE INDEX idx_health_alerts_status ON health_alerts(follow_up_status);
CREATE INDEX idx_response_activities_date ON response_activities(activity_date);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);

-- Row Level Security (RLS) Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE restricted_identity ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE response_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Public can only see non-identifying aggregated data
-- This is a simplified policy - in production, use views for public access
CREATE POLICY "Public can view settings" ON settings
    FOR SELECT USING (true);

-- Staff can only see cases in their assigned barangays
CREATE POLICY "Encoders can view their cases" ON cases
    FOR SELECT USING (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

CREATE POLICY "Encoders can insert cases" ON cases
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

CREATE POLICY "Encoders can update their cases" ON cases
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

-- Restricted identity has stricter access
CREATE POLICY "Only admins can view restricted identity" ON restricted_identity
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Only admins can insert restricted identity" ON restricted_identity
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- Health alerts are routed by barangay
CREATE POLICY "Staff can view alerts in their barangay" ON health_alerts
    FOR SELECT USING (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

CREATE POLICY "Staff can update alerts in their barangay" ON health_alerts
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

-- Response activities follow same barangay rules
CREATE POLICY "Staff can view activities in their barangay" ON response_activities
    FOR SELECT USING (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

CREATE POLICY "Staff can insert activities" ON response_activities
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT id FROM users WHERE 
            (barangay = ANY(barangay_coverage) OR role = 'admin')
        )
    );

-- Admin-only access to users table
CREATE POLICY "Only admins can view users" ON users
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Only admins can manage users" ON users
    FOR ALL USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

-- Audit log is admin-only
CREATE POLICY "Only admins can view audit log" ON audit_log
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "System can insert audit log" ON audit_log
    FOR INSERT WITH CHECK (true);

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply the trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cases_updated_at BEFORE UPDATE ON cases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_restricted_identity_updated_at BEFORE UPDATE ON restricted_identity
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create a view for public-safe case statistics
CREATE OR REPLACE VIEW public_case_stats AS
SELECT 
    barangay,
    date_trunc('week', report_date) as week_start,
    classification,
    COUNT(*) as case_count,
    -- Don't show exact counts below threshold
    CASE 
        WHEN COUNT(*) >= (SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'aggregation_threshold')
        THEN COUNT(*) 
        ELSE NULL 
    END as safe_count
FROM cases
WHERE is_submitted = true
GROUP BY barangay, date_trunc('week', report_date), classification
HAVING COUNT(*) >= (SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'aggregation_threshold');

-- Grant public access to the view
GRANT SELECT ON public_case_stats TO anon;
GRANT SELECT ON public_case_stats TO authenticated;