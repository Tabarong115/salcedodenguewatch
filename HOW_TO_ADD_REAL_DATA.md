# How to Add Real Data to Salcedo Dengue Watch

⚠️ **IMPORTANT WARNING**: Do NOT add real patient data until the RHU/LGU has approved the workflow, privacy notice, data access procedures, and emergency contact details. Unauthorized use of real health data may violate Philippine data privacy laws.

## Prerequisites Before Adding Real Data

Before you can add real patient data, ensure:

1. ✅ RHU/LGU has approved the case form and workflow
2. ✅ A privacy officer or authorized LGU/RHU representative has approved the privacy notice
3. ✅ Official Salcedo barangay names and approved map boundary data are loaded
4. ✅ Staff accounts and barangay assignments are properly configured
5. ✅ RHU operating hours, phone numbers, and emergency directions are correct
6. ✅ The alert-review team and backup person are assigned
7. ✅ Public map grouping and small-count hiding rules are checked
8. ✅ A practice session has been completed using fictional data
9. ✅ Backup and record-retention responsibilities are assigned

## Step 1: Set Up Supabase Project

### Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or log in
3. Click "New Project"
4. Choose a name (e.g., "salcedo-dengue-watch")
5. Set a strong database password
6. Choose a region close to the Philippines (e.g., Singapore)
7. Wait for the project to be created (2-3 minutes)

### Configure Database

1. Open your Supabase project
2. Go to the **SQL Editor** (icon looks like a terminal)
3. Copy the contents of `lib/config/database_schema.sql`
4. Paste it into the SQL Editor
5. Click **Run** to execute the schema
6. Verify that all tables were created successfully

### Update App Configuration

1. Open `lib/config/supabase_config.dart`
2. Replace the placeholder values:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```
3. Get these values from:
   - Go to **Project Settings** > **API**
   - Copy the **Project URL**
   - Copy the **anon/public key**
4. Save the file

## Step 2: Create Staff Accounts

### Create Supabase Auth Users

1. In Supabase, go to **Authentication** > **Users**
2. Click "Add User" > "Create New User"
3. For each staff member:
   - Enter their email
   - Set a temporary password
   - Auto-confirm the user
   - Add user metadata (name, role if needed)

### Add User Records to Database

1. Go to **SQL Editor**
2. Run this for each staff member (replace with actual data):

```sql
INSERT INTO users (email, name, role, barangay_coverage, team, is_active) VALUES
('staff.email@salcedo.doh.gov.ph', 'Staff Name', 'encoder', 
 ARRAY['Barangay 1', 'Barangay 2'], 'Team A', true);
```

3. For administrators:
```sql
INSERT INTO users (email, name, role, barangay_coverage, team, is_active) VALUES
('admin.email@salcedo.doh.gov.ph', 'Admin Name', 'admin', 
 ARRAY['Barangay 1', 'Barangay 2', 'Barangay 3', 'Barangay 4', 'Barangay 5'], 'Team A', true);
```

## Step 3: Configure Barangays

### Update Barangay List

1. Get the official list of barangays in Salcedo, Eastern Samar
2. Update the barangay lists in the app code:
   - `lib/screens/public/health_alert_screen.dart`
   - `lib/screens/staff/case_report_screen.dart`
   - `lib/screens/staff/response_activity_screen.dart`
3. Replace the sample barangay names with official names

### Add Map Boundaries (Optional but Recommended)

1. Obtain official barangay boundary data in GeoJSON or KML format
2. This can be requested from:
   - Municipal Planning and Development Office (MPDO)
   - Geographic Information System (GIS) office
   - National Mapping and Resource Information Authority (NAMRIA)
3. Integrate the boundary data with the map component

## Step 4: Configure RHU Settings

### Update Contact Information

1. In Supabase SQL Editor, run:
```sql
UPDATE settings SET value = 'Official RHU Name' WHERE key = 'rhu_contact_name';
UPDATE settings SET value = 'Official Phone Number' WHERE key = 'rhu_contact_phone';
UPDATE settings SET value = 'Official Operating Hours' WHERE key = 'rhu_contact_hours';
UPDATE settings SET value = 'Official Emergency Instructions' WHERE key = 'emergency_text';
```

### Configure Privacy Settings

Review and adjust these settings in the database:

```sql
-- Public map grid size (in meters)
UPDATE settings SET value = '500' WHERE key = 'public_map_grid_size';

