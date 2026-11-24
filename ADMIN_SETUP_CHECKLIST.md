# Admin Setup Checklist for Salcedo Dengue Watch

> **Current database setup:** Use [`supabase/README.md`](supabase/README.md) for the clean project schema, first-admin bootstrap, and staff email invitations. This checklist contains older database setup steps and should not be used to install a schema.

This checklist contains all the fields and settings that the RHU administrator must configure before the app can be launched with real data.

## Pre-Launch Approval Checklist

Before configuring the app, ensure you have:

- [ ] RHU/LGU approval for the case form and staff workflow
- [ ] Privacy officer or authorized LGU/RHU representative approval for privacy notice
- [ ] Official Salcedo barangay names and approved map boundary data
- [ ] Staff account information (names, emails, barangay assignments)
- [ ] Official RHU contact details and operating hours
- [ ] Emergency procedures and contact information
- [ ] Alert-review team assignments and backup contacts
- [ ] Privacy level decisions (public map grouping, small-count rules)
- [ ] Completion of practice session with fictional data
- [ ] Assignment of backup and record-retention responsibilities

## Database Configuration

### Supabase Project Setup

- [ ] Create Supabase project
- [ ] Run database schema (`database_schema.sql`)
- [ ] Configure app with Supabase URL and anon key
- [ ] Test database connection
- [ ] Enable Row Level Security (RLS)
- [ ] Verify security policies are active

### Settings Configuration

Update these settings in the `settings` table or via admin interface:

#### RHU Contact Information

- [ ] **RHU Contact Name**: `rhu_contact_name`
  - Current value: "Salcedo Rural Health Unit"
  - Required: Official RHU name
  
- [ ] **RHU Contact Phone**: `rhu_contact_phone`
  - Current value: "PLACEHOLDER_PHONE"
  - Required: Official RHU phone number(s)
  - Format: "Primary: (055) 123-4567, Emergency: 911"
  
- [ ] **RHU Operating Hours**: `rhu_contact_hours`
  - Current value: "PLACEHOLDER_HOURS"
  - Required: Official operating hours
  - Format: "Monday-Friday 8:00 AM - 5:00 PM, Saturday 8:00 AM - 12:00 PM"

#### Emergency Information

- [ ] **Emergency Text**: `emergency_text`
  - Current value: "For severe symptoms, go to the RHU/nearest hospital or use the official emergency contact."
  - Required: Official emergency instructions
  - Include: Nearest hospital, emergency numbers, after-hours procedures

#### Privacy Settings

- [ ] **Public Map Grid Size**: `public_map_grid_size`
  - Current value: "500" (meters)
  - Recommended: 500-1000 meters
  - Purpose: Size of grid cells for public map aggregation
  
- [ ] **Aggregation Threshold**: `aggregation_threshold`
  - Current value: "5" (minimum cases)
  - Recommended: 3-5 cases
  - Purpose: Minimum cases required to show an area publicly
  - Warning: Lower values may affect privacy
  
- [ ] **Data Retention Days**: `data_retention_days`
  - Current value: "2555" (7 years)
  - Recommended: Follow DOH guidelines (typically 5-10 years)
  - Purpose: How long to keep records before archival/deletion

#### Outbreak Detection Thresholds

- [ ] **Weekly Outbreak Threshold**: `outbreak_threshold_weekly`
  - Current value: "10" cases per week
  - Required: Based on local epidemiology
  - Consult with: Regional epidemiologist
  
- [ ] **Barangay Outbreak Threshold**: `outbreak_threshold_barangay`
  - Current value: "3" cases per barangay per week
  - Required: Based on local epidemiology
  - Consult with: Regional epidemiologist

## User Account Setup

### Create Staff Accounts

For each staff member, complete:

#### Encoder Accounts

- [ ] **Staff Member 1**
  - Email: _______________________
  - Name: _______________________
  - Role: encoder
  - Barangay Coverage: _______________________
  - Team: _______________________
  - Is Active: ☐ Yes ☐ No
  
- [ ] **Staff Member 2**
  - Email: _______________________
  - Name: _______________________
  - Role: encoder
  - Barangay Coverage: _______________________
  - Team: _______________________
  - Is Active: ☐ Yes ☐ No
  
