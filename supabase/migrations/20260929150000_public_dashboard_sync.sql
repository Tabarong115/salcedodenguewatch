-- Rebuild the public dashboard summary for the current case schema.
-- Run in SQL Editor for an existing database; do not run setup.sql here.

begin;

drop view if exists public.public_cases_summary;

create view public.public_cases_summary
with (security_barrier = true) as
select c.barangay,
       date_trunc('week', c.report_date)::date as week_starting,
       count(*)::integer as case_count,
       case
         when count(*) filter (where c.classification = 'confirmed') >= 3
         then count(*) filter (where c.classification = 'confirmed')::integer
         else null
       end as confirmed_count,
       false as is_suppressed
from public.cases c
where c.is_submitted
  and c.is_duplicate_of is null
  and c.report_date is not null
group by c.barangay, date_trunc('week', c.report_date)
having count(*) >= 3;

revoke all on public.public_cases_summary from anon, authenticated;
grant select on public.public_cases_summary to anon, authenticated;

-- Dashboard also reports the number of configured barangays even when their
-- weekly case totals are below the public reporting threshold.
create or replace view public.public_barangay_names
with (security_barrier = true) as
select b.id, b.name
from public.barangays b;

revoke all on public.public_barangay_names from anon, authenticated;
grant select on public.public_barangay_names to anon, authenticated;

commit;
