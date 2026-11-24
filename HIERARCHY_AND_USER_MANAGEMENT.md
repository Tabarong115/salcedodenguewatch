# Admin Hierarchy & User Management System

**Last Updated:** 2026-09-02  
**Status:** ✅ Implementation Complete (Ready for Supabase Integration)

---

## 📋 Overview

This document describes the new hierarchical user and organizational management system implemented in Salcedo Dengue Watch. The system allows admins to fully manage users, RHUs, facilities, and barangays directly in the app without developer intervention.

---

## 🏗️ Database Hierarchy Structure

### **Organizational Levels**

```
┌─────────────────────────────────────┐
│      ADMIN (Super User)             │
│  • Can manage everything            │
│  • Sees all data                    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  RHU (Regional Health Unit)         │
│  • Top-level organizational unit    │
│  • Can manage facilities & barangays│
│  • RHU Staff sees all RHU data      │
└─────────────────────────────────────┘
         ↙               ↘
    ┌────────────┐   ┌──────────┐
    │ Facilities │   │ Barangays│
    │ (Hospital/ │   │  (Served │
    │  Clinic)   │   │   by RHU)│
    └────────────┘   └──────────┘
         ↓                ↓
    ┌──────────────┐ ┌──────────────┐
    │Hospital Staff│ │ BHWs & BSIs  │
    │(Can see only │ │(Can see only │
    │ their clinic)│ │  their area) │
    └──────────────┘ └──────────────┘
```

---

## 📊 Database Tables (New & Updated)

### **New Tables**