- [ ] **Staff Member 3**
  - Email: _______________________
  - Name: _______________________
  - Role: encoder
  - Barangay Coverage: _______________________
  - Team: _______________________
  - Is Active: ☐ Yes ☐ No

#### Administrator Accounts

- [ ] **Administrator 1**
  - Email: _______________________
  - Name: _______________________
  - Role: admin
  - Barangay Coverage: All barangays
  - Team: _______________________
  - Is Active: ☐ Yes ☐ No

- [ ] **Administrator 2 (Backup)**
  - Email: _______________________
  - Name: _______________________
  - Role: admin
  - Barangay Coverage: All barangays
  - Team: _______________________
  - Is Active: ☐ Yes ☐ No

### Supabase Auth Setup

For each user account:

- [ ] Create user in Supabase Authentication
- [ ] Set temporary password
- [ ] Auto-confirm user email
- [ ] Add user to users table with role and coverage
- [ ] Test login functionality
- [ ] Require password change on first login

## Barangay Configuration

### Official Barangay List

Update barangay names throughout the app with official names:

- [ ] Barangay 1: _______________________ (Official Name)
- [ ] Barangay 2: _______________________ (Official Name)
- [ ] Barangay 3: _______________________ (Official Name)
- [ ] Barangay 4: _______________________ (Official Name)
- [ ] Barangay 5: _______________________ (Official Name)
- [ ] Add additional barangays as needed: _______________________

### Update in Code Files

Update these files with official barangay names:

- [ ] `lib/screens/public/health_alert_screen.dart`
- [ ] `lib/screens/staff/case_report_screen.dart`
- [ ] `lib/screens/staff/response_activity_screen.dart`

### Map Boundary Data (Optional but Recommended)

- [ ] Obtain official barangay boundary data (GeoJSON/KML)
- [ ] Source: MPDO / GIS office / NAMRIA
- [ ] Integrate with map component
- [ ] Test boundary display
- [ ] Verify accuracy against official maps

## Content Configuration

### Prevention Guide Content

Review and customize prevention content:

- [ ] **4S Strategy Descriptions**
  - Search & Destroy: Customize local guidance
  - Self-Protection: Customize local guidance
  - Seek Early Consultation: Customize local guidance
  - Support Fogging/Spraying: Customize local guidance
  
- [ ] **4 O'clock Habit**
  - Customize time if different from 4:00 PM
  - Add local-specific actions
  
- [ ] **Warning Signs**
  - Review list for completeness
  - Add local-specific warning signs if needed
  
- [ ] **RHU Contact Information**
  - Verify phone numbers
  - Verify operating hours
  - Add specific departments if needed

### Health Alert Form

- [ ] **Symptom List**
  - Review symptom options
  - Add local-specific symptoms if needed
  - Ensure translations are accurate
  
- [ ] **Contact Methods**
  - Review: phone, text, visit
  - Add other methods if used locally
  
- [ ] **Emergency Warning**
  - Customize emergency instructions
  - Include local hospital information
  - Add after-hours procedures

## Team Configuration

### Response Teams

Define response teams:

- [ ] **Team A**
  - Members: _______________________
  - Primary Barangays: _______________________
  - Backup Barangays: _______________________
  
- [ ] **Team B**
  - Members: _______________________
  - Primary Barangays: _______________________
  - Backup Barangays: _______________________
  
- [ ] **Team C**
  - Members: _______________________
  - Primary Barangays: _______________________
  - Backup Barangays: _______________________

### Alert Review Assignment

- [ ] **Primary Alert Reviewer**
  - Name: _______________________
  - Contact: _______________________
  - Hours: _______________________
  
- [ ] **Backup Alert Reviewer**
  - Name: _______________________
  - Contact: _______________________
  - Hours: _______________________

## Testing and Validation

### Functionality Testing

