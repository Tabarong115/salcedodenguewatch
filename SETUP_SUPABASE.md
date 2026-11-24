# Supabase setup

For the fresh Supabase project, follow the current [setup guide](supabase/README.md) and run [`supabase/setup.sql`](supabase/setup.sql) once in the new project's SQL Editor.

`supabase/setup.sql` creates the app's schema from scratch, including the role lookup table, `users.role` foreign key, role-specific assignment checks, and RLS policies. It does not migrate or copy the old database. Do not run the historical SQL experiments in `lib/config/`.
