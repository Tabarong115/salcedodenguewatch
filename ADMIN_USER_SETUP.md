# Admin User Setup Guide

> **Current setup:** This guide describes the previous user workflow. For a new Supabase project and email invitation onboarding, follow [`supabase/README.md`](supabase/README.md). Do not run the historical SQL scripts in `lib/config/` against that project.

This guide explains how to set up admin and staff users for the Salcedo Dengue Watch app with proper authentication, email verification, and role-based access control.

## Prerequisites

- Access to Supabase Dashboard (https://supabase.com/dashboard)
- Project URL: `https://dlocjhsrxgabpebqmpaz.supabase.co`
- Admin access to the Supabase project
- Run the database migrations first: `supabase_migrations_hierarchy.sql`
- Run the auth setup script: `supabase_auth_setup.sql`

## Step 1: Configure Supabase Authentication Settings

### Enable Email Confirmation

1. Go to **Supabase Dashboard** → **Authentication** → **Providers**
2. Click on **Email** provider
3. Enable **Confirm email** toggle
4. Set **Email confirmation delay** to `0` (immediate)
5. Click **Save**

### Configure Email Templates

1. Go to **Authentication** → **Email Templates**
2. Configure **Confirm signup** template:
   - Subject: `Welcome to Salcedo Dengue Watch`
   - Body: Include verification link and welcome message
3. Configure **Reset password** template:
   - Subject: `Password Reset Request`
   - Body: Include password reset link

## Step 2: Create the First Admin User

### Method 1: Through Supabase Dashboard (Recommended for first admin)

1. Go to **Authentication** → **Users**
2. Click **Add user** → **Create new user**
3. Enter the admin's email address
4. Enter a secure password (minimum 6 characters)
5. **IMPORTANT**: Check **Auto confirm user** for the first admin only
6. Click **Create user**

### Set Up Admin Profile

After creating the auth user, you need to set up their profile in the database:

1. Copy the **User ID** (UUID) from the newly created user in the Authentication dashboard
2. Go to **SQL Editor** in Supabase
3. Run the following SQL (replace with actual values):

```sql
-- Replace these values with your actual admin information
UPDATE public.users
SET 
  name = 'Dr. Maria Santos',  -- Admin's full name
  role = 'admin',
  active = true,
  rhu_id = (SELECT id FROM public.rhu WHERE name = 'Salcedo RHU' LIMIT 1),
  updated_at = NOW()
WHERE id = 'YOUR_ADMIN_UUID_HERE';
```

## Step 3: Create Staff Users

### For Regular Staff (Encoders, BHWs, BSI, etc.)

1. Go to **Authentication** → **Users**
2. Click **Add user** → **Create new user**
3. Enter staff member's email
4. Enter a temporary password
4. **DO NOT** check **Auto confirm user** (they must verify their email)
5. Click **Create user**

### Set Up Staff Profile

After creating the auth user, set up their profile:

```sql
-- Example for an encoder
UPDATE public.users
SET 
  name = 'Juan Dela Cruz',
  role = 'encoder',
  active = true,
  rhu_id = (SELECT id FROM public.rhu WHERE name = 'Salcedo RHU' LIMIT 1),
  barangay_id = (SELECT id FROM public.barangays WHERE name = 'Barangay 1' LIMIT 1),
  team = ARRAY['Team A'],
  updated_at = NOW()
WHERE id = 'STAFF_USER_UUID_HERE';
```

### Role Options

- `admin` - Full system access, can manage users and settings
- `rhu_staff` - RHU-level access to all barangays in their RHU
- `encoder` - Can create and update cases within their assigned area
- `bhw` - Barangay Health Worker, access to specific barangay
- `bsi` - Barangay Service Inspector, access to specific barangay
- `hospital_staff` - Hospital/clinic staff, access to facility's barangay

## Step 4: User Approval Workflow

### For New User Registration

When a new user registers through the app:

1. They receive a verification email
2. After verification, their account is created in `auth.users`
3. A trigger automatically creates a profile in `public.users` with:
   - `active = false` (inactive by default)
   - `role = 'encoder'` (default role)
   - Basic information from email

### Admin Approval Process

An administrator must approve new users:

```sql
-- Approve a user account
SELECT public.activate_user_account('USER_UUID_HERE');

-- Assign appropriate role
SELECT public.update_user_role('USER_UUID_HERE', 'encoder');

-- Assign to RHU and barangay
SELECT public.assign_user_to_rhu('USER_UUID_HERE', 'RHU_UUID_HERE');
SELECT public.assign_user_to_barangay('USER_UUID_HERE', 'BARANGAY_UUID_HERE');
```

## Step 5: User Management Functions

### Available Helper Functions

```sql
-- Activate user account
SELECT public.activate_user_account(user_id uuid);

-- Deactivate user account
SELECT public.deactivate_user_account(user_id uuid);

-- Update user role
SELECT public.update_user_role(user_id uuid, new_role text);

-- Assign user to RHU
SELECT public.assign_user_to_rhu(user_id uuid, rhu_id uuid);

-- Assign user to barangay
SELECT public.assign_user_to_barangay(user_id uuid, barangay_id uuid);
```

### User Management View

For easy user management, use the admin view:

```sql
-- View all users with their details
SELECT * FROM public.user_management_view;

-- Filter by role
SELECT * FROM public.user_management_view WHERE role = 'encoder';

-- Filter by active status
SELECT * FROM public.user_management_view WHERE active = false;

-- Filter by RHU
SELECT * FROM public.user_management_view WHERE rhu_id = 'RHU_UUID';
```

## Step 6: Password Reset

Users can reset their password through the app's "Forgot Password" feature. The system will:

1. Send a password reset email to the user's registered email
2. User clicks the link to set a new password
3. Password is updated in Supabase Auth

Admins can also force password resets by disabling the user account and requiring them to use password reset.

## Step 7: Security Best Practices

### Password Requirements

- Minimum 6 characters (Supabase default)
- Recommend using strong passwords with:
  - At least 8 characters
  - Mix of uppercase and lowercase
  - Numbers and special characters

### Account Security

- Always require email verification for new users (except first admin)
- Set initial passwords to temporary values and require change on first login
- Regularly review active users and deactivate former staff
- Use role-based access control to limit privileges

### Email Verification

- Email verification is required for all users except the first admin
- Users cannot log in until their email is verified
- Users can request verification email resend if needed

### Account Status

- New accounts start as `active = false` until admin approval
- Admins can deactivate accounts when staff leave
- Inactive users cannot log in even with correct credentials

## Step 8: Testing the Setup

### Test Admin Login

1. Open the app
2. Navigate to Staff Login
3. Enter admin email and password
4. Should successfully log in and see Admin Dashboard

### Test Staff Login

1. Create a test staff user following the steps above
2. Ensure their email is verified
3. Ensure their account is set to `active = true`
4. Log in with their credentials
5. Should see Staff Dashboard with appropriate permissions

### Test Email Verification

1. Create a new user without auto-confirm
2. Try to log in - should fail with "email not verified" error
3. Use the "Resend Verification" option
4. Click the verification link in email
5. Try to log in again - should work if account is active

### Test Account Inactivation

1. Set a user's `active` field to `false`
2. Try to log in with that user
3. Should fail with "account deactivated" error

## Step 9: Troubleshooting

### User Cannot Log In

1. Check if email is verified: `SELECT * FROM auth.users WHERE email = 'user@example.com'`
2. Check if account is active: `SELECT * FROM public.users WHERE email = 'user@example.com'`
3. Check if user profile exists: `SELECT * FROM public.users WHERE id = 'USER_UUID'`
4. Check error messages in the app for specific issues

### Email Not Received

1. Check email templates in Supabase Dashboard
2. Check spam/junk folders
3. Verify email configuration in Supabase project settings
4. Use "Resend Verification" option in the app

### Profile Not Created Automatically

1. Check if trigger exists: `SELECT * FROM information_schema.triggers WHERE event_object_table = 'users'`
2. Re-run the auth setup script if trigger is missing
3. Manually create profile if needed

### Permission Issues

1. Verify RLS policies are correctly applied
2. Check user role in `public.users` table
3. Ensure RHU, facility, and barangay assignments are correct
4. Test with admin account to verify it's not a broader issue

## Step 10: Maintenance

### Regular Tasks

- Monthly review of active users
- Deactivate accounts for former staff
- Review and update user roles as needed
- Monitor failed login attempts
- Update contact information for users

### Audit Trail

All user management actions are logged in the `audit_log` table:

```sql
-- View recent user management changes
SELECT * FROM public.audit_log 
WHERE record_type = 'users' 
ORDER BY created_at DESC 
LIMIT 20;
```

## Contact and Support

For issues with authentication setup:
- Check Supabase Dashboard logs
- Review error messages in the app
- Consult this documentation
- Contact technical support if needed

## Production Checklist

Before going live with real users:

- [ ] Email confirmation is enabled
- [ ] Email templates are configured
- [ ] First admin user is created and tested
- [ ] User approval workflow is tested
- [ ] Password reset functionality is tested
- [ ] Role-based access is verified
- [ ] All staff users are created and assigned
- [ ] Email verification flow is tested
- [ ] Account deactivation flow is tested
- [ ] Security policies are reviewed
- [ ] Backup procedures are in place
