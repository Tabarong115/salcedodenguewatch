-- Give active RHU staff municipal-wide access to operational records.
-- This deployment serves Salcedo municipality; RHU staff are the clinical
-- authority across all barangays, whether or not each row has an RHU link.
-- Admin remains the separate authority for app and organization management.

create or replace function public.can_access_barangay(
  target_id uuid,
  target_name text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or (
      public.current_user_role() in ('encoder', 'bhw', 'bsi')
      and target_id = public.current_user_barangay_id()
    )
    or (
      public.current_user_role() = 'hospital_staff'
      and exists (
        select 1
        from public.facilities f
        where f.id = public.current_user_facility_id()
          and (
            (target_id is not null and f.barangay_id = target_id)
            or (target_name is not null and f.barangay = target_name)
          )
      )
    )
    or public.current_user_role() = 'rhu_staff';
$$;

grant execute on function public.can_access_barangay(uuid, text) to authenticated;
revoke all on function public.can_access_barangay(uuid, text) from public, anon;

-- RHU dashboard filters and municipal map views need the full directory too.
drop policy if exists barangays_rhu_staff_read on public.barangays;
create policy barangays_rhu_staff_read on public.barangays
  for select to authenticated
  using (public.current_user_role() = 'rhu_staff');
