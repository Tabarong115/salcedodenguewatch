# Salcedo Dengue Watch

Salcedo Dengue Watch is a Flutter Android application for public dengue awareness, case reporting, surveillance, and response coordination for Salcedo, Eastern Samar, Philippines. Residents use the public screens to view aggregated activity and submit health alerts. Authorized RHU, hospital, and barangay staff manage reports and cases according to their assigned roles and areas.

The repository contains the Flutter client and Supabase database/function sources. It does not establish whether a particular hosted Supabase project has every migration applied; check the project against the SQL instructions below before relying on its data.

## Current features

### Public screens

- **Dashboard:** Shows municipality-wide reportable all-time and current-week totals, barangays with reportable activity, and registered barangays. Totals include all submitted, dated, non-duplicate cases; barangay-week breakdowns are suppressed below three cases. It distinguishes no reportable data from a query error.
- **Activity map:** Filters by day, week, month, year, or all time, and by barangay. Public markers show one coarse barangay-level location for groups of at least three submitted, dated, non-duplicate cases; public responses do not provide individual case rows or exact coordinates. Signed-in staff can see an individual map marker at each case's recorded location, subject to Supabase RLS; encoder/BHW/BSI accounts are limited to their assigned barangay, and other staff scopes are determined by their role and organizational assignment.
- **Trends & timeline:** Shows weekly public case counts from the earliest reportable week through the current week. Playback advances one week per second, with seek, restart, latest-week, municipality, and barangay controls. The chart uses the submitted, dated, non-duplicate public weekly summary; barangay-week groups below three cases remain suppressed.
- **Health alert:** Lets a resident submit their name, address, age, sex, contact number, barangay, symptoms, onset date, and notes. It warns against prank reports and explains that emergencies need immediate care. A health alert is a request for follow-up, not a confirmed case.
- **Dengue prevention:** Provides prevention information based on the DOH 4S strategy in English and Filipino.

### Staff and administration

- **Case register:** Staff see the submitted cases available to their account under Supabase RLS and their jurisdiction. The list is not restricted to cases assigned to that specific worker; assignment is for follow-up responsibility. Results are fetched in pages so large case registers are not silently limited to the API's default page size.
- **Staff dashboard:** Four summary cards show New Reports (submitted cases with pending status), Unverified Alerts (health alerts awaiting BHW/BSI verification), Active Cases (submitted, non-duplicate cases whose outcome is ongoing), and Reportable Cases (all submitted, non-duplicate cases). Case counts use the signed-in user's RLS scope; RHU staff see municipality-wide operational data, while encoder/BHW/BSI accounts are limited to their assigned barangay. These are distinct measures and can overlap where their definitions allow.
- Staff can create and manage case reports, patient outcomes, and drafts; record response activities; and access records permitted by their role and assigned barangay, facility, or RHU.
- Unverified health alerts appear in staff and administrator dashboards and remain visible until verified. Authorized dashboards reload them from the database and receive Supabase Realtime updates while the app is open and connected. BHW/BSI staff perform the verification; a verified alert is not automatically converted into a formal case. Staff should create a case report through the case workflow when appropriate.
- The app does not currently send push notifications, SMS, or email for alerts. Staff see alerts in the app dashboard.
- Admin Settings include staff profile/access management and RHU, facility, and barangay configuration. Email invitations use the `admin-create-user` Supabase Edge Function; invited profiles remain inactive until approved and correctly assigned. Admins can also provision Auth users manually. See [Supabase setup and operations](supabase/README.md).
- The RHU contact number is taken from configured RHU data, with a user-facing fallback when no number is configured; the UI does not show the internal `PLACEHOLDER_PHONE` token.

## Data rules and privacy

- Public case totals and map aggregates are based on submitted, dated, non-duplicate cases. Drafts, undated cases, and duplicate records are excluded from public totals.
- Public municipality totals include all eligible cases; barangay-week breakdowns and public map markers require at least three cases in the selected barangay/period. Public map markers use a barangay reference point or a coarsened group center, never an individual case coordinate.
- Staff map locations and case records are subject to Supabase Row Level Security (RLS), role, and organizational assignment. Do not treat the Flutter interface alone as an authorization boundary.
- Exact case locations are available on the authenticated staff map only. Access is still governed by database policies; the staff interface limits encoder/BHW/BSI barangay choices to the assigned barangay.
- Health alerts contain reporter and health information. They are visible only to authenticated staff permitted by the database policies. Database change auditing is available for selected operations; it is not a complete log of every read.
- Treat this as a development system until the RHU/LGU has completed privacy, security, access-control, retention, staff-training, and operational review. Use fictional/demo data until then.

## Database and Supabase

The app uses Supabase Auth, PostgreSQL, RLS, database views/functions/triggers, Realtime, and an Edge Function for optional staff invitations. The Flutter app should contain only the Supabase project URL and public publishable/anon key in `lib/config/supabase_config.dart`; never put a service-role key in the mobile app.

### Fresh database

For a new, empty Supabase database only, apply [`supabase/setup.sql`](supabase/setup.sql) once, then follow [supabase/README.md](supabase/README.md) to bootstrap the first administrator and configure the project. Do not use `setup.sql` to update a database that already contains app data: it is the initial schema setup, not an upgrade script.

### Existing database