- [ ] Test public dashboard with sample data
- [ ] Test health alert submission
- [ ] Test staff login for all users
- [ ] Test case report creation and submission
- [ ] Test draft saving and loading
- [ ] Test response activity logging
- [ ] Test admin dashboard functions
- [ ] Test user management (admin only)
- [ ] Test settings configuration (admin only)
- [ ] Test language switch (English/Filipino)

### Privacy Testing

- [ ] Verify patient names are not visible publicly
- [ ] Verify exact addresses are not visible publicly
- [ ] Verify phone numbers are not visible publicly
- [ ] Verify exact coordinates are staff-only
- [ ] Test small-count suppression
- [ ] Verify map aggregation is working
- [ ] Test audit log access (admin only)
- [ ] Verify restricted identity table access

### Performance Testing

- [ ] Test on low-cost Android phone
- [ ] Test on slow mobile data connection
- [ ] Test offline functionality
- [ ] Test draft sync when connection restored
- [ ] Verify app loading times
- [ ] Test with large datasets

## Security Configuration

### Access Control

- [ ] Verify RLS policies are active
- [ ] Test barangay-based access restrictions
- [ ] Verify admin-only functions are protected
- [ ] Test audit trail functionality
- [ ] Review and update security policies

### Data Protection

- [ ] Enable database encryption
- [ ] Configure backup schedule
- [ ] Test backup restoration
- [ ] Set up data retention procedures
- [ ] Configure secure deletion process

## Documentation

### User Documentation

- [ ] Create staff user guides
- [ ] Create admin user guides
- [ ] Create public user guide
- [ ] Create troubleshooting guide
- [ ] Create emergency procedures guide

### Policy Documentation

- [ ] Document privacy policy
- [ ] Document data retention policy
- [ ] Document access request procedures
- [ ] Document breach notification procedures
- [ ] Document backup and recovery procedures

## Training

### Staff Training

- [ ] Train all encoders on case reporting
- [ ] Train all encoders on response activity logging
- [ ] Train all encoders on health alert review
- [ ] Train all encoders on privacy requirements
- [ ] Train administrators on user management
- [ ] Train administrators on settings configuration
- [ ] Train administrators on data export procedures
- [ ] Conduct practice session with fictional data

### User Acceptance

- [ ] Obtain staff acknowledgement of training
- [ ] Obtain staff acknowledgement of privacy policy
- [ ] Obtain administrator sign-off on configuration
- [ ] Obtain RHU/LGU approval for launch

## Launch Preparation

### Final Checks

- [ ] Remove all fictional test data
- [ ] Verify all real staff accounts are active
- [ ] Verify all contact information is current
- [ ] Verify emergency procedures are documented
- [ ] Verify privacy settings are approved
- [ ] Verify backup procedures are tested
- [ ] Verify monitoring procedures are in place

### Go-Live Decision

- [ ] All checklist items completed
- [ ] RHU/LGU approval obtained
- [ ] Privacy approval obtained
- [ ] Staff training completed
- [ ] Testing completed successfully
- [ ] Documentation completed
- [ ] Emergency procedures in place

## Post-Launch Monitoring

### First Week Tasks

- [ ] Monitor system performance daily
- [ ] Check data quality daily
- [ ] Review audit logs daily
- [ ] Address staff questions promptly
- [ ] Collect user feedback
- [ ] Document any issues

### Ongoing Tasks

- [ ] Weekly data quality review
- [ ] Monthly user access review
- [ ] Quarterly security review
- [ ] Annual privacy audit
- [ ] Regular backup verification
- [ ] Update documentation as needed

## Contact Information

### Key Contacts

- **RHU Administrator**: _______________________
- **IT Support**: _______________________
- **Privacy Officer**: _______________________
- **Backup Administrator**: _______________________
- **Supabase Support**: https://supabase.com/support

### Emergency Contacts

- **System Emergency**: _______________________
- **Data Breach**: _______________________
- **Privacy Incident**: _______________________

---

## Sign-Off

**RHU Administrator**: _______________________ Date: ___________

**Privacy Officer**: _______________________ Date: ___________

**IT/Technical Lead**: _______________________ Date: ___________

**LGU Representative**: _______________________ Date: ___________

**Launch Approval**: ☐ Approved ☐ Not Approved

**Notes**: _______________________
