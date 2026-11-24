-- Restore/refresh the exact role options used by the app's Add/Edit User forms.
-- Safe to run repeatedly. This only changes public.roles; it does not change users.

insert into public.roles (
  id,
  display_name,
  requires_rhu,
  requires_facility,
  requires_barangay,
  is_admin,
  is_assignable
) values
  ('pending', 'Pending setup', false, false, false, false, false),
  ('admin', 'Administrator', false, false, false, true, true),
  ('rhu_staff', 'RHU Staff', true, false, false, false, true),
  ('hospital_staff', 'Hospital/Clinic Staff', true, true, false, false, true),
  ('encoder', 'Encoder', true, false, true, false, true),
  ('bhw', 'Barangay Health Worker', true, false, true, false, true),
  ('bsi', 'Barangay Surveillance Information Officer', true, false, true, false, true)
on conflict (id) do update set
  display_name = excluded.display_name,
  requires_rhu = excluded.requires_rhu,
  requires_facility = excluded.requires_facility,
  requires_barangay = excluded.requires_barangay,
  is_admin = excluded.is_admin,
  is_assignable = excluded.is_assignable;

select id, display_name, requires_rhu, requires_facility,
       requires_barangay, is_assignable
from public.roles
where id in ('pending', 'admin', 'rhu_staff', 'hospital_staff', 'encoder', 'bhw', 'bsi')
order by id;
