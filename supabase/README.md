# Fresh Supabase setup

This folder is the source of truth for a **new Supabase project**. The SQL is intended for an empty project. It does not copy data from, or make changes to, the existing project.

## 1. Create the project and schema

1. Create a new project in Supabase and wait for its database to finish provisioning.
2. Open **SQL Editor** in that new project.
3. Run [`setup.sql`](setup.sql) once.
4. Confirm the script finishes successfully before configuring the app.

Do not run the older SQL files under `lib/config/` against the new project. Those files document earlier schema experiments and disagree about the profile role columns and RLS policies.

If the `public.roles` table already exists but is missing role rows, run [`seed_roles.sql`](seed_roles.sql) in SQL Editor. It inserts or refreshes only the seven app roles and does not modify `public.users`.

## Apply the activity map update to an existing project

Do not run `setup.sql` against an existing project. For the current activity map, run [`migrations/20260929130000_activity_map_sync.sql`](migrations/20260929130000_activity_map_sync.sql) in the existing project's Supabase SQL Editor. It exposes public barangay names independently of case data and adds a privacy-safe cluster function that reflects case status and outcomes while suppressing clusters smaller than three. It does not grant public access to case rows or exact coordinates. The earlier `20260929120000_public_case_map.sql` file may remain applied; this update drops its older map-summary view and replaces the app's use of that map query.

For public health alert reporter details, RHU contact synchronization, and in-app live alert updates for authorized staff, run [`migrations/20260929140000_health_alert_report_workflow.sql`](migrations/20260929140000_health_alert_report_workflow.sql) after the activity map update. Live updates appear while the staff app is open; this setup does not send SMS, email, or operating-system push notifications.

For the public trends timeline's barangay-week summary, run [`migrations/20260929150000_public_dashboard_sync.sql`](migrations/20260929150000_public_dashboard_sync.sql). It rebuilds the weekly summary for the current case schema, excludes duplicate/draft rows, and publishes barangay-week totals only when a group contains at least three submitted cases.

To give RHU staff municipality-wide operational access across every barangay, run [`migrations/20260929160000_rhu_municipal_scope.sql`](migrations/20260929160000_rhu_municipal_scope.sql). It updates the shared barangay-access function used by case, health-alert, and response-activity RLS policies and gives RHU staff the full barangay directory for municipal filters and maps. This grants RHU staff operational read/write access across case, alert, and activity records; administrator-only organization and app management policies remain separate.

For complete municipality-wide public totals and useful public map markers, run [`migrations/20260929170000_public_municipal_summary_and_map.sql`](migrations/20260929170000_public_municipal_summary_and_map.sql). Dashboard totals count all submitted, dated, non-duplicate cases across the municipality. The timeline's barangay-week groups still use the three-case minimum. The map now returns one coarse marker per barangay with at least three eligible cases in the selected period; it never returns individual case coordinates or rows.

New health alerts are visible to RHU staff and other staff whose active role and barangay/facility assignment permit access under RLS. BHW/BSI accounts can set the report to **Confirmed** after verification; other roles cannot set that status. A health alert remains a follow-up request. Staff must enter a verified dengue case separately through Case Report when appropriate.

Both staff and admin dashboards show the full unverified-alert queue. An alert stays in that queue through acknowledgement, contact, referral, or closure and leaves only when a BHW/BSI marks it **Confirmed**. While the app is open, new alerts and confirmation changes refresh the queue through Supabase Realtime; when staff reopen the app, the queue is loaded again from the database.

## 2. Configure Auth links and email

In **Authentication → URL Configuration**, add this redirect URL:

```text
salcedo-dengue-watch://auth-callback/
```

Enable email invitations and configure the invitation and recovery email templates to use Supabase's confirmation URL (the default `{{ .ConfirmationURL }}` template). The Flutter Android and iOS app registers this callback scheme. Supabase's Flutter guide explains that email authentication links need an app deep link to return to the app: https://supabase.com/docs/guides/getting-started/tutorials/with-flutter.

Disable public self-signup for this staff-only authentication flow. You can invite staff manually from **Authentication → Users → Add user → Send invitation**; the Edge Function described below is optional and only adds an invitation screen to the Flutter app. Residents do not need Auth accounts to use public dengue information.

## 3. Bootstrap the first administrator

The Auth trigger creates each new profile as `pending` and inactive. This prevents a dashboard-created Auth account from receiving access accidentally.

1. In **Authentication → Users**, create and confirm the account that will be the initial administrator.
2. Copy that Auth user's UUID.
3. In SQL Editor, run this statement after replacing the placeholder UUID:

```sql
update public.users
set role = 'admin', active = true, password_setup_required = false
where id = 'REPLACE_WITH_AUTH_USER_UUID';
```

4. Sign in to the app with that account.
5. Add the RHU, barangays, and facilities in Admin Settings before inviting scoped staff.

## 4. Optional: enable invitations from the app

Install and sign in to the Supabase CLI, then run these commands from the repository root, using the **new** project's reference:

```text
supabase link --project-ref YOUR_NEW_PROJECT_REF
supabase functions deploy admin-create-user
```

