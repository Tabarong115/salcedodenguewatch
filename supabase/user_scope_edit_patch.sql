-- Allows admins to assign profile roles and scope IDs in separate Table Editor
-- saves while a profile remains inactive. Required assignments are enforced
-- together when active is set to true.
create or replace function public.enforce_user_role_scope()
returns trigger language plpgsql set search_path = '' as $$
declare selected_role public.roles%rowtype;
begin
  select * into selected_role from public.roles where id = new.role;
  if not found then raise exception 'Unknown user role'; end if;
  if new.active and new.role = 'pending' then
    raise exception 'Assign a non-pending role before activating this user';
  end if;

  if not new.active then
    if tg_op = 'UPDATE' and new.rhu_id is distinct from old.rhu_id then
      if new.facility_id is not null and not exists (
        select 1 from public.facilities f
        where f.id = new.facility_id and f.rhu_id = new.rhu_id
      ) then
        new.facility_id := null;
      end if;
      if new.barangay_id is not null and not exists (
        select 1 from public.barangays b
        where b.id = new.barangay_id and b.rhu_id = new.rhu_id
      ) then
        new.barangay_id := null;
      end if;
    end if;
    return new;
  end if;

  if selected_role.requires_rhu and new.rhu_id is null then
    raise exception 'RHU assignment is required for this role';
  end if;
  if selected_role.requires_facility and new.facility_id is null then
    raise exception 'Facility assignment is required for this role';
  end if;
  if selected_role.requires_barangay and new.barangay_id is null then
    raise exception 'Barangay assignment is required for this role';
  end if;

  if not selected_role.requires_rhu then
    new.rhu_id := null;
    new.facility_id := null;
    new.barangay_id := null;
  else
    if not selected_role.requires_facility then new.facility_id := null; end if;
    if not selected_role.requires_barangay then new.barangay_id := null; end if;
  end if;
  return new;
end;
$$;
