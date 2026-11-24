-- Activity-map and case-outcome alignment for an existing database.
-- Run this file in Supabase SQL Editor on an existing app database.

begin;

-- Remove the earlier public map relation. The replacement function below
-- groups cases for the selected period and rounds locations more coarsely.
drop view if exists public.public_case_map_summary;

-- Barangay choices are public metadata and must not depend on whether the
-- current period contains any case clusters.
create or replace view public.public_barangay_names
with (security_barrier = true) as
select b.id, b.name
from public.barangays b;

revoke all on public.public_barangay_names from anon, authenticated;
grant select on public.public_barangay_names to anon, authenticated;

-- Return only rounded, sufficiently large clusters. The date filter is applied
-- before aggregation, so day/week/month/year counts reflect the entire chosen
-- period rather than requiring every case to be reported on the same day.
create or replace function public.get_public_case_map(
  p_start_date date default null,
  p_end_date date default null,
  p_barangay text default null
)
returns table (
  latitude double precision,
  longitude double precision,
  barangay text,
  map_category text,
  case_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (round((c.latitude::numeric / 0.005)) * 0.005)::double precision as latitude,
    (round((c.longitude::numeric / 0.005)) * 0.005)::double precision as longitude,
    c.barangay,
    case
      when c.outcome = 'death' then 'death'
      when c.outcome = 'recovered' then 'recovered'
      when c.outcome = 'ongoing' or c.classification = 'confirmed' then 'active'
      when c.status = 'closed' then 'resolved'
      else 'probable'
    end as map_category,
    count(*)::integer as case_count
  from public.cases c
  where c.is_submitted
    and c.is_duplicate_of is null
    and c.latitude is not null
    and c.longitude is not null
    and c.report_date is not null
    and (p_start_date is null or c.report_date::date >= p_start_date)
    and (p_end_date is null or c.report_date::date < p_end_date)
    and (p_barangay is null or c.barangay = p_barangay)
  group by 1, 2, 3, 4
  having count(*) >= 3;
$$;

revoke all on function public.get_public_case_map(date, date, text)
  from public, anon, authenticated;
grant execute on function public.get_public_case_map(date, date, text)
  to anon, authenticated;

-- Case updates remain protected by the existing row-level policies.
grant update (status, outcome, outcome_date) on public.cases to authenticated;

commit;
