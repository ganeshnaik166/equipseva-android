-- Round 3830 — region catalogue v1: State/UT and district codes, server
-- validation, and the home-region and service-district write paths.
--
-- PRODUCT_PLAN §6 / delivery ledger P2.2: location is India -> State/UT ->
-- district. Records persist stable codes plus the catalogue version they were
-- chosen from; names are labels only. Fuzzy or substring matching never
-- decides anything; ambiguous or unknown legacy text needs confirmation.
--
-- What this migration adds (new objects only):
--   * public read-only catalogue: region_catalog_versions, region_states,
--     region_districts, region_district_aliases;
--   * profile_regions (a user's home State/UT + district) and
--     engineer_service_districts (an engineer's explicit coverage, which may
--     span states): own-row SELECT only, written through the RPCs below,
--     ON DELETE CASCADE from the profile/engineer row so they never block
--     account deletion;
--   * region_resolution_queue: legacy labels that did not resolve exactly; no
--     client access;
--   * RPCs region_catalog_current(), set_my_home_region(),
--     set_my_service_districts(), my_region_profile(), and the service-only
--     region_legacy_backfill_report(p_apply), which returns counts only.
--
-- Deliberately NOT done here:
--   * No catalogue rows are seeded. District codes come only from a dated,
--     owner-approved LGD snapshot through a later generated seed migration.
--     Until then region_catalog_current() reports no current version and the
--     write RPCs refuse every version (region_catalog_version_unsupported).
--   * No table, column, trigger, policy, grant or enum is added to or changed
--     on profiles or engineers. Legacy text written directly by older app
--     versions is resolved inside my_region_profile() (read-only preview, with
--     a stale flag) and by region_legacy_backfill_report(), not by a trigger.
--   * No directory, job-feed, nearby, attendance, deletion or export function
--     changes. engineers.service_radius_km, latitude and longitude are not
--     touched.
--
-- The write RPCs keep the legacy label columns in sync: set_my_home_region
-- mirrors the chosen names into profiles.state/district, and
-- set_my_service_districts mirrors the chosen names into
-- engineers.service_areas, which existing readers still use.
--
-- Grants: the project's default privileges grant new tables and functions to
-- anon and authenticated directly (round3791), so every object below is
-- revoked from PUBLIC, anon and authenticated first and then granted
-- explicitly. The trailing DO block re-checks the result and aborts the whole
-- migration if any grant, RLS flag or function shape is not as intended.
--
-- Idempotent and forward-only. Proven locally by
-- supabase/tests/region_catalog.test.mjs (PGlite, synthetic catalogue).
-- Not applied to any Supabase project by this commit.
BEGIN;

-- ---------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.region_catalog_versions (
  version         text PRIMARY KEY CHECK (version ~ '^[a-z0-9][a-z0-9._-]{2,63}$'),
  source_url      text NOT NULL CHECK (length(source_url) BETWEEN 1 AND 500),
  retrieved_on    date NOT NULL,
  sha256          text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  is_current      boolean NOT NULL DEFAULT false,
  accepts_writes  boolean NOT NULL DEFAULT true,
  is_synthetic    boolean NOT NULL DEFAULT false,
  imported_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT is_current OR accepts_writes)
);
CREATE UNIQUE INDEX IF NOT EXISTS region_catalog_versions_one_current
  ON public.region_catalog_versions ((true)) WHERE is_current;

