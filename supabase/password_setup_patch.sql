-- Apply this once to an already-created project so invited, inactive users can
-- finish choosing a password before an administrator activates their profile.
create or replace function public.complete_user_setup()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.users
  set password_setup_required = false
  where id = (select auth.uid()) and (active or password_setup_required);
  if not found then raise exception 'User profile is not eligible to complete setup'; end if;
end;
$$;

revoke all on function public.complete_user_setup() from public, anon;
grant execute on function public.complete_user_setup() to authenticated;
