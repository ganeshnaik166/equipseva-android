-- Clamp p_radius_km + p_limit in list_nearby_repair_jobs so a hostile
-- client can't enumerate the full repair-jobs directory via a giant
-- radius (e.g. p_radius_km=99999) and expensive haversine scan over
-- every row.
--
-- Original definition (20260425073000): no caps. Client controls the
-- entire bound — the LIMIT is also client-provided. RLS still gates
-- which rows can be SELECTed, but the per-row haversine evaluation
-- and the response payload size scale with the unbounded params.
--
-- This migration re-creates the function with `LEAST(...)` clamps:
--   p_radius_km → clamped to 500 km (covers all of India + buffer)
--   p_limit     → clamped to 200 rows (matches client's typical pager)

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
  ), bounds as (
    -- Clamp client-supplied params. 500 km comfortably covers India's
    -- longest engineer travel commitments without exposing the full
    -- directory; 200 rows matches the client's typical paging size.
    select
      greatest(1::double precision, least(coalesce(p_radius_km, 50), 500))   as radius_km,
      greatest(1, least(coalesce(p_limit, 100), 200))                         as row_limit
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
  cross join bounds
  where rj.status::text in ('requested', 'assigned')
    and o.latitude is not null
    and o.longitude is not null
    and me.lat is not null
    and me.lng is not null
    and public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) <= bounds.radius_km
  order by distance_km asc, rj.created_at desc
  limit (select row_limit from bounds);
$$;

comment on function public.list_nearby_repair_jobs is
  'Engineer feed of open repair jobs within p_radius_km of the calling '
  'engineer''s registered base coords. p_radius_km clamped to 500 km and '
  'p_limit clamped to 200 rows server-side so a client can''t enumerate '
  'the full directory via giant params.';