CREATE TABLE IF NOT EXISTS public.region_states (
  code           text PRIMARY KEY CHECK (code ~ '^[0-9]{1,3}$'),
  name_en        text NOT NULL CHECK (length(name_en) BETWEEN 1 AND 64),
  kind           text NOT NULL CHECK (kind IN ('state', 'union_territory')),
  active         boolean NOT NULL DEFAULT true,
  introduced_in  text REFERENCES public.region_catalog_versions(version),
  retired_in     text REFERENCES public.region_catalog_versions(version),
  CHECK (active = (retired_in IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS region_states_active_name
  ON public.region_states (lower(name_en)) WHERE active;

CREATE TABLE IF NOT EXISTS public.region_districts (
  code           text PRIMARY KEY CHECK (code ~ '^[0-9]{1,6}$'),
  state_code     text NOT NULL REFERENCES public.region_states(code),
  name_en        text NOT NULL CHECK (length(name_en) BETWEEN 1 AND 64),
  active         boolean NOT NULL DEFAULT true,
  introduced_in  text REFERENCES public.region_catalog_versions(version),
  retired_in     text REFERENCES public.region_catalog_versions(version),
  replaced_by    text[] NOT NULL DEFAULT '{}',
  CHECK (active = (retired_in IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS region_districts_active_state_name
  ON public.region_districts (state_code, lower(name_en)) WHERE active;
CREATE INDEX IF NOT EXISTS region_districts_state_idx
  ON public.region_districts (state_code);

CREATE TABLE IF NOT EXISTS public.region_district_aliases (
  state_code        text NOT NULL REFERENCES public.region_states(code),
  alias_normalized  text NOT NULL CHECK (length(alias_normalized) BETWEEN 1 AND 64),
  district_code     text NOT NULL REFERENCES public.region_districts(code),
  kind              text NOT NULL CHECK (kind IN ('official', 'legacy_bundled', 'renamed', 'common_spelling')),
  added_in          text REFERENCES public.region_catalog_versions(version),
  PRIMARY KEY (state_code, alias_normalized, district_code)
);

-- ---------------------------------------------------------------------
-- Per-user records
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profile_regions (
  user_id                uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  state_code             text REFERENCES public.region_states(code),
  district_code          text REFERENCES public.region_districts(code),
  catalog_version        text NOT NULL REFERENCES public.region_catalog_versions(version),
  status                 text NOT NULL CHECK (status IN ('resolved', 'needs_confirmation')),
  source                 text NOT NULL CHECK (source IN ('user', 'legacy_backfill')),
  legacy_state_label     text,
  legacy_district_label  text,
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CHECK (status <> 'resolved' OR (state_code IS NOT NULL AND district_code IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.engineer_service_districts (
  engineer_id      uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  district_code    text NOT NULL REFERENCES public.region_districts(code),
  catalog_version  text NOT NULL REFERENCES public.region_catalog_versions(version),
  source           text NOT NULL CHECK (source IN ('engineer', 'legacy_backfill')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (engineer_id, district_code)
);

CREATE TABLE IF NOT EXISTS public.region_resolution_queue (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_kind        text NOT NULL CHECK (subject_kind IN ('profile_home', 'engineer_service')),
  subject_user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  raw_state_label     text,
  raw_district_label  text,
  reason              text NOT NULL CHECK (reason IN ('state_unknown', 'no_match', 'ambiguous')),
  candidate_codes     text[] NOT NULL DEFAULT '{}',
  catalog_version     text NOT NULL REFERENCES public.region_catalog_versions(version),
  status              text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
  created_at          timestamptz NOT NULL DEFAULT now(),
  resolved_at         timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS region_resolution_queue_one_open
  ON public.region_resolution_queue
     (subject_kind, subject_user_id, coalesce(raw_state_label, ''), coalesce(raw_district_label, ''))
  WHERE status = 'open';

-- ---------------------------------------------------------------------
-- RLS and table grants
-- ---------------------------------------------------------------------

ALTER TABLE public.region_catalog_versions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.region_states              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.region_districts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.region_district_aliases    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_regions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_service_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.region_resolution_queue    ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.region_catalog_versions, public.region_states, public.region_districts,
              public.region_district_aliases, public.profile_regions,
              public.engineer_service_districts, public.region_resolution_queue
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.region_resolution_queue_id_seq FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.region_catalog_versions, public.region_states, public.region_districts,
                public.region_district_aliases
  TO anon, authenticated, service_role;
GRANT SELECT ON public.profile_regions, public.engineer_service_districts TO authenticated, service_role;
GRANT SELECT ON public.region_resolution_queue TO service_role;

DROP POLICY IF EXISTS region_catalog_versions_read ON public.region_catalog_versions;
CREATE POLICY region_catalog_versions_read ON public.region_catalog_versions
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS region_states_read ON public.region_states;
CREATE POLICY region_states_read ON public.region_states
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS region_districts_read ON public.region_districts;
CREATE POLICY region_districts_read ON public.region_districts
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS region_district_aliases_read ON public.region_district_aliases;
CREATE POLICY region_district_aliases_read ON public.region_district_aliases
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS profile_regions_own_read ON public.profile_regions;
CREATE POLICY profile_regions_own_read ON public.profile_regions
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS engineer_service_districts_own_read ON public.engineer_service_districts;
CREATE POLICY engineer_service_districts_own_read ON public.engineer_service_districts
  FOR SELECT TO authenticated
  USING (engineer_id IN (SELECT e.id FROM public.engineers e WHERE e.user_id = auth.uid()));

COMMENT ON TABLE public.region_catalog_versions IS
  'round3830: one row per imported region catalogue snapshot (source, date, checksum). At most one is_current; accepts_writes=false retires a version for new selections. Seeded only by generated, owner-approved migrations.';
COMMENT ON TABLE public.profile_regions IS
  'round3830: a user''s home State/UT + district as codes plus the catalogue version. Written only by set_my_home_region / region_legacy_backfill_report; legacy_*_label keep the label text as it was when the row was written.';
COMMENT ON TABLE public.engineer_service_districts IS
  'round3830: an engineer''s explicit service districts (may span states). Written only by set_my_service_districts / region_legacy_backfill_report. Not yet read by any feed or directory.';
COMMENT ON TABLE public.region_resolution_queue IS
  'round3830: legacy labels that did not resolve to exactly one code. No client access; reviewed by operators.';

-- ---------------------------------------------------------------------
-- Internal helpers (owner-only; called from the functions below)
-- ---------------------------------------------------------------------

-- Exact-match normalisation: case, surrounding and repeated whitespace only.
-- Punctuation, abbreviations ("Dist.") and partial names are NOT folded.
CREATE OR REPLACE FUNCTION public.region_normalize_label(p_label text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
  SELECT nullif(lower(btrim(regexp_replace(coalesce(p_label, ''), '\s+', ' ', 'g'))), '')
$$;

-- The single current catalogue version, or NULL before any seed.
CREATE OR REPLACE FUNCTION public.region_current_version()
RETURNS text
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT v.version FROM public.region_catalog_versions v WHERE v.is_current
$$;

-- Active State/UT whose name matches exactly after normalisation, or NULL.
CREATE OR REPLACE FUNCTION public.region_resolve_state_label(p_label text)
RETURNS text
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN count(*) = 1 THEN min(s.code) END
    FROM public.region_states s
   WHERE s.active
     AND public.region_normalize_label(s.name_en) = public.region_normalize_label(p_label)
$$;

-- Active district codes in one State/UT whose current name or an alias
-- matches exactly after normalisation. Never looks outside p_state_code.
CREATE OR REPLACE FUNCTION public.region_district_candidates(p_state_code text, p_label text)
RETURNS text[]
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  WITH n AS (SELECT public.region_normalize_label(p_label) AS label)
  SELECT coalesce(array_agg(DISTINCT c.code ORDER BY c.code), '{}')
    FROM (
      SELECT d.code
        FROM public.region_districts d, n
       WHERE d.state_code = p_state_code AND d.active
         AND public.region_normalize_label(d.name_en) = n.label
      UNION
      SELECT d.code
        FROM public.region_district_aliases a
        JOIN public.region_districts d ON d.code = a.district_code
        CROSS JOIN n
       WHERE a.state_code = p_state_code AND d.state_code = p_state_code AND d.active
         AND a.alias_normalized = n.label
    ) c
$$;

-- Validates that p_catalog_version may be used for a new selection.
CREATE OR REPLACE FUNCTION public.region_require_writable_version(p_catalog_version text)
RETURNS void
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_catalog_version IS NULL OR NOT EXISTS (
       SELECT 1 FROM public.region_catalog_versions v
        WHERE v.version = p_catalog_version AND v.accepts_writes) THEN
    RAISE EXCEPTION 'region_catalog_version_unsupported' USING ERRCODE = '22023';
  END IF;
END;
$$;

-- Exact resolution of one legacy State/district label pair (no writes).
-- status: resolved | needs_confirmation | empty.
CREATE OR REPLACE FUNCTION public.region_resolve_legacy_pair(p_state_label text, p_district_label text)
RETURNS TABLE(status text, state_code text, district_code text, reason text, candidate_codes text[])
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_state text;
  v_candidates text[];
BEGIN
  IF public.region_normalize_label(p_state_label) IS NULL
     AND public.region_normalize_label(p_district_label) IS NULL THEN
    RETURN QUERY SELECT 'empty'::text, NULL::text, NULL::text, NULL::text, '{}'::text[];
    RETURN;
  END IF;
  v_state := public.region_resolve_state_label(p_state_label);
  IF v_state IS NULL THEN
    RETURN QUERY SELECT 'needs_confirmation'::text, NULL::text, NULL::text, 'state_unknown'::text, '{}'::text[];
    RETURN;
  END IF;
  v_candidates := public.region_district_candidates(v_state, p_district_label);
  IF cardinality(v_candidates) = 1 THEN
    RETURN QUERY SELECT 'resolved'::text, v_state, v_candidates[1], NULL::text, v_candidates;
  ELSIF cardinality(v_candidates) = 0 THEN
    RETURN QUERY SELECT 'needs_confirmation'::text, v_state, NULL::text, 'no_match'::text, v_candidates;
  ELSE
    RETURN QUERY SELECT 'needs_confirmation'::text, v_state, NULL::text, 'ambiguous'::text, v_candidates;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------
-- Client RPCs
-- ---------------------------------------------------------------------

-- The catalogue version the server accepts for new selections.
CREATE OR REPLACE FUNCTION public.region_catalog_current()
RETURNS TABLE(current_version text, supported_versions text[], is_synthetic boolean,
              state_count integer, district_count integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT (SELECT v.version FROM public.region_catalog_versions v WHERE v.is_current),
         coalesce((SELECT array_agg(v.version ORDER BY v.version)
                     FROM public.region_catalog_versions v WHERE v.accepts_writes), '{}'),
         coalesce((SELECT v.is_synthetic FROM public.region_catalog_versions v WHERE v.is_current), false),
         (SELECT count(*)::integer FROM public.region_states s WHERE s.active),
         (SELECT count(*)::integer FROM public.region_districts d WHERE d.active);
END;
$$;

-- Sets the caller's home State/UT + district from codes and mirrors the
-- names into profiles.state/district.
CREATE OR REPLACE FUNCTION public.set_my_home_region(
  p_state_code text, p_district_code text, p_catalog_version text
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_state public.region_states%ROWTYPE;
  v_district public.region_districts%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  PERFORM public.region_require_writable_version(p_catalog_version);

  SELECT * INTO v_state FROM public.region_states s WHERE s.code = p_state_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_district FROM public.region_districts d WHERE d.code = p_district_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  IF NOT v_district.active THEN
    RAISE EXCEPTION 'region_district_retired' USING ERRCODE = '22023';
  END IF;
  IF NOT v_state.active OR v_district.state_code <> v_state.code THEN
    RAISE EXCEPTION 'region_pair_invalid' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid) THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.profile_regions AS pr
         (user_id, state_code, district_code, catalog_version, status, source,
          legacy_state_label, legacy_district_label, updated_at)
  VALUES (v_uid, v_state.code, v_district.code, p_catalog_version, 'resolved', 'user',
          v_state.name_en, v_district.name_en, now())
  ON CONFLICT (user_id) DO UPDATE
     SET state_code = EXCLUDED.state_code,
         district_code = EXCLUDED.district_code,
         catalog_version = EXCLUDED.catalog_version,
         status = 'resolved',
         source = 'user',
         legacy_state_label = EXCLUDED.legacy_state_label,
         legacy_district_label = EXCLUDED.legacy_district_label,
         updated_at = now();

  UPDATE public.profiles
     SET state = v_state.name_en, district = v_district.name_en
   WHERE id = v_uid;

  UPDATE public.region_resolution_queue q
     SET status = 'resolved', resolved_at = now()
   WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_uid AND q.status = 'open';

  RETURN jsonb_build_object(
    'state_code', v_state.code, 'state_name', v_state.name_en,
    'district_code', v_district.code, 'district_name', v_district.name_en,
    'catalog_version', p_catalog_version, 'status', 'resolved');
END;
$$;

-- Replaces the caller's service districts (1..30 unique active codes, any
-- State/UT) and mirrors the names into engineers.service_areas.
CREATE OR REPLACE FUNCTION public.set_my_service_districts(
  p_district_codes text[], p_catalog_version text
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_engineer uuid;
  v_count integer := coalesce(cardinality(p_district_codes), 0);
  v_known integer;
  v_active integer;
  v_names text[];
  c_max constant integer := 30;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT e.id INTO v_engineer FROM public.engineers e WHERE e.user_id = v_uid;
  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'not_an_engineer' USING ERRCODE = '42501';
  END IF;
  PERFORM public.region_require_writable_version(p_catalog_version);

  IF v_count = 0 THEN
    RAISE EXCEPTION 'region_service_districts_empty' USING ERRCODE = '22023';
  END IF;
  IF v_count > c_max THEN
    RAISE EXCEPTION 'region_service_districts_too_many' USING ERRCODE = '22023';
  END IF;
  IF array_position(p_district_codes, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  IF (SELECT count(DISTINCT c) FROM unnest(p_district_codes) c) <> v_count THEN
    RAISE EXCEPTION 'region_service_districts_duplicate' USING ERRCODE = '22023';
  END IF;

  SELECT count(*), count(*) FILTER (WHERE d.active)
    INTO v_known, v_active
    FROM public.region_districts d
   WHERE d.code = ANY (p_district_codes);
  IF v_known <> v_count THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  IF v_active <> v_count THEN
    RAISE EXCEPTION 'region_district_retired' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.engineer_service_districts esd WHERE esd.engineer_id = v_engineer;
  INSERT INTO public.engineer_service_districts (engineer_id, district_code, catalog_version, source)
  SELECT v_engineer, c, p_catalog_version, 'engineer' FROM unnest(p_district_codes) c;

  SELECT array_agg(d.name_en ORDER BY x.ord)
    INTO v_names
    FROM unnest(p_district_codes) WITH ORDINALITY AS x(code, ord)
    JOIN public.region_districts d ON d.code = x.code;
  UPDATE public.engineers SET service_areas = v_names WHERE id = v_engineer;

  UPDATE public.region_resolution_queue q
     SET status = 'resolved', resolved_at = now()
   WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_uid AND q.status = 'open';

  RETURN jsonb_build_object(
    'catalog_version', p_catalog_version,
    'district_codes', to_jsonb(p_district_codes),
    'count', v_count);
END;
$$;

-- The caller's region record. When no coded home region exists, or the
-- label text changed since it was written (an older app version edited
-- profiles directly), it includes an exact-only resolution preview of the
-- current text. Never writes.
CREATE OR REPLACE FUNCTION public.my_region_profile()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile_state text;
  v_profile_district text;
  v_row public.profile_regions%ROWTYPE;
  v_has_row boolean;
  v_stale boolean := false;
  v_preview jsonb := NULL;
  v_engineer uuid;
  v_service jsonb := '[]'::jsonb;
  r record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  SELECT p.state, p.district INTO v_profile_state, v_profile_district
    FROM public.profiles p WHERE p.id = v_uid;

  SELECT * INTO v_row FROM public.profile_regions pr WHERE pr.user_id = v_uid;
  v_has_row := FOUND;
  IF v_has_row THEN
    v_stale := v_row.legacy_state_label IS DISTINCT FROM v_profile_state
            OR v_row.legacy_district_label IS DISTINCT FROM v_profile_district;
  END IF;

  IF (NOT v_has_row OR v_stale) AND public.region_current_version() IS NOT NULL THEN
    SELECT * INTO r FROM public.region_resolve_legacy_pair(v_profile_state, v_profile_district);
    v_preview := jsonb_build_object(
      'status', r.status, 'state_code', r.state_code, 'district_code', r.district_code,
      'reason', r.reason, 'candidate_codes', to_jsonb(r.candidate_codes),
      'catalog_version', public.region_current_version());
  END IF;

  SELECT e.id INTO v_engineer FROM public.engineers e WHERE e.user_id = v_uid;
  IF v_engineer IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'district_code', esd.district_code, 'catalog_version', esd.catalog_version,
             'source', esd.source) ORDER BY esd.district_code), '[]'::jsonb)
      INTO v_service
      FROM public.engineer_service_districts esd WHERE esd.engineer_id = v_engineer;
  END IF;

  RETURN jsonb_build_object(
    'home', CASE WHEN v_has_row THEN jsonb_build_object(
        'state_code', v_row.state_code, 'district_code', v_row.district_code,
        'catalog_version', v_row.catalog_version, 'status', v_row.status, 'source', v_row.source,
        'legacy_state_label', v_row.legacy_state_label,
        'legacy_district_label', v_row.legacy_district_label) END,
    'home_stale', v_stale,
    'legacy_state_label', v_profile_state,
    'legacy_district_label', v_profile_district,
    'legacy_preview', v_preview,
    'is_engineer', v_engineer IS NOT NULL,
    'service_districts', v_service,
    'current_catalog_version', public.region_current_version());
END;
$$;

-- ---------------------------------------------------------------------
-- Service-only legacy backfill (counts only)
-- ---------------------------------------------------------------------

-- Resolves legacy profiles.state/district and engineers.service_areas text
-- against the current catalogue with exact-only matching. p_apply=false is a
-- dry run. p_apply=true writes profile_regions (resolved or
-- needs_confirmation; never overwrites a current user-chosen row), adds
-- engineer_service_districts for exactly-resolved names when the engineer has
-- chosen none, and queues everything else. Returns counts only: no ids,
-- labels or codes leave this function.
CREATE OR REPLACE FUNCTION public.region_legacy_backfill_report(p_apply boolean)
RETURNS TABLE(
  profiles_with_labels integer,
  profiles_already_current integer,
  profiles_resolved integer,
  profiles_needs_confirmation integer,
  engineers_with_service_areas integer,
  engineers_already_chosen integer,
  service_labels_resolved integer,
  service_labels_needs_confirmation integer,
  queue_rows_added integer
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_version text := public.region_current_version();
  v_with integer := 0; v_current integer := 0; v_resolved integer := 0; v_needs integer := 0;
  v_eng integer := 0; v_eng_chosen integer := 0; v_svc_ok integer := 0; v_svc_needs integer := 0;
  v_queued integer := 0;
  v_n integer;
  p record;
  r record;
  e record;
  v_label text;
  v_scope text;
  v_candidates text[];
BEGIN
  IF v_version IS NULL THEN
    RAISE EXCEPTION 'region_catalog_missing' USING ERRCODE = 'P0002';
  END IF;

  FOR p IN
    SELECT pf.id, pf.state, pf.district, pr.user_id AS has_row, pr.source,
           pr.legacy_state_label, pr.legacy_district_label
      FROM public.profiles pf
      LEFT JOIN public.profile_regions pr ON pr.user_id = pf.id
     WHERE public.region_normalize_label(pf.state) IS NOT NULL
        OR public.region_normalize_label(pf.district) IS NOT NULL
  LOOP
    v_with := v_with + 1;
    IF p.has_row IS NOT NULL
       AND p.legacy_state_label IS NOT DISTINCT FROM p.state
       AND p.legacy_district_label IS NOT DISTINCT FROM p.district THEN
      v_current := v_current + 1;
      CONTINUE;
    END IF;
    SELECT * INTO r FROM public.region_resolve_legacy_pair(p.state, p.district);
    IF r.status = 'resolved' THEN
      v_resolved := v_resolved + 1;
    ELSE
      v_needs := v_needs + 1;
    END IF;
    IF p_apply THEN
      INSERT INTO public.profile_regions AS x
             (user_id, state_code, district_code, catalog_version, status, source,
              legacy_state_label, legacy_district_label, updated_at)
      VALUES (p.id, r.state_code, r.district_code, v_version, r.status, 'legacy_backfill',
              p.state, p.district, now())
      ON CONFLICT (user_id) DO UPDATE
         SET state_code = EXCLUDED.state_code, district_code = EXCLUDED.district_code,
             catalog_version = EXCLUDED.catalog_version, status = EXCLUDED.status,
             source = EXCLUDED.source, legacy_state_label = EXCLUDED.legacy_state_label,
             legacy_district_label = EXCLUDED.legacy_district_label, updated_at = now();
      IF r.status <> 'resolved' THEN
        INSERT INTO public.region_resolution_queue
               (subject_kind, subject_user_id, raw_state_label, raw_district_label, reason,
                candidate_codes, catalog_version)
        VALUES ('profile_home', p.id, p.state, p.district, r.reason, r.candidate_codes, v_version)
        ON CONFLICT DO NOTHING;
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_queued := v_queued + v_n;
      END IF;
    END IF;
  END LOOP;

  FOR e IN
    SELECT en.id, en.user_id, en.state AS engineer_state, en.service_areas, pf.state AS profile_state,
           EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                    WHERE esd.engineer_id = en.id AND esd.source = 'engineer') AS chosen
      FROM public.engineers en
      JOIN public.profiles pf ON pf.id = en.user_id
     WHERE coalesce(cardinality(en.service_areas), 0) > 0
  LOOP
    v_eng := v_eng + 1;
    IF e.chosen THEN
      v_eng_chosen := v_eng_chosen + 1;
      CONTINUE;
    END IF;
    -- Service-area text has no State/UT of its own: resolve only inside the
    -- engineer's own State/UT (KYC column first, then the profile's).
    v_scope := coalesce(public.region_resolve_state_label(e.engineer_state),
                        public.region_resolve_state_label(e.profile_state));
    FOREACH v_label IN ARRAY e.service_areas LOOP
      CONTINUE WHEN public.region_normalize_label(v_label) IS NULL;
      v_candidates := CASE WHEN v_scope IS NULL THEN '{}'::text[]
                           ELSE public.region_district_candidates(v_scope, v_label) END;
      IF cardinality(v_candidates) = 1 THEN
        v_svc_ok := v_svc_ok + 1;
        IF p_apply THEN
          INSERT INTO public.engineer_service_districts (engineer_id, district_code, catalog_version, source)
          VALUES (e.id, v_candidates[1], v_version, 'legacy_backfill')
          ON CONFLICT (engineer_id, district_code) DO NOTHING;
        END IF;
      ELSE
        v_svc_needs := v_svc_needs + 1;
        IF p_apply THEN
          INSERT INTO public.region_resolution_queue
                 (subject_kind, subject_user_id, raw_state_label, raw_district_label, reason,
                  candidate_codes, catalog_version)
          VALUES ('engineer_service', e.user_id, coalesce(e.engineer_state, e.profile_state), v_label,
                  CASE WHEN v_scope IS NULL THEN 'state_unknown'
                       WHEN cardinality(v_candidates) = 0 THEN 'no_match' ELSE 'ambiguous' END,
                  v_candidates, v_version)
          ON CONFLICT DO NOTHING;
          GET DIAGNOSTICS v_n = ROW_COUNT;
          v_queued := v_queued + v_n;
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  RETURN QUERY SELECT v_with, v_current, v_resolved, v_needs, v_eng, v_eng_chosen,
                      v_svc_ok, v_svc_needs, v_queued;
END;
$$;

-- ---------------------------------------------------------------------
-- Function grants
-- ---------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.region_normalize_label(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_current_version() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_resolve_state_label(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_district_candidates(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_require_writable_version(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_resolve_legacy_pair(text, text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.region_catalog_current() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_my_home_region(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_my_service_districts(text[], text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.my_region_profile() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_legacy_backfill_report(boolean) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.region_catalog_current() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_my_home_region(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_my_service_districts(text[], text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.my_region_profile() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.region_legacy_backfill_report(boolean) TO service_role;

-- ---------------------------------------------------------------------
-- Self-check: abort the migration if anything is not as intended
-- ---------------------------------------------------------------------

DO $$
DECLARE
  v_bad text[] := ARRAY[]::text[];
  v_table text;
  v_priv text;
  v_sig text;
  v_def boolean;
  v_cfg text[];
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'public.region_catalog_versions', 'public.region_states', 'public.region_districts',
    'public.region_district_aliases', 'public.profile_regions',
    'public.engineer_service_districts', 'public.region_resolution_queue'
  ] LOOP
    IF NOT (SELECT c.relrowsecurity FROM pg_class c WHERE c.oid = v_table::regclass) THEN
      v_bad := v_bad || ('rls off: ' || v_table);
    END IF;
    FOREACH v_priv IN ARRAY ARRAY['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
      IF has_table_privilege('anon', v_table, v_priv) OR has_table_privilege('authenticated', v_table, v_priv) THEN
        v_bad := v_bad || (lower(v_priv) || ' granted to a client on ' || v_table);
      END IF;
    END LOOP;
  END LOOP;

  FOREACH v_table IN ARRAY ARRAY['public.profile_regions', 'public.engineer_service_districts',
                                  'public.region_resolution_queue'] LOOP
    IF has_table_privilege('anon', v_table, 'SELECT') THEN
      v_bad := v_bad || ('anon select on ' || v_table);
    END IF;
  END LOOP;
  IF has_table_privilege('authenticated', 'public.region_resolution_queue', 'SELECT') THEN
    v_bad := v_bad || 'authenticated select on public.region_resolution_queue'::text;
  END IF;
  IF has_sequence_privilege('anon', 'public.region_resolution_queue_id_seq', 'USAGE')
     OR has_sequence_privilege('authenticated', 'public.region_resolution_queue_id_seq', 'USAGE') THEN
    v_bad := v_bad || 'client usage on public.region_resolution_queue_id_seq'::text;
  END IF;

  FOREACH v_sig IN ARRAY ARRAY[
    'public.region_catalog_current()', 'public.set_my_home_region(text,text,text)',
    'public.set_my_service_districts(text[],text)', 'public.my_region_profile()'
  ] LOOP
    SELECT p.prosecdef, p.proconfig INTO v_def, v_cfg FROM pg_proc p WHERE p.oid = v_sig::regprocedure;
    IF NOT v_def OR NOT EXISTS (SELECT 1 FROM unnest(v_cfg) c WHERE c LIKE 'search_path=%')
       OR has_function_privilege('anon', v_sig, 'EXECUTE')
       OR NOT has_function_privilege('authenticated', v_sig, 'EXECUTE')
       OR NOT has_function_privilege('service_role', v_sig, 'EXECUTE') THEN
      v_bad := v_bad || ('client rpc shape: ' || v_sig);
    END IF;
  END LOOP;

  SELECT p.prosecdef, p.proconfig INTO v_def, v_cfg
    FROM pg_proc p WHERE p.oid = 'public.region_legacy_backfill_report(boolean)'::regprocedure;
  IF NOT v_def OR NOT EXISTS (SELECT 1 FROM unnest(v_cfg) c WHERE c LIKE 'search_path=%')
     OR has_function_privilege('anon', 'public.region_legacy_backfill_report(boolean)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.region_legacy_backfill_report(boolean)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.region_legacy_backfill_report(boolean)', 'EXECUTE') THEN
    v_bad := v_bad || 'service-only shape: public.region_legacy_backfill_report(boolean)'::text;
  END IF;

  FOREACH v_sig IN ARRAY ARRAY[
    'public.region_normalize_label(text)', 'public.region_current_version()',
    'public.region_resolve_state_label(text)', 'public.region_district_candidates(text,text)',
    'public.region_require_writable_version(text)', 'public.region_resolve_legacy_pair(text,text)'
  ] LOOP
    IF has_function_privilege('anon', v_sig, 'EXECUTE') OR has_function_privilege('authenticated', v_sig, 'EXECUTE') THEN
      v_bad := v_bad || ('client execute on helper ' || v_sig);
    END IF;
  END LOOP;

  IF array_length(v_bad, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'round3830: not as intended: %', v_bad USING ERRCODE = '42501';
  END IF;
END $$;

COMMIT;
