-- Public dashboard shows complete municipality-level case totals. Barangay
-- breakdowns and map markers remain privacy-suppressed below three cases.
-- Public map markers are aggregated per barangay, never returned per case.

begin;

create or replace function public.get_public_dashboard_summary()
returns table (
  total_cases integer,
  affected_barangays integer,
  registered_barangays integer,
  this_week_cases integer,
  this_week_affected_barangays integer,
  has_this_week_data boolean,
  has_reportable_data boolean,
  week_starting date
)
language sql
stable
security definer
set search_path = ''
as $$
  with eligible_cases as (
    select c.barangay,
           date_trunc('week', c.report_date at time zone 'UTC')::date as week_starting
    from public.cases c
    where c.is_submitted
      and c.is_duplicate_of is null
      and c.report_date is not null
  ),
  weekly_counts as (
    select e.barangay, e.week_starting, count(*)::integer as case_count
    from eligible_cases e
    group by e.barangay, e.week_starting
  ),
  current_week as (
    select date_trunc('week', now() at time zone 'UTC')::date as week_starting
  )
  select
    (select count(*)::integer from eligible_cases),
    (select count(distinct w.barangay)::integer from weekly_counts w where w.case_count >= 3),
    (select count(*)::integer from public.barangays),
    (select count(*)::integer from eligible_cases e where e.week_starting = (select c.week_starting from current_week c)),
    (select count(distinct w.barangay)::integer from weekly_counts w
      where w.week_starting = (select c.week_starting from current_week c) and w.case_count >= 3),
    exists (select 1 from eligible_cases e where e.week_starting = (select c.week_starting from current_week c)),
    exists (select 1 from eligible_cases),
    (select c.week_starting from current_week c);
$$;

revoke all on function public.get_public_dashboard_summary() from public, anon, authenticated;
grant execute on function public.get_public_dashboard_summary() to anon, authenticated;

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
  with eligible_cases as (
    select c.barangay_id, c.barangay, c.latitude, c.longitude,
           b.latitude as barangay_latitude, b.longitude as barangay_longitude
    from public.cases c
    left join public.barangays b on b.id = c.barangay_id
    where c.is_submitted
      and c.is_duplicate_of is null
      and c.report_date is not null
      and (p_start_date is null or (c.report_date at time zone 'UTC')::date >= p_start_date)
      and (p_end_date is null or (c.report_date at time zone 'UTC')::date < p_end_date)
      and (p_barangay is null or c.barangay = p_barangay)
      and ((b.latitude is not null and b.longitude is not null)
        or (c.latitude is not null and c.longitude is not null))
  ),
  barangay_groups as (
    select
      coalesce(max(e.barangay_latitude), round(avg(e.latitude)::numeric / 0.01) * 0.01)::double precision as latitude,
      coalesce(max(e.barangay_longitude), round(avg(e.longitude)::numeric / 0.01) * 0.01)::double precision as longitude,
      e.barangay,
      count(*)::integer as case_count
    from eligible_cases e
    group by e.barangay_id, e.barangay
    having count(*) >= 3
  )
  select g.latitude, g.longitude, g.barangay, 'public_cluster'::text, g.case_count
  from barangay_groups g;
$$;

revoke all on function public.get_public_case_map(date, date, text)
  from public, anon, authenticated;
grant execute on function public.get_public_case_map(date, date, text)
  to anon, authenticated;

commit;
