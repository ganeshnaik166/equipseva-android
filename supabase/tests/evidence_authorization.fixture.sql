-- Focused disposable PostgreSQL fixture, never a deployment migration.
-- Only the columns used by the exact evidence RPCs and canonical writer are
-- modeled. This is not a replay of the complete Supabase migration history.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE SCHEMA storage;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO anon, authenticated, service_role;
-- Reproduce Supabase's broad default EXECUTE grants, so missing revokes fail.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.role', true), '')
$$;
CREATE FUNCTION public.is_founder() RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT coalesce(auth.uid() = '10000000-0000-0000-0000-000000000005'::uuid, false)
$$;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users(id) SELECT ('10000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid
  FROM generate_series(1,8) n;

CREATE TABLE public.engineers(
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE
);
INSERT INTO public.engineers VALUES
  ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003'),
  ('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004');

CREATE TABLE public.repair_jobs(
  id uuid PRIMARY KEY,
  hospital_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  engineer_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  before_photos text[],
  after_photos text[],
  status text NOT NULL DEFAULT 'assigned'
);
-- 1: canonical engineer 3. 2: no-bid/unassigned. 3: AMC/direct-assigned
-- engineer 3 with NO accepted bid. 4: reassigned to engineer 4 with stale
-- accepted bid for engineer 3. 5: cleared assignment with stale accepted bid.
INSERT INTO public.repair_jobs(id,hospital_user_id,engineer_id) VALUES
  ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001',NULL),
  ('30000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002'),
  ('30000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001',NULL);
CREATE TABLE public.repair_job_bids(
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  repair_job_id uuid REFERENCES public.repair_jobs(id),
  engineer_user_id uuid REFERENCES auth.users(id),
  status text
);
INSERT INTO public.repair_job_bids(repair_job_id,engineer_user_id,status)
SELECT id, '10000000-0000-0000-0000-000000000003', 'accepted'
  FROM public.repair_jobs WHERE id::text IN (
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000005'
  );
CREATE TABLE storage.objects(
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  bucket_id text NOT NULL,
  name text NOT NULL,
  owner uuid,
  owner_id text,
  metadata jsonb,
  UNIQUE(bucket_id,name)
);

-- The fixture tables are private to the definer just as these RPCs expect;
-- direct authenticated table access cannot stand in for an RPC allow test.
ALTER TABLE public.repair_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_job_bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON storage.objects TO authenticated;