Apply the additive migrations documented in [supabase/README.md](supabase/README.md) to an existing project, in the prescribed order. Current feature migrations include:

1. `supabase/migrations/20260929130000_activity_map_sync.sql` — synchronizes the map data rules and public cluster behavior.
2. `supabase/migrations/20260929140000_health_alert_report_workflow.sql` — updates health-alert intake, staff verification, and related database rules.
3. `supabase/migrations/20260929150000_public_dashboard_sync.sql` — aligns public trends timeline aggregates and barangay directory data with reportable case rules.
4. `supabase/migrations/20260929160000_rhu_municipal_scope.sql` — gives RHU staff municipality-wide operational access across case, alert, and response-activity records.
5. `supabase/migrations/20260929170000_public_municipal_summary_and_map.sql` — makes public dashboard totals municipality-wide and groups map markers by barangay while retaining the three-case minimum.

`20260929120000_public_case_map.sql` is an earlier map migration retained in the migration history. Follow the existing-database instructions in `supabase/README.md` to determine which scripts a particular database still needs; do not blindly rerun setup or migrations on a production database. Back up important data and review SQL changes before applying them.

## Roles and alert workflow

The app uses role-based profiles such as `admin`, `rhu_staff`, `hospital_staff`, `encoder`, `bhw`, and `bsi`, with access further limited by RHU, facility, or barangay assignments and database RLS. Account provisioning and activation requirements are described in [supabase/README.md](supabase/README.md).

Public health alert flow:

1. A resident submits a follow-up alert from the public screen.
2. The alert is stored in Supabase and shown on authorized staff/admin dashboards. No external phone, email, SMS, or push message is sent.
3. A BHW/BSI verifies the report using the staff workflow. The alert remains in the dashboard until it reaches the verified status.
4. If a formal dengue case is warranted, staff record it using the case-report workflow. Alert verification and case confirmation are separate records/actions.

The database policies determine which staff can see an alert; dashboard visibility does not imply that every staff member or every barangay sees every alert.

## Technology

- Flutter and Dart (package version is recorded in `pubspec.yaml`)
- Supabase Auth, PostgreSQL, RLS, Realtime, and Edge Functions
- SQLite-backed local draft support
- Provider state management and Easy Localization (English/Filipino)
- `flutter_map` and OpenStreetMap tiles
- App-wide safe-area handling keeps content clear of system bars; Android uses resize behavior for the on-screen keyboard, with scrollable layouts on key forms.

## Getting started

### Requirements

- Flutter SDK compatible with `pubspec.yaml`
- Android Studio or VS Code with Flutter support
- Android device or emulator
- Supabase project configured using the applicable steps above

### Run the app

1. Install dependencies with `flutter pub get`.
2. Copy `lib/config/supabase_config.dart.template` to `lib/config/supabase_config.dart`, then set your Supabase Project URL and public client key. The real config file is ignored by Git.
3. Initialize a fresh database with `supabase/setup.sql`, or apply the required migrations to an existing database. See [supabase/README.md](supabase/README.md).
4. Configure and activate an administrator, then provision staff and assign their scopes.
5. Run with `flutter run`.

The optional invitation flow also requires deploying `supabase/functions/admin-create-user/` and configuring its secrets and email/deep-link settings. Manual staff provisioning does not require that function.

## Known limitations

- There are no external alert notifications; staff must open the app dashboard. Realtime updates depend on connectivity and the app being open; alerts remain stored and are loaded again when the dashboard is reopened.
- Local draft storage exists, but automatic offline detection and reliable background synchronization are not complete. Do not rely on the app as an offline-first case system.
- Some secondary staff screens and reporting visualizations remain incomplete; the trends timeline and map are available, but their output depends on the quality and completeness of submitted case dates and locations.
- Data export and a complete audit-log viewing screen are not yet complete.
- A successful local build does not prove that hosted Supabase policies, views, triggers, credentials, or invitation settings are current. Verify the deployed database separately.

## Repository layout

```text
lib/
  config/                 Supabase client configuration
  services/               Authentication and data access
  screens/auth/            Sign-in and account setup
  screens/admin/           Admin dashboard and settings
  screens/staff/           Case, alert, and response workflows
  screens/public/          Dashboard, activity map, trends timeline, health alert, prevention
supabase/
  setup.sql                Initial schema for a fresh database
  migrations/              SQL changes for existing databases
  functions/                Supabase Edge Functions
  README.md                 Database setup and operational instructions
assets/translations/        English and Filipino translations
android/                    Android application configuration
```

## Related documentation

- [Supabase setup and operations](supabase/README.md)
- [Android device testing](HOW_TO_TEST_ON_ANDROID.md)
- [Real data preparation](HOW_TO_ADD_REAL_DATA.md)
- [Administrator setup checklist](ADMIN_SETUP_CHECKLIST.md)
- [Recorded test results and known status](TEST_RESULTS.md)

## Project

Developed for the Salcedo Rural Health Unit. Coordinate contributions and operational use with the RHU/LGU. Dengue prevention material references the Department of Health (DOH) Philippines 4S strategy; the project also acknowledges the National Privacy Commission, Supabase, and Flutter communities.

**README updated:** September 29, 2026  
**Package version:** See `pubspec.yaml` (currently `1.0.0+1`)
