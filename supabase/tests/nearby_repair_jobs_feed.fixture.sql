-- Addendum fixture for nearby_repair_jobs_feed.test.mjs, applied after
-- engineer_location_privacy.fixture.sql. Adds the organizations table with the
-- production column-level lockdown (20260428120000: table SELECT revoked from
-- authenticated/anon; a column whitelist WITHOUT latitude/longitude granted to
-- authenticated) and the repair_jobs columns the feed returns. repair_jobs
-- itself is readable by authenticated here so that the previous (invoker)
-- definition can only fail for the reason under test: the coordinate columns.

CREATE TABLE public.organizations (
  id uuid PRIMARY KEY,
  name text,
  type text,
  city text,
  state text,
  logo_url text,
  latitude double precision,
  longitude double precision,
  created_by uuid
);
REVOKE ALL ON public.organizations FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, name, type, city, state, logo_url, created_by) ON public.organizations TO authenticated;
GRANT SELECT (id, name, type, city, state, logo_url) ON public.organizations TO anon;

ALTER TABLE public.repair_jobs
  ADD COLUMN hospital_org_id uuid,
  ADD COLUMN job_number text,
  ADD COLUMN equipment_brand text,
  ADD COLUMN equipment_model text,
  ADD COLUMN equipment_type text,
  ADD COLUMN urgency text,
  ADD COLUMN issue_description text,
  ADD COLUMN scheduled_date date,
  ADD COLUMN scheduled_time_slot text,
  ADD COLUMN estimated_cost numeric,
  ADD COLUMN created_at timestamptz DEFAULT now();
GRANT SELECT ON public.repair_jobs TO authenticated;
GRANT SELECT ON public.engineers TO authenticated;