#### 1. **rhu (Regional Health Units)**
```sql
CREATE TABLE public.rhu (
  id UUID PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,           -- e.g., "Salcedo RHU"
  region TEXT,                         -- e.g., "Eastern Samar"
  contact_person TEXT,                 -- Contact name
  contact_number TEXT,                 -- Phone number
  email TEXT,                          -- Email address
  address TEXT,                        -- Physical address
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

#### 2. **facilities (Hospitals & Clinics)**
```sql
CREATE TABLE public.facilities (
  id UUID PRIMARY KEY,
  rhu_id UUID NOT NULL,                -- Foreign key to RHU
  name TEXT NOT NULL,                  -- e.g., "Salcedo Health Center"
  facility_type TEXT NOT NULL,         -- 'hospital' or 'clinic'
  contact_person TEXT,
  contact_number TEXT,
  email TEXT,
  address TEXT,
  barangay TEXT,                       -- Service area barangay
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

#### 3. **barangays (Administrative Divisions)**
```sql
CREATE TABLE public.barangays (
  id UUID PRIMARY KEY,
  rhu_id UUID NOT NULL,                -- Foreign key to RHU
  name TEXT NOT NULL,                  -- e.g., "Barangay 1"
  region TEXT,
  population INTEGER,
  latitude DOUBLE PRECISION,           -- For mapping
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### **Updated Tables**

#### 4. **users (Enhanced)**
```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY,                 -- Matches Supabase Auth user ID
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'encoder',  -- Role types below
  rhu_id UUID REFERENCES rhu(id),      -- NEW: RHU assignment
  facility_id UUID REFERENCES facilities(id), -- NEW: Facility assignment
  barangay_id UUID REFERENCES barangays(id), -- NEW: Barangay assignment
  covered_barangay TEXT[],             -- LEGACY: Backward compatibility
  team TEXT[],
  active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

---

## 👥 User Roles & Access Control

| Role | RHU | Facility | Barangay | Can Create Cases? | Data Visibility |
|------|-----|----------|----------|------------------|-----------------|
| **admin** | Any | Any | Any | ✅ | All data |
| **rhu_staff** | Own | Own RHU's | Own RHU's | ✅ | All RHU data |
| **hospital_staff** | Own | Own | Own Facility's barangay | ✅ | Own facility data |
| **encoder** | Own | - | Own | ✅ | Own barangay data |
| **bhw** | Own | - | Own | ✅ | Own barangay data |
| **bsi** | Own | - | Own | ✅ | Own barangay data |

---

## 🔐 Row Level Security (RLS) Policies

All access is enforced at the database level via PostgreSQL RLS:

### **Cases Access**
- **Admins**: See all cases
- **RHU Staff**: See cases from all barangays in their RHU
- **Hospital Staff**: See cases from their facility's service area
- **Barangay Staff (BHW/BSI/Encoder)**: See only cases in their assigned barangay
- **Public**: See aggregated, anonymized data only

### **Users Access**
- **Admins**: Can create, read, update, delete any user
- **RHU Staff**: Can read users in their RHU
- **Users**: Can read their own profile

### **Facilities Access**
- **Admins**: Full access
- **RHU Staff**: Can see facilities in their RHU
- **Facility Staff**: Can see their own facility

### **Barangays Access**
- **Admins**: Full access
- **RHU Staff**: Can see barangays in their RHU
- **Barangay Staff**: Can see their assigned barangay

---

## 🎯 Admin Settings Screen

Located in: `lib/screens/admin/admin_settings_screen.dart`

### **Tabs & Features**

#### **1. Users Tab**
- ✅ View all users with role and assignment info
- ✅ Add new users with hierarchical assignment:
  - Select RHU first
  - System auto-filters facilities and barangays based on RHU
- ✅ Deactivate/reactivate users
- ✅ Edit user details (TODO: In future)

**User Creation Flow:**
1. Admin clicks "Add User"
2. Fills: Email, Password, Name, Role
3. Role determines next fields:
   - **admin**: No additional fields
   - **rhu_staff**: Select RHU
   - **hospital_staff**: Select RHU → Select Facility
   - **encoder/bhw/bsi**: Select RHU → Select Barangay
4. System creates both:
   - Auth user in Supabase Auth
   - User row in `public.users` with correct hierarchy IDs
5. New user can log in immediately

#### **2. RHU Tab**
- ✅ View all RHUs
- ✅ Add new RHU with:
  - Name (unique)
  - Region
  - Contact person
  - Contact number
  - Email
  - Address

#### **3. Facilities Tab**
- ✅ View all facilities (hospitals/clinics)
- ✅ Add new facility with:
  - Select RHU (required)
  - Name
  - Type (Hospital or Clinic)
  - Barangay served
  - Contact details (person, number, email, address)

#### **4. Barangays Tab**
- ✅ View all barangays
- ✅ Add new barangay with:
  - Select RHU (required)
  - Name
  - Region
  - Population
  - Coordinates (latitude/longitude for mapping)

---

## 🖥️ Admin Dashboard

Located in: `lib/screens/admin/admin_dashboard.dart`

### **Features**

**Statistics Cards (6 total):**
1. RHUs Count
2. Barangays Count
3. Facilities Count
4. Users Count
5. Total Cases Submitted
6. Confirmed Cases

**Quick Actions:**
- Manage Users (→ Settings)
- Manage Facilities (→ Settings)
- Manage Barangays (→ Settings)

**Navigation:**
- Sidebar drawer with user profile
- Settings menu in app bar
- Logout option

---

## 📱 Services & Code Architecture

### **AdminService** (`lib/services/admin_service.dart`)

Provides all CRUD operations:

```dart
// RHU Operations
Future<List<Map<String, dynamic>>> getRHUs()
Future<bool> createRHU({...})
Future<bool> updateRHU(String rhuId, Map updates)
Future<bool> deleteRHU(String rhuId)

// Barangay Operations
Future<List<Map<String, dynamic>>> getBarangays({String? rhuId})
Future<bool> createBarangay({...})
Future<bool> updateBarangay(String barangayId, Map updates)
Future<bool> deleteBarangay(String barangayId)

// Facility Operations
Future<List<Map<String, dynamic>>> getFacilities({String? rhuId})
Future<bool> createFacility({...})
Future<bool> updateFacility(String facilityId, Map updates)
Future<bool> deleteFacility(String facilityId)

// User Operations (with Auth integration)
Future<List<Map<String, dynamic>>> getUsers({...})
Future<bool> createUser({
  required String email,
  required String password,
  required String name,
  required String role,
  String? rhuId,
  String? facilityId,
  String? barangayId,
})
Future<bool> updateUser(String userId, Map updates)
Future<bool> deactivateUser(String userId)
Future<bool> reactivateUser(String userId)

// Dashboard
Future<Map<String, dynamic>> getAdminDashboard()
```

### **Enhanced AuthService** (`lib/services/auth_service.dart`)

**New User Model Methods:**

```dart
class User {
  // New fields
  String? rhuId;
  String? facilityId;
  String? barangayId;
  
  // New access control methods
  bool canAccessBarangay(String barangayId)
  bool canAccessRHU(String rhuId)
  bool canAccessFacility(String facilityId)
}
```

### **Updated Main & Routing** (`lib/main.dart`)

**Changes:**
- Added `Supabase.initialize()` with config credentials
- Added `AdminService` provider
- Updated `AuthWrapper` to route to `AdminDashboard` when user role is 'admin'
- Imported `AdminDashboard` widget

---

## 🗄️ SQL Migration File

**File:** `lib/config/supabase_migrations_hierarchy.sql`

**What it includes:**
✅ All new tables (rhu, facilities, barangays)
✅ Updated users table with foreign keys
✅ Updated cases, health_alerts, response_activities tables with barangay_id
✅ 25+ RLS policies for role-based access
✅ Audit logging triggers
✅ Public summary view
✅ Seed data (sample RHU, barangays, facility)

**How to use:**
1. Copy entire SQL file contents
2. Go to Supabase Console → SQL Editor → "+ New Query"
3. Paste contents
4. Click "Run"
5. ✅ Done - all tables, policies, and views created

---

## 🔄 User Creation Flow (Step-by-Step)

### **Example: Create a Barangay Health Worker (BHW)**

**Step 1: Admin navigates to Settings > Users tab**
```
Admin Dashboard → Drawer → Settings → Users Tab
```

**Step 2: Admin clicks "Add User"**
```
Form appears with fields:
- Email: bhw1@example.com
- Password: ••••••••
- Name: Maria Cruz
- Role: BHW (Barangay Health Worker)
```

**Step 3: System shows RHU selection**
```
Since role is BHW, form asks:
- Select RHU: [Salcedo RHU ▼]
```

**Step 4: System shows Barangay selection**
```
Based on selected RHU, form filters to show:
- Select Barangay: [Barangay 1 ▼]
                   [Barangay 2 ▼]
                   [Barangay 3 ▼]

Admin selects: Barangay 1
```

**Step 5: Admin clicks "Add"**
```
System:
1. Creates Auth user in Supabase Auth with:
   - email: bhw1@example.com
   - password: (hashed)

2. Creates row in public.users with:
   - id: (matches Auth user ID)
   - email: bhw1@example.com
   - name: Maria Cruz
   - role: bhw
   - rhu_id: (Salcedo RHU ID)
   - facility_id: null
   - barangay_id: (Barangay 1 ID)

3. Shows success message: "User created successfully"
```

**Step 6: BHW logs in**
```
Login Screen:
- Email: bhw1@example.com
- Password: ••••••••

Result:
- AuthService loads user profile from public.users
- User can only see cases from Barangay 1
- RLS policies enforce data access at database level
```

---

## 🔐 Security Highlights

### **Privacy by Design:**
✅ **Granular RLS**: Every query filtered by user's assigned area
✅ **No Oversharing**: Hospital staff can't see other hospitals' data
✅ **Audit Logging**: All changes logged with user, timestamp, before/after values
✅ **Password Security**: Handled by Supabase Auth (bcrypt, no plain text)
✅ **Config Secrets**: API keys in `.gitignore`, never committed

### **Access Enforcement Points:**
1. **Database Layer**: RLS policies prevent unauthorized queries
2. **Application Layer**: UI checks `user.canAccessBarangay()` before showing data
3. **Service Layer**: AdminService respects user role for operations

---

## 📥 Next Steps to Deploy

### **1. Apply Database Migration**
```
→ Supabase Console → SQL Editor
→ Copy lib/config/supabase_migrations_hierarchy.sql
→ Paste & Run
→ Verify all tables created (rhu, facilities, barangays updated)
```

### **2. Create Admin User in Supabase**
```
Supabase Console → Authentication → Users
→ Create new user (admin@example.com)
→ Note the UUID
```

### **3. Insert Admin into public.users**
```sql
INSERT INTO public.users (id, email, name, role, active)
VALUES (
  '{UUID from step 2}',
  'admin@example.com',
  'System Admin',
  'admin',
  true
);
```

### **4. Test Login Flow**
```
App → Staff Login Screen
Email: admin@example.com
Password: (from Supabase Auth)
→ Should see Admin Dashboard
→ Should see Settings with all management tabs
```

### **5. Create Test Data (Optional)**
```
Use Admin Dashboard to:
1. Add test RHU
2. Add test barangays to RHU
3. Add test facilities
4. Add test users (bhw, encoder, rhu_staff)
5. Verify access control works
```

---

## 🎓 Features Coming Soon

- ✅ User edit functionality (currently add/deactivate only)
- ✅ Bulk user import (CSV)
- ✅ Password reset for existing users
- ✅ User activity audit trail
- ✅ Role-based staff dashboards (non-admin screens)
- ✅ Advanced analytics & reporting

---

## 📚 Translation Support

All new UI strings translated to:
- **English** (assets/translations/en.json)
- **Filipino** (assets/translations/fil.json)

**Example translations added:**
- `admin_settings`, `admin_dashboard`
- `add_user`, `add_rhu`, `add_facility`, `add_barangay`
- All role names and UI labels

---

## 🛠️ For Developers

### **Key Files**

| File | Purpose |
|------|---------|
| `lib/config/supabase_migrations_hierarchy.sql` | Database schema + RLS policies |
| `lib/services/admin_service.dart` | CRUD operations for hierarchy |
| `lib/services/auth_service.dart` | Enhanced User model with access checks |
| `lib/screens/admin/admin_dashboard.dart` | Admin home screen with stats |
| `lib/screens/admin/admin_settings_screen.dart` | Management interfaces for all entities |
| `lib/main.dart` | Supabase init, routing to admin on login |

### **Important: Do NOT Skip**

1. **Never commit real credentials** (`lib/config/supabase_config.dart` stays in `.gitignore`)
2. **Test RLS policies** by logging in as different roles and verifying access
3. **Audit logs** are automatically created by triggers; check them regularly
4. **User password creation** happens in Supabase Auth during signup, never ask user to reset manually initially

---

## ✅ Checklist for Deployment

- [ ] SQL migrations applied to Supabase
- [ ] Admin user created in Auth
- [ ] Admin user row inserted in public.users
- [ ] App credentials configured in supabase_config.dart
- [ ] AdminService provider added to main.dart
- [ ] Login flow tested with admin account
- [ ] Admin Dashboard loads without errors
- [ ] Admin Settings accessible from dashboard
- [ ] Can add new users through UI
- [ ] New users can log in
- [ ] Access control verified (test barangay isolation)
- [ ] Audit logs showing changes

---

**System designed for scalability and privacy. Admins control everything. No developer intervention needed for user management!** 🎯
