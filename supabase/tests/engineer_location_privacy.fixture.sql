-- Minimal fixture for engineer_location_privacy.test.mjs.
--
-- Recreates only the objects the four functions under test read, with the
-- same column names and compatible types as production. Helper bodies
-- (haversine_km, engineer_address_public, is_admin) are copied from their
-- latest migrations; is_founder() models the production email check.
-- No production data: every row is synthetic.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE OR REPLACE FUNCTION auth.email() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.email', true), '')
$$;
GRANT EXECUTE ON FUNCTION auth.uid(), auth.email() TO anon, authenticated, service_role;

CREATE TYPE public.verification_status AS ENUM ('pending', 'verified', 'rejected');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  full_name text,
  avatar_url text,
  phone text,
  email text,
  role text,
  roles text[],
  active_role text
);

CREATE TABLE public.engineers (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id),
  city text,
  state text,
  service_areas text[],
  specializations text[],
  brands_serviced text[],
  oem_training_badges text[],
  experience_years int,
  years_experience int,
  rating_avg numeric,
  total_jobs int,
  hourly_rate numeric,
  bio text,
  is_available boolean,
  latitude double precision,
  longitude double precision,
  completion_rate numeric,
  verification_status public.verification_status,
  service_radius_km int
);

CREATE TABLE public.engineer_certification_progress (
  engineer_user_id uuid PRIMARY KEY,
  current_tier text
);

CREATE TABLE public.repair_jobs (
  id uuid PRIMARY KEY,
  hospital_user_id uuid,
  engineer_id uuid,
  status text,
  site_latitude double precision,
  site_longitude double precision
);

CREATE TABLE public.repair_job_bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL,
  engineer_user_id uuid NOT NULL,
  amount_rupees numeric,
  eta_hours int,
  note text,
  status text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.chat_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_user_ids uuid[]
);

-- haversine_km — body from 20260425073000_nearby_repair_jobs_rpc.sql
CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) RETURNS double precision
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public
AS $$
  select 6371.0 * 2 * asin(
    sqrt(
      sin(radians((lat2 - lat1) / 2)) ^ 2
      + cos(radians(lat1)) * cos(radians(lat2)) * sin(radians((lng2 - lng1) / 2)) ^ 2
    )
  )
$$;

-- engineer_address_public — body from 20260625110000_v21_engineer_address_public_sanitize.sql
CREATE OR REPLACE FUNCTION public.engineer_address_public(addr text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp
AS $$
DECLARE
  v_parts text[];
  v_len int;
BEGIN
  IF addr IS NULL OR btrim(addr) = '' THEN
    RETURN addr;
  END IF;
  v_parts := string_to_array(addr, ',');
  v_len := array_length(v_parts, 1);
  IF v_len IS NULL OR v_len <= 2 THEN
    RETURN btrim(addr);
  END IF;
  RETURN btrim(v_parts[v_len - 1]) || ', ' || btrim(v_parts[v_len]);
END;
$$;
GRANT EXECUTE ON FUNCTION public.engineer_address_public(text) TO authenticated, anon;

-- is_founder — models production: the founder is identified by account email.
CREATE OR REPLACE FUNCTION public.is_founder() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$ SELECT coalesce(lower(auth.email()) = 'founder@fixture.test', false) $$;

-- is_admin — body from 20263866000000_round3766_is_admin_founder_selfcheck_widening.sql
CREATE OR REPLACE FUNCTION public.is_admin(uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = uid AND role = 'admin'
  )
  OR (uid = auth.uid() AND public.is_founder());
$$;
