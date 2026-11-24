-- Public activity-map support for an existing Salcedo Dengue Watch database.
-- Run this file in Supabase SQL Editor. It does not recreate the schema or
-- change case access policies. Safe to rerun.

begin;

-- Ensure the privacy-grid columns exist on deployments that predate them.
alter table public.cases
  add column if not exists public_grid_lat double precision,
  add column if not exists public_grid_lng double precision;

-- Keep public coordinates rounded to roughly 100 m. Exact case coordinates
-- stay in public.cases, which remains unavailable to anonymous clients.
create or replace function public.set_case_public_grid()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.latitude is not null and new.longitude is not null then
    new.public_grid_lat := round(new.latitude::numeric, 3)::double precision;
    new.public_grid_lng := round(new.longitude::numeric, 3)::double precision;
  else
    new.public_grid_lat := null;
    new.public_grid_lng := null;
  end if;
  return new;
end;
$$;

drop trigger if exists cases_set_public_grid on public.cases;
create trigger cases_set_public_grid
before insert or update of latitude, longitude on public.cases
for each row execute function public.set_case_public_grid();

-- Populate rounded coordinates for existing cases without changing their
-- exact coordinates or case timestamps.
update public.cases
set public_grid_lat = round(latitude::numeric, 3)::double precision,
    public_grid_lng = round(longitude::numeric, 3)::double precision
where latitude is not null
  and longitude is not null
  and (public_grid_lat is distinct from round(latitude::numeric, 3)::double precision
    or public_grid_lng is distinct from round(longitude::numeric, 3)::double precision);

update public.cases
set public_grid_lat = null,
    public_grid_lng = null
where (latitude is null or longitude is null)
  and (public_grid_lat is not null or public_grid_lng is not null);

-- Each visible marker represents at least five submitted cases for that day,
-- coarse grid cell, barangay, and display category. No patient identifier or
-- exact location is exposed by this view.
create or replace view public.public_case_map_summary
with (security_barrier = true) as
select c.report_date::date as case_day,
       c.public_grid_lat as latitude,
       c.public_grid_lng as longitude,
       c.barangay,
       case
         when c.outcome = 'death' then 'death'
         when c.classification = 'confirmed'
           or c.status in ('pending', 'investigation') then 'active'
         else 'probable'
       end as map_category,
       count(*)::integer as case_count
from public.cases c
where c.is_submitted
  and c.report_date is not null
  and c.public_grid_lat is not null
  and c.public_grid_lng is not null
group by c.report_date::date,
         c.public_grid_lat,
         c.public_grid_lng,
         c.barangay,
         case
           when c.outcome = 'death' then 'death'
           when c.classification = 'confirmed'
             or c.status in ('pending', 'investigation') then 'active'
           else 'probable'
         end
having count(*) >= 5;

revoke all on public.public_case_map_summary from anon, authenticated;
grant select on public.public_case_map_summary to anon, authenticated;

commit;