-- Minimum cases to show publicly (small-count suppression)
UPDATE settings SET value = '5' WHERE key = 'aggregation_threshold';

-- Data retention period (in days)
UPDATE settings SET value = '2555' WHERE key = 'data_retention_days';

-- Outbreak thresholds
UPDATE settings SET value = '10' WHERE key = 'outbreak_threshold_weekly';
UPDATE settings SET value = '3' WHERE key = 'outbreak_threshold_barangay';
```

## Step 5: Test with Real Workflow

### Conduct Practice Session

Before going live:

1. Use fictional test data only
2. Have staff practice:
   - Submitting case reports
   - Logging response activities
   - Managing health alerts
   - Using admin functions
3. Test all three user roles (public, encoder, admin)
4. Verify privacy controls are working
5. Test offline functionality
6. Test on actual Android devices

### Verify Privacy Compliance

1. Ensure patient names never appear on public screens
2. Verify exact addresses are not publicly visible
3. Check that phone numbers are protected
4. Confirm exact coordinates are staff-only
5. Test small-count suppression (areas with <5 cases)
6. Verify audit logging is working

## Step 6: Train Staff

### Training Checklist

- [ ] All staff can log in successfully
- [ ] Staff understand the case reporting workflow
- [ ] Staff know how to save drafts for offline use
- [ ] Staff understand privacy requirements
- [ ] Staff know how to log response activities
- [ ] Staff can review and follow up on health alerts
- [ ] Admin users understand user management
- [ ] Admin users know how to configure settings
- [ ] All staff understand emergency procedures

### Provide Documentation

Give each staff member:
- Printed user guide for their role
- Emergency contact information
- Privacy notice acknowledgment form
- Troubleshooting guide

## Step 7: Go Live

### Launch Checklist

- [ ] All fictional test data is removed
- [ ] All real staff accounts are created
- [ ] RHU contact information is verified
- [ ] Emergency procedures are documented
- [ ] Privacy settings are reviewed and approved
- [ ] Backup procedures are established
- [ ] Data retention policy is documented
- [ ] Staff training is completed
- [ ] Practice session was successful
- [ ] Legal/privacy approval is obtained

### Monitor Initial Usage

For the first week:

1. Monitor system performance
2. Check data quality regularly
3. Address staff questions promptly
4. Verify privacy controls are working
5. Review audit logs for any issues
6. Collect feedback for improvements

## Data Entry Guidelines

### Case Reports

- Only enter data for confirmed RHU cases
- Use official RHU forms as reference
- Double-check classification (suspected/probable/confirmed)
- Enter exact location for staff use only
- Save draft if internet is unstable
- Submit only when all required fields are complete

### Health Alerts

- Clearly explain these are requests for follow-up, not diagnoses
- Residents must see emergency warning before submitting
- Assign alerts to appropriate staff based on barangay
- Follow up within 24-48 hours
- Create separate case report only when appropriate

### Response Activities

- Log all field activities promptly
- Include accurate area coverage data
- Note any findings or concerns
- Link to case clusters when applicable
- Review activity logs weekly

## Privacy and Security Reminders

### Never Share
- Patient names on public screens
- Exact home addresses publicly
- Phone numbers publicly
- Exact coordinates publicly
- Individual case dates publicly

### Always Protect
- Use secure passwords for staff accounts
- Lock devices when not in use
- Report any security concerns immediately
- Follow data retention policies
- Maintain audit logs

### Legal Compliance
- Follow Philippine Data Privacy Act
- Obtain necessary approvals
- Document data access requests
- Maintain privacy notices
- Conduct regular privacy audits

## Backup and Recovery

### Regular Backups

- Supabase automatically backs up database daily
- Export data weekly for additional safety
- Keep backup copies in secure locations
- Test backup restoration periodically

### Data Retention

- Follow the configured retention period (default: 7 years)
- Archive old data appropriately
- Securely delete data when required
- Document data destruction

## Support and Maintenance

### Ongoing Tasks

- Monitor system performance
- Update app as needed
- Train new staff members
- Review and update settings
- Address user feedback
- Maintain security updates

### Emergency Contacts

Keep these contacts updated:
- RHU administrator
- IT support
- Supabase support (if needed)
- Legal/privacy officer

## Questions or Issues

If you encounter issues:

1. Check the troubleshooting guide
2. Review the audit logs
3. Contact technical support
4. Document the issue for future reference

Remember: This system handles sensitive health data. Always prioritize patient privacy and data security.