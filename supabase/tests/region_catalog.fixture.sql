-- Fixture for region_catalog.test.mjs, applied after
-- engineer_location_privacy.fixture.sql (roles, auth.uid(), profiles, engineers).
--
-- 1. Adds profiles.state/district exactly as round419 defines them (free text,
--    length 1..64), which the base fixture does not model.
-- 2. Models the production table grants the app relies on today (authenticated
--    may read and update its own profile and engineer rows; anon may read
--    engineers), per the 2026-09-18 catalogue baseline.
-- 3. Reproduces Supabase's default privileges: tables, sequences and functions
--    created afterwards are granted to anon and authenticated directly, so the
--    migration's explicit revokes are what keeps clients out.
-- 4. Inserts synthetic users only. No production data.

ALTER TABLE public.profiles
  ADD COLUMN state text CHECK (state IS NULL OR length(state) BETWEEN 1 AND 64),
  ADD COLUMN district text CHECK (district IS NULL OR length(district) BETWEEN 1 AND 64);

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.engineers TO authenticated;
GRANT SELECT ON public.engineers TO anon;
GRANT ALL ON public.profiles, public.engineers TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

-- Users for the RPC tests (state/district set later by the tests).
INSERT INTO public.profiles (id, full_name, role) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Home User', 'hospital_admin'),
  ('a0000000-0000-0000-0000-000000000002', 'Other User', 'hospital_admin'),
  ('b0000000-0000-0000-0000-000000000001', 'Engineer One', 'engineer'),
  ('b0000000-0000-0000-0000-000000000002', 'Engineer Two', 'engineer');
INSERT INTO public.engineers (id, user_id, state) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Alpha State'),
  ('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Beta Territory');

-- Legacy users written by older app versions (free-text labels).
INSERT INTO public.profiles (id, full_name, role, state, district) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'Legacy exact',          'hospital_admin', 'Alpha State', 'Northfield'),
  ('c0000000-0000-0000-0000-000000000002', 'Legacy abbreviation',   'hospital_admin', 'Alpha State', 'Northfield Dist.'),
  ('c0000000-0000-0000-0000-000000000003', 'Legacy renamed',        'hospital_admin', 'Alpha State', 'Old Riverton'),
  ('c0000000-0000-0000-0000-000000000004', 'Legacy other state',    'hospital_admin', 'Beta Territory', 'Northfield'),
  ('c0000000-0000-0000-0000-000000000005', 'Legacy ambiguous',      'hospital_admin', 'Alpha State', 'Lakeside'),
  ('c0000000-0000-0000-0000-000000000006', 'Legacy spacing',        'hospital_admin', '  alpha   STATE ', 'NORTHFIELD'),
  ('c0000000-0000-0000-0000-000000000007', 'Legacy unknown state',  'hospital_admin', 'Unknown State', 'Northfield'),
  ('c0000000-0000-0000-0000-000000000008', 'Legacy no labels',      'hospital_admin', NULL, NULL),
  ('c0000000-0000-0000-0000-000000000009', 'Legacy retired state',  'hospital_admin', 'Gamma Former State', 'Old Town'),
  ('c0000000-0000-0000-0000-000000000010', 'Legacy partial name',   'hospital_admin', 'Alpha State', 'North'),
  ('c0000000-0000-0000-0000-000000000011', 'Legacy partial state',  'hospital_admin', 'Alpha', 'Northfield'),
  ('c0000000-0000-0000-0000-000000000012', 'Legacy engineer',       'engineer',       'Alpha State', 'Riverton'),
  ('c0000000-0000-0000-0000-000000000013', 'Legacy engineer no st', 'engineer',       NULL, NULL);
INSERT INTO public.engineers (id, user_id, state, city, service_areas) VALUES
  ('e0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000012', 'Alpha State', 'Riverton, Alpha State',
     ARRAY['Northfield', 'Riverton', 'Hill crest']),
  ('e0000000-0000-0000-0000-000000000013', 'c0000000-0000-0000-0000-000000000013', NULL, NULL,
     ARRAY['Northfield']);
