-- F-01 server fix: list_nearby_repair_jobs leaked Postgres "permission denied
-- for table organizations" to the engineer Repair tab. Lockdown migration
-- 20260428120000 revoked broad SELECT on public.organizations and granted only
-- a column whitelist that excludes latitude/longitude. The RPC's join into
-- organizations under SECURITY INVOKER therefore failed for every authenticated
-- caller, and the raw error bubbled up to the UI banner.
--
-- Switch the RPC to SECURITY DEFINER so it can read org coords directly.
-- That bypasses RLS on repair_jobs too, so we replicate the engineer
-- visibility rule explicitly in the WHERE clause: open requests are visible
-- to every engineer; assigned jobs are only visible to the engineer they're
-- assigned to. This matches the original RLS:
--   - "Engineers can view open repair jobs" (status='requested' AND engineer)
--   - "Repair jobs viewable by involved parties" (engineer_id = my engineer)

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
security definer
set search_path = public, pg_temp
as $$
  with me as (
    select e.id as engineer_id, e.latitude as lat, e.longitude as lng
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
  where me.lat is not null
    and me.lng is not null
    and o.latitude is not null
    and o.longitude is not null
    and (
      rj.status::text = 'requested'
      or (rj.status::text = 'assigned' and rj.engineer_id = me.engineer_id)
    )
    and public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) <= p_radius_km
  order by distance_km asc, rj.created_at desc
  limit p_limit;
$$;

comment on function public.list_nearby_repair_jobs is
  'Engineer feed of open repair jobs within p_radius_km of the calling '
  'engineer''s registered base coords. SECURITY DEFINER so it can read '
  'org coords past the column-level lockdown on public.organizations; '
  'visibility rule (open + own-assigned) is replicated in WHERE since '
  'DEFINER bypasses repair_jobs RLS.';

revoke all on function public.list_nearby_repair_jobs(double precision, integer) from public, anon;
grant execute on function public.list_nearby_repair_jobs(double precision, integer) to authenticated;