The Edge Function verifies the caller's session and active administrator profile, validates the requested role and scope, sends the email invitation, and assigns the resulting profile. Supabase provides the function's project URL and service-role secret as server-side environment variables. Never put the service-role secret in Flutter or commit it to this repository. Skip this section if you will continue inviting users in the Supabase Dashboard and assigning their profiles there.

When using app invitations, the invited staff member receives the email. The function attaches the selected role and organization scope but leaves the profile inactive. The invite link opens the app's password setup screen; the profile stays inactive until you review and activate it from Admin Settings (or the Supabase Dashboard). For manual Dashboard invitations, the profile starts pending and inactive; the new user can set their password in the app before you assign a role and activate them.

## Password setup and recovery

- Dashboard invitations use the configured Site URL as their default destination. Set both Site URL and the allowed Redirect URL to `salcedo-dengue-watch://auth-callback/` so the invitation opens the installed app without needing a website.
- The invitee chooses a password in the app. The app keeps their account inactive while awaiting your approval.
- Users who forget their password can request a reset from the Staff Login screen. The recovery email redirects to the app, which displays the password reset form.
- If the project was initialized with an earlier version of `setup.sql`, run [`password_setup_patch.sql`](password_setup_patch.sql) once in SQL Editor. This lets an invited inactive user complete password setup without granting app data access or activating the account.
- If the project was initialized before inactive profiles could be edited in stages, run [`user_scope_edit_patch.sql`](user_scope_edit_patch.sql) once in SQL Editor. It lets you set role and scope fields across separate Table Editor saves; required fields are still enforced before activation.

## 5. Point the app at the new project

Use the new project's URL and publishable/anon key in `lib/config/supabase_config.dart`. That key is intended for client use only because access is restricted by RLS. Keep the existing project's credentials unchanged until the new project is ready to replace it.

## Schema and access model

- `users.role` is the canonical role (`admin`, `rhu_staff`, `hospital_staff`, `encoder`, `bhw`, or `bsi`). The `roles` table supplies display labels and assignment requirements. There is no separate `role_id` profile column.
- New Auth users receive an inactive `pending` profile. Dashboard invitations remain pending until you assign a role; app invitations assign the chosen role and scope but also remain inactive until approval. The role and organization columns reference lookup rows, and the database checks required assignments when the profile is saved.
- An account cannot be activated while its role is still `pending`. Assign the role and required scope first, then activate it in the same Table Editor save.
- Case, alert, and activity data is scoped by the active user's role: RHU staff have municipality-wide operational scope, encoder/BHW/BSI staff are limited to their assigned barangay, and hospital staff are scoped to their facility.
- Public clients can read barangay names, submit health alerts, and read the weekly case summary. They cannot read case rows, profiles, or restricted identities.
- Public case summaries omit weekly barangay buckets below three submitted cases. Exact locations and patient identifiers are not included in that view.
- Audit records store the action, table, record ID, and actor only; they do not duplicate patient fields.

## Local check before deployment

Run `setup.sql` successfully in the new project's SQL Editor before inviting staff. Review the Edge Function only if you choose to enable in-app invitations; this repository alone cannot confirm a remote project's Auth URL settings or email delivery setup.

## Manually approve and assign an invited user

Use this Dashboard workflow if you do not want to deploy the optional invitation function:

1. In **Authentication → Users**, choose **Add user → Send invitation** and enter the staff member's email. The Auth user is created when the invitation is sent. The database trigger creates its matching `public.users` profile with `role = 'pending'` and `active = false`.
2. After the person accepts the email invitation, find their Auth user and copy its UUID. The redirect page (including a default `localhost:3000` page) does not activate the app profile; the profile stays pending and inactive until you approve it.
3. Open **Table Editor → public.users**, find the profile with that UUID, and edit it. Select a role and its required organization rows, then set `active` to `true` before saving. The role and assignment fields are foreign-key references; select existing rows in the editor. Create the RHU, barangay, or facility first if it does not exist.

Required assignments:

The `public.roles` table is the canonical list. `public.users.role` is a foreign key to `public.roles.id`; the app loads the assignable rows from this table for both Add User and Edit User role dropdowns.

| Role ID | Supabase display label | Required assignments | Assignable |
| --- | --- | --- | --- |
| `pending` | Pending setup | None; must remain inactive | No |
| `admin` | Administrator | None | Yes |
| `rhu_staff` | RHU Staff | RHU | Yes |
| `hospital_staff` | Hospital/Clinic Staff | RHU and facility belonging to that RHU | Yes |
| `encoder` | Encoder | RHU and barangay belonging to that RHU | Yes |
| `bhw` | Barangay Health Worker | RHU and barangay belonging to that RHU | Yes |
| `bsi` | Barangay Surveillance Information Officer | RHU and barangay belonging to that RHU | Yes |

Set the role and all required fields before activation. Saving an incomplete assignment is rejected by the database with a message naming the missing field. The `pending` role cannot be active. Email confirmation verifies control of the email address; your profile review and activation are the separate approval step.
