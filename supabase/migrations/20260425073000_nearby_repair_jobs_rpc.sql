-- Engineer feed needs to filter open repair jobs by distance from the
-- engineer's home base. PostGIS / earthdistance aren't enabled in this
-- project, so we ship a pure-SQL haversine helper and an RPC that joins
-- repair_jobs → organizations to compute hospital→engineer distance.
--
-- Status filter: 'requested' + 'assigned' — what RepairJobStatus.OpenForEngineers
-- considers actionable from the feed.

create or replace function public.haversine_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
) returns double precision
language sql
immutable
parallel safe
set search_path = public
as $$
  select 6371.0 * 2 * asin(
    sqrt(
      sin(radians((lat2 - lat1) / 2)) ^ 2
      + cos(radians(lat1)) * cos(radians(lat2)) * sin(radians((lng2 - lng1) / 2)) ^ 2
    )
  )
$$;

comment on function public.haversine_km is
  'Great-circle distance in km between (lat1,lng1) and (lat2,lng2). '
  'No PostGIS dependency.';

create or replace function public.list_nearby_repair_jobs(
  p_radius_km double precision default 50,
  p_limit integer default 100
) returns table (
  id uuid,
  job_number text,
  hospital_user_id uuid,
  hospital_org_id uuid,
  equipment_brand text,
  equipment_model text,
  equipment_type text,
  urgency text,
  status text,
  issue_description text,
  scheduled_date date,
  scheduled_time_slot text,
  estimated_cost numeric,
  hospital_latitude double precision,
  hospital_longitude double precision,
  distance_km double precision,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  with me as (
    select e.latitude as lat, e.longitude as lng
    from public.engineers e
    where e.user_id = auth.uid()
    limit 1
  )
  select
    rj.id,
    rj.job_number,
    rj.hospital_user_id,
    rj.hospital_org_id,
    rj.equipment_brand,
    rj.equipment_model,
    rj.equipment_type::text,
    rj.urgency::text,
    rj.status::text,
    rj.issue_description,
    rj.scheduled_date,
    rj.scheduled_time_slot,
    rj.estimated_cost,
    o.latitude  as hospital_latitude,
    o.longitude as hospital_longitude,
    public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) as distance_km,
    rj.created_at
  from public.repair_jobs rj
  join public.organizations o on o.id = rj.hospital_org_id
  cross join me
  where rj.status::text in ('requested', 'assigned')
    and o.latitude is not null
    and o.longitude is not null
    and me.lat is not null
    and me.lng is not null
    and public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) <= p_radius_km
  order by distance_km asc, rj.created_at desc
  limit p_limit;
$$;

comment on function public.list_nearby_repair_jobs is
  'Engineer feed of open repair jobs within p_radius_km of the calling '
  'engineer''s registered base coords. Returns hospital coords + distance '
  'so the client can render markers + labels. RLS still applies via the '
  'underlying repair_jobs SELECT policy.';

grant execute on function public.list_nearby_repair_jobs(double precision, integer) to authenticated;
grant execute on function public.haversine_km(double precision, double precision, double precision, double precision) to authenticated;
