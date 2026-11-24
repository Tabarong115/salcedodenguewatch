# 🚀 Quick Start: Deploy Hierarchy System

**Estimated time:** 15-20 minutes

---

## ✅ Step 1: Apply Database Schema (5 min)

### **What:** Add new tables and RLS policies to Supabase

1. **Go to your Supabase project**
   - URL: https://app.supabase.com
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "+ New Query"

3. **Copy & Paste Schema**
   - Open: `lib/config/supabase_migrations_hierarchy.sql`
   - Copy **entire file contents**
   - Paste into SQL Editor

4. **Run Migration**
   - Click "Run" button
   - Wait for completion (should see green checkmark)

5. **Verify Tables Created**
   - Go to "Table Editor" in sidebar
   - You should see:
     - ✅ rhu
     - ✅ facilities
     - ✅ barangays
     - ✅ users (updated)
     - ✅ cases (updated)
     - ✅ health_alerts (updated)
     - ✅ response_activities (updated)

---

## ✅ Step 2: Create Admin User in Auth (3 min)

### **What:** Create the first admin account

1. **Go to Authentication**
   - In Supabase, click "Authentication" sidebar
   - Click "Users"

2. **Create Admin User**
   - Click "Invite user" or create directly
   - Email: `admin@example.com`
   - Password: Create a strong password (you'll use this to test login)
   - Confirm creation

3. **Copy User ID**
   - Look at the user row created
   - Copy the **UUID** value (long ID like `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
   - Save it somewhere - you'll need it next

---

## ✅ Step 3: Insert Admin into Users Table (2 min)

### **What:** Link the Auth user to the public.users table

1. **Open SQL Editor Again**
   - Click "SQL Editor"
   - Click "+ New Query"

2. **Run Admin Insert**
   ```sql
   INSERT INTO public.users (
     id,
     email,
     name,
     role,
     active,
     created_at
   ) VALUES (
     '{PASTE_UUID_FROM_STEP2_HERE}',
     'admin@example.com',
     'System Administrator',
     'admin',
     true,
     now()
   );
   ```

3. **Replace UUID**
   - Find: `{PASTE_UUID_FROM_STEP2_HERE}`
   - Replace with: UUID you copied in Step 2
   - Example: `'a1b2c3d4-e5f6-7890-abcd-ef1234567890'`

4. **Click Run**
   - Should see: "1 row inserted"

---

## ✅ Step 4: Create Sample Organization Data (5 min)

### **What:** Add sample RHU, barangays, and facilities for testing

**Open new SQL Query and run:**

```sql
-- Sample Data for Testing

-- 1. Create RHU (if not already seeded)
INSERT INTO public.rhu (name, region, contact_person, contact_number, email, address)
VALUES (
  'Salcedo RHU',
  'Eastern Samar',
  'Dr. Maria Santos',
  '09123456789',
  'rhu@salcedo.gov.ph',
  'Salcedo, Eastern Samar'
) ON CONFLICT (name) DO NOTHING;

-- 2. Get RHU ID for next inserts
-- (Don't run this - use the ID from RHU table directly)

-- 3. Create Barangays
INSERT INTO public.barangays (rhu_id, name, region, population)
SELECT id, 'Barangay 1', 'Eastern Samar', 5000
FROM public.rhu WHERE name = 'Salcedo RHU'
ON CONFLICT DO NOTHING;

INSERT INTO public.barangays (rhu_id, name, region, population)
SELECT id, 'Barangay 2', 'Eastern Samar', 4500
FROM public.rhu WHERE name = 'Salcedo RHU'
ON CONFLICT DO NOTHING;

-- 4. Create Facility
INSERT INTO public.facilities (rhu_id, name, facility_type, barangay, contact_person, contact_number, email, address)
SELECT id, 'Salcedo Health Center', 'clinic', 'Barangay 1', 'Nurse Rosa', '09987654321', 'hc@salcedo.gov.ph', 'Salcedo'
FROM public.rhu WHERE name = 'Salcedo RHU'
ON CONFLICT DO NOTHING;
```

---

## ✅ Step 5: Start Flutter App (2 min)

### **What:** Run the app and verify Supabase connection

1. **Terminal in project root:**
   ```bash
   flutter pub get
   flutter run
   ```

2. **App should start**
   - First screen: Public Dashboard (unauthenticated)
   - No errors in console

---

## ✅ Step 6: Test Admin Login (3 min)

### **What:** Log in as admin and verify admin dashboard appears

1. **Find Login Screen**
   - On Public Dashboard, look for "Staff Login" or similar button
   - If not visible, check if login is on separate screen

2. **Enter Admin Credentials**
   - Email: `admin@example.com`
   - Password: (the password you created in Step 2)
   - Click Login

3. **Expected Result**
   - ✅ Admin Dashboard appears
   - ✅ Shows statistics cards (RHUs, Barangays, Facilities, Users, Cases)
   - ✅ Shows Quick Actions buttons
   - ✅ Sidebar drawer visible with user info

4. **If Error**
   - Check browser console for Supabase error
   - Verify:
     - Supabase URL and key correct in supabase_config.dart
     - Admin user exists in Supabase Auth
     - Admin row exists in public.users table
     - RLS policies aren't blocking the query

---

## ✅ Step 7: Test User Creation (3 min)

### **What:** Verify admin can create new users through the app

1. **In Admin Dashboard**
   - Click "Settings" (in menu or sidebar)
   - Should see 4 tabs: Users | RHU | Facilities | Barangays

2. **Go to Users Tab**
   - Should show current admin user
   - Click "Add User" button

3. **Create Test User (Encoder)**
   ```
   Email: encoder1@example.com
   Password: TestPassword123
   Name: Test Encoder
   Role: Encoder
   Select RHU: Salcedo RHU
   Select Barangay: Barangay 1
   ```
   - Click "Add"

4. **Expected Result**
   - ✅ User created successfully message
   - ✅ User appears in list
   - ✅ User can log in with those credentials

---

## ✅ Step 8: Verify Access Control (2 min)

### **What:** Test that RLS policies are working

1. **Log out as admin**
   - Click drawer → Logout

2. **Log in as encoder1**
   - Email: `encoder1@example.com`
   - Password: `TestPassword123`
   - Should see encoder dashboard/screen (TODO for you to build)

3. **Test Data Isolation**
   - Create a case in Barangay 1 (as encoder1)
   - Create another case in Barangay 2 via admin
   - As encoder1, you should only see Barangay 1 case
   - (RLS policy prevents cross-barangay access)

---

## ⚠️ Troubleshooting

### **"Supabase not initialized"**
- Make sure `Supabase.initialize()` called in main.dart
- Verify supabase_config.dart has correct URL and key

### **"Access denied" when creating users**
- Verify logged-in user is actually admin role
- Check public.users table that admin row has `role = 'admin'`

### **Users can't log in after creation**
- Verify Supabase Auth user was created (Auth → Users in console)
- Verify password is correct
- Check that email matches exactly

### **Settings screen doesn't load**
- Check network tab in DevTools
- Verify RLS policies aren't blocking queries
- Check Supabase logs for query errors

### **Can't see dropdown options (RHU/Barangay/Facility)**
- Make sure seed data was inserted (Step 4)
- Verify RHU, Barangays, Facilities exist in their tables

---

## 🎯 What Works Now

✅ **Admin Dashboard** - Stats and overview  
✅ **Admin Settings** - Manage users, RHU, facilities, barangays  
✅ **User Creation** - Full CRUD with Auth integration  
✅ **Hierarchical Organization** - RHU → Facilities → Barangays → Users  
✅ **Role-Based Access** - RLS policies enforce who sees what  
✅ **Multi-language UI** - English & Filipino  

---

## 📋 What's Next (Your Todo)

⏳ **Build Staff Dashboards**
- Create encoder dashboard screen
- Create bhw/bsi dashboard screen  
- Create hospital_staff dashboard screen
- Create rhu_staff dashboard screen

⏳ **Implement Staff Workflows**
- Case reporting form integration with hierarchy
- Health alert assignment
- Response activity logging

⏳ **Advanced Features**
- User profile editing screen
- Bulk user import (CSV)
- Password reset functionality
- Advanced reporting & analytics

---

## 📞 Reference

**Files Modified/Created:**
- ✅ `lib/config/supabase_migrations_hierarchy.sql` - Database schema
- ✅ `lib/services/admin_service.dart` - Admin CRUD operations
- ✅ `lib/services/auth_service.dart` - Enhanced User model
- ✅ `lib/screens/admin/admin_dashboard.dart` - Admin home
- ✅ `lib/screens/admin/admin_settings_screen.dart` - Settings UI
- ✅ `lib/main.dart` - Supabase init, routing, providers
- ✅ `assets/translations/en.json` - English strings
- ✅ `assets/translations/fil.json` - Filipino strings
- ✅ `HIERARCHY_AND_USER_MANAGEMENT.md` - Full documentation

**Database:** Supabase PostgreSQL with RLS

**Authentication:** Supabase Auth (email/password)

---

**You're all set! Start with Step 1 and work through each step. Everything is ready to deploy!** 🚀
