-- Read-only diagnostic; it does not modify the schema.

-- Read-only diagnostics for the live Supabase user-management setup.
-- Run in Supabase Dashboard > SQL Editor; results contain schema and counts,
-- not user emails, names, or authentication secrets.

-- 1) Actual profile and role columns.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('users', 'roles')
order by table_name, ordinal_position;

-- 2) RLS enabled/forced state for relevant tables.
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('users', 'roles');

-- 3) Policies that apply to user/profile and role rows.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename in ('users', 'roles')
order by tablename, policyname;

-- 4) Auth/profile triggers and their function bodies.
select trigger_ns.nspname as table_schema,
       table_class.relname as table_name,
       trigger_row.tgname as trigger_name,
       trigger_row.tgenabled as enabled_state,
       pg_get_triggerdef(trigger_row.oid) as trigger_definition,
       function_ns.nspname as function_schema,
       function_row.proname as function_name,
       pg_get_functiondef(function_row.oid) as function_definition
from pg_trigger trigger_row
join pg_class table_class on table_class.oid = trigger_row.tgrelid
join pg_namespace trigger_ns on trigger_ns.oid = table_class.relnamespace
join pg_proc function_row on function_row.oid = trigger_row.tgfoid
join pg_namespace function_ns on function_ns.oid = function_row.pronamespace
where not trigger_row.tgisinternal
  and ((trigger_ns.nspname = 'auth' and table_class.relname = 'users')
    or (trigger_ns.nspname = 'public' and table_class.relname = 'users'))
order by trigger_ns.nspname, table_class.relname, trigger_row.tgname;

-- 5) Constraints on public.users, including role and foreign-key constraints.
select con.conname as constraint_name,
       con.contype as constraint_type,
       pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class table_class on table_class.oid = con.conrelid
join pg_namespace table_ns on table_ns.oid = table_class.relnamespace
where table_ns.nspname = 'public' and table_class.relname = 'users'
order by con.contype, con.conname;

-- 6) Aggregate reconciliation only; no identifying fields are returned.
select
  (select count(*) from auth.users) as auth_user_count,
  (select count(*) from public.users) as profile_count,
  (select count(*) from auth.users a
   left join public.users p on p.id = a.id
   where p.id is null) as auth_users_without_profile,
  (select count(*) from public.users p
   left join auth.users a on a.id = p.id
   where a.id is null) as profiles_without_auth_user;
