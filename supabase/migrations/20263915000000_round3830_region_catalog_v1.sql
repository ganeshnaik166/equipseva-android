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
--   * No column, user trigger, policy, grant or enum is added to or changed on
--     profiles or engineers. (The three ON DELETE CASCADE foreign keys do add
--     PostgreSQL-internal RI triggers on profiles and engineers and
--     pg_constraint rows whose confrelid is those tables; checks that pin
--     those tables should exclude tgisinternal triggers and match constraints
--     by conrelid.) Legacy text written directly by older app versions is
--     resolved inside my_region_profile() (read-only preview with stale flags)
--     and by region_legacy_backfill_report(), not by a trigger.
--   * No directory, job-feed, nearby, attendance, deletion or export function
--     changes. engineers.service_radius_km, latitude and longitude are not
--     touched.
--
-- Label sync: set_my_home_region mirrors the chosen names into
-- profiles.state/district, and set_my_service_districts mirrors them into
-- engineers.service_areas, which existing readers still use. Each coded row
-- keeps the label text it was written with, so staleness compares text with
-- text and a catalogue rename alone is never a change.
--   * Home region: when an older app version later edits profiles.state/district
--     directly, the latest text wins: my_region_profile reports home_stale and
--     the next backfill re-resolves the new text exactly.
--   * Service districts: an engineer's own choice is never overridden by the
--     backfill. Free service-area text carries no State/UT, so re-deriving it
--     could silently drop a cross-State/UT choice; instead my_region_profile
--     reports service_stale so the app can ask the engineer to confirm.
-- A district that moves to another State/UT under the same code carries its
-- aliases and stored home pairs with it (composite foreign keys cascade).
--
-- Resolution queue: the backfill opens an item per unresolved text and closes
-- its own items as 'superseded' when the text changes or goes, or 'resolved'
-- when it resolves; a choice made in the app also closes them as 'resolved'.
-- Operators close an item with 'dismissed' to stop it being re-queued while
-- the text stays the same.
--
-- Refusals (RAISE message = code; clients map the code, never the wording):
--   not_authenticated                     42501  no JWT subject
--   not_an_engineer                       42501  set_my_service_districts by a non-engineer
--   region_catalog_version_unsupported    22023  version unknown, or not accepting writes
--   region_code_unknown                   22023  unknown code, a NULL or multi-dimensional
--                                                list element, or a code that is not part
--                                                of the submitted catalogue version
--   region_district_retired               22023  the district, or its State/UT, is retired
--   region_pair_invalid                   22023  district not in the given State/UT
--   region_service_districts_empty        22023  no codes
--   region_service_districts_too_many     22023  more than 30 codes
--   region_service_districts_duplicate    22023  a code repeated
--   profile_not_found                     P0001  caller has no profiles row
--   region_catalog_missing                P0001  backfill before any catalogue is seeded
--
-- Grants: the project's default privileges grant new tables, sequences and
-- functions to anon and authenticated directly (round3791), so every object
-- below is revoked from PUBLIC, anon and authenticated first and then granted
-- explicitly. The trailing DO block re-checks the result and aborts the whole
-- migration if any grant, RLS flag or function shape is not as intended.
--
-- Idempotent and forward-only. Proven locally by
-- supabase/tests/region_catalog.test.mjs and region_catalog_guards.test.mjs
-- (PGlite, synthetic catalogue). Not applied to any Supabase project by this
-- commit.
BEGIN;

-- The foreign keys below take a SHARE ROW EXCLUSIVE lock on profiles and
-- engineers; do not queue behind a long transaction holding them.
SET LOCAL lock_timeout = '5s';

-- Exact-match normalisation: lower case, and runs of ASCII whitespace (space,
-- tab, newline, carriage return, form feed, vertical tab) collapsed to one
-- space and trimmed. Nothing else is folded: not non-breaking or other Unicode
-- spaces, punctuation, abbreviations ("Dist.") or partial names. The explicit
-- class keeps the result independent of the database locale, so the device
-- (RegionCatalog.normalizeLabel) and the generator can mirror it exactly.
-- Defined first because a CHECK constraint below uses it.
CREATE OR REPLACE FUNCTION public.region_normalize_label(p_label text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
  SELECT nullif(lower(btrim(regexp_replace(coalesce(p_label, ''), '[ \t\n\r\f\v]+', ' ', 'g'))), '')
$$;

CREATE OR REPLACE FUNCTION public.region_labels_equal(p_a text, p_b text)
RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
  SELECT public.region_normalize_label(p_a) IS NOT DISTINCT FROM public.region_normalize_label(p_b)
$$;

-- ---------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.region_catalog_versions (
  version         text PRIMARY KEY CHECK (version ~ '^[a-z0-9][a-z0-9._-]{2,63}$'),
  ordinal         bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
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
  CHECK (active = (retired_in IS NULL)),
  UNIQUE (code, state_code)
);
CREATE UNIQUE INDEX IF NOT EXISTS region_districts_active_state_name
  ON public.region_districts (state_code, lower(name_en)) WHERE active;
CREATE INDEX IF NOT EXISTS region_districts_state_idx
  ON public.region_districts (state_code);

-- An alias always belongs to the same State/UT as its district (composite FK,
-- which follows the district if it moves) and is stored normalised, or it
-- could never match.
CREATE TABLE IF NOT EXISTS public.region_district_aliases (
  state_code        text NOT NULL REFERENCES public.region_states(code),
  alias_normalized  text NOT NULL CHECK (length(alias_normalized) BETWEEN 1 AND 64
                                         AND alias_normalized = public.region_normalize_label(alias_normalized)),
  district_code     text NOT NULL,
  kind              text NOT NULL CHECK (kind IN ('official', 'legacy_bundled', 'renamed', 'common_spelling')),
  added_in          text REFERENCES public.region_catalog_versions(version),
  PRIMARY KEY (state_code, alias_normalized, district_code),
  FOREIGN KEY (district_code, state_code) REFERENCES public.region_districts(code, state_code) ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- Per-user records
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profile_regions (
  user_id                uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  state_code             text REFERENCES public.region_states(code),
  district_code          text,
  catalog_version        text NOT NULL REFERENCES public.region_catalog_versions(version),
  status                 text NOT NULL CHECK (status IN ('resolved', 'needs_confirmation')),
  source                 text NOT NULL CHECK (source IN ('user', 'legacy_backfill')),
  legacy_state_label     text,
  legacy_district_label  text,
  updated_at             timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (district_code, state_code) REFERENCES public.region_districts(code, state_code) ON UPDATE CASCADE,
  CHECK (district_code IS NULL OR state_code IS NOT NULL),
  CHECK (status <> 'resolved' OR (state_code IS NOT NULL AND district_code IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.engineer_service_districts (
  engineer_id      uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  district_code    text NOT NULL REFERENCES public.region_districts(code),
  catalog_version  text NOT NULL REFERENCES public.region_catalog_versions(version),
  source           text NOT NULL CHECK (source IN ('engineer', 'legacy_backfill')),
  label_snapshot   text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (engineer_id, district_code)
);

CREATE TABLE IF NOT EXISTS public.region_resolution_queue (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  subject_kind        text NOT NULL CHECK (subject_kind IN ('profile_home', 'engineer_service')),
  subject_user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  raw_state_label     text,
  raw_district_label  text,
  reason              text NOT NULL CHECK (reason IN ('state_unknown', 'no_match', 'ambiguous', 'retired', 'too_many')),
  candidate_codes     text[] NOT NULL DEFAULT '{}',
  catalog_version     text NOT NULL REFERENCES public.region_catalog_versions(version),
  status              text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'superseded', 'dismissed')),
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
REVOKE ALL ON SEQUENCE public.region_resolution_queue_id_seq, public.region_catalog_versions_ordinal_seq
  FROM PUBLIC, anon, authenticated;

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
  'round3830: one row per imported region catalogue snapshot (source, date, checksum); ordinal orders them. At most one is_current; accepts_writes=false retires a version for new selections. Seeded only by generated, owner-approved migrations.';
COMMENT ON TABLE public.profile_regions IS
  'round3830: a user''s home State/UT + district as codes plus the catalogue version. Written only by set_my_home_region / region_legacy_backfill_report; legacy_*_label keep the label text as it was when the row was written.';
COMMENT ON TABLE public.engineer_service_districts IS
  'round3830: an engineer''s explicit service districts (may span states). Written only by set_my_service_districts / region_legacy_backfill_report. Not yet read by any feed or directory.';
COMMENT ON TABLE public.region_resolution_queue IS
  'round3830: legacy labels that did not resolve to exactly one code. No client access; reviewed by operators.';

-- ---------------------------------------------------------------------
-- Internal helpers (owner-only; called from the functions below)
-- ---------------------------------------------------------------------

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

-- Active district codes of one active State/UT whose current name or an alias
-- matches exactly after normalisation. Never looks outside p_state_code.
CREATE OR REPLACE FUNCTION public.region_district_candidates(p_state_code text, p_label text)
RETURNS text[]
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  WITH n AS (SELECT public.region_normalize_label(p_label) AS label),
       s AS (SELECT st.code FROM public.region_states st WHERE st.code = p_state_code AND st.active)
  SELECT coalesce(array_agg(DISTINCT c.code ORDER BY c.code), '{}')
    FROM (
      SELECT d.code
        FROM public.region_districts d
        JOIN s ON s.code = d.state_code
        CROSS JOIN n
       WHERE d.active AND public.region_normalize_label(d.name_en) = n.label
      UNION
      SELECT d.code
        FROM public.region_district_aliases a
        JOIN public.region_districts d ON d.code = a.district_code AND d.state_code = a.state_code
        JOIN s ON s.code = a.state_code
        CROSS JOIN n
       WHERE d.active AND a.alias_normalized = n.label
    ) c
$$;

-- Validates that p_catalog_version may be used for a new selection and
-- returns its ordinal.
CREATE OR REPLACE FUNCTION public.region_require_writable_version(p_catalog_version text)
RETURNS bigint
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ordinal bigint;
BEGIN
  SELECT v.ordinal INTO v_ordinal
    FROM public.region_catalog_versions v
   WHERE v.version = p_catalog_version AND v.accepts_writes;
  IF v_ordinal IS NULL THEN
    RAISE EXCEPTION 'region_catalog_version_unsupported' USING ERRCODE = '22023';
  END IF;
  RETURN v_ordinal;
END;
$$;

-- Whether a record introduced in p_introduced_in already existed in the
-- catalogue version with ordinal p_version_ordinal.
CREATE OR REPLACE FUNCTION public.region_in_version(p_introduced_in text, p_version_ordinal bigint)
RETURNS boolean
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT p_introduced_in IS NULL
      OR coalesce((SELECT v.ordinal <= p_version_ordinal FROM public.region_catalog_versions v
                    WHERE v.version = p_introduced_in), false)
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
  v_replacements text[];
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
    -- A retired district's own name: suggest its active replacements, never pick one.
    IF EXISTS (SELECT 1 FROM public.region_districts d
                WHERE d.state_code = v_state AND NOT d.active
                  AND public.region_normalize_label(d.name_en) = public.region_normalize_label(p_district_label)) THEN
      SELECT coalesce(array_agg(DISTINCT x.code ORDER BY x.code), '{}') INTO v_replacements
        FROM public.region_districts d
        CROSS JOIN LATERAL unnest(d.replaced_by) AS r(code)
        JOIN public.region_districts x ON x.code = r.code AND x.active
       WHERE d.state_code = v_state AND NOT d.active
         AND public.region_normalize_label(d.name_en) = public.region_normalize_label(p_district_label);
      RETURN QUERY SELECT 'needs_confirmation'::text, v_state, NULL::text, 'retired'::text, v_replacements;
    ELSE
      RETURN QUERY SELECT 'needs_confirmation'::text, v_state, NULL::text, 'no_match'::text, v_candidates;
    END IF;
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
         coalesce((SELECT array_agg(v.version ORDER BY v.ordinal)
                     FROM public.region_catalog_versions v WHERE v.accepts_writes), '{}'),
         coalesce((SELECT v.is_synthetic FROM public.region_catalog_versions v WHERE v.is_current), false),
         (SELECT count(*)::integer FROM public.region_states s WHERE s.active),
         (SELECT count(*)::integer FROM public.region_districts d
            JOIN public.region_states s ON s.code = d.state_code
           WHERE d.active AND s.active);
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
  v_ordinal bigint;
  v_state public.region_states%ROWTYPE;
  v_district public.region_districts%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  v_ordinal := public.region_require_writable_version(p_catalog_version);

  SELECT * INTO v_state FROM public.region_states s WHERE s.code = p_state_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_district FROM public.region_districts d WHERE d.code = p_district_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  IF NOT v_district.active OR NOT v_state.active THEN
    RAISE EXCEPTION 'region_district_retired' USING ERRCODE = '22023';
  END IF;
  IF v_district.state_code <> v_state.code THEN
    RAISE EXCEPTION 'region_pair_invalid' USING ERRCODE = '22023';
  END IF;
  IF NOT public.region_in_version(v_state.introduced_in, v_ordinal)
     OR NOT public.region_in_version(v_district.introduced_in, v_ordinal) THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;

  -- Serialises against concurrent saves and the backfill for this user.
  PERFORM 1 FROM public.profiles p WHERE p.id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
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
-- State/UT) and mirrors the names, in the order given, into
-- engineers.service_areas.
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
  v_ordinal bigint;
  v_count integer;
  v_known integer;
  v_usable integer;
  v_in_version integer;
  v_names text[];
  c_max constant integer := 30;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '42501';
  END IF;
  -- Locking the engineer row serialises concurrent saves and the backfill, so
  -- the replace below stays atomic and within the cap.
  SELECT e.id INTO v_engineer FROM public.engineers e WHERE e.user_id = v_uid FOR UPDATE;
  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'not_an_engineer' USING ERRCODE = '42501';
  END IF;
  v_ordinal := public.region_require_writable_version(p_catalog_version);

  IF coalesce(array_ndims(p_district_codes), 1) > 1 THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  v_count := coalesce(cardinality(p_district_codes), 0);
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

  SELECT count(*),
         count(*) FILTER (WHERE d.active AND s.active),
         count(*) FILTER (WHERE public.region_in_version(d.introduced_in, v_ordinal))
    INTO v_known, v_usable, v_in_version
    FROM public.region_districts d
    JOIN public.region_states s ON s.code = d.state_code
   WHERE d.code = ANY (p_district_codes);
  IF v_known <> v_count THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;
  IF v_usable <> v_count THEN
    RAISE EXCEPTION 'region_district_retired' USING ERRCODE = '22023';
  END IF;
  IF v_in_version <> v_count THEN
    RAISE EXCEPTION 'region_code_unknown' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.engineer_service_districts esd WHERE esd.engineer_id = v_engineer;
  INSERT INTO public.engineer_service_districts (engineer_id, district_code, catalog_version, source, label_snapshot)
  SELECT v_engineer, d.code, p_catalog_version, 'engineer', d.name_en
    FROM unnest(p_district_codes) c JOIN public.region_districts d ON d.code = c;

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

-- The caller's region record. When no coded home region exists, when it still
-- needs confirmation, or when the label text changed since it was written (an
-- older app version edited profiles directly), it includes an exact-only
-- resolution preview of the current text. Never writes.
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
  v_areas text[];
  v_service jsonb := '[]'::jsonb;
  v_service_source text := 'none';
  v_service_stale boolean := false;
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
    v_stale := NOT (public.region_labels_equal(v_row.legacy_state_label, v_profile_state)
                AND public.region_labels_equal(v_row.legacy_district_label, v_profile_district));
  END IF;

  IF (NOT v_has_row OR v_stale OR v_row.status <> 'resolved')
     AND public.region_current_version() IS NOT NULL THEN
    SELECT * INTO r FROM public.region_resolve_legacy_pair(v_profile_state, v_profile_district);
    v_preview := jsonb_build_object(
      'status', r.status, 'state_code', r.state_code, 'district_code', r.district_code,
      'reason', r.reason, 'candidate_codes', to_jsonb(r.candidate_codes),
      'catalog_version', public.region_current_version());
  END IF;

  SELECT e.id, e.service_areas INTO v_engineer, v_areas FROM public.engineers e WHERE e.user_id = v_uid;
  IF v_engineer IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'district_code', esd.district_code, 'catalog_version', esd.catalog_version,
             'source', esd.source) ORDER BY esd.district_code), '[]'::jsonb)
      INTO v_service
      FROM public.engineer_service_districts esd WHERE esd.engineer_id = v_engineer;
    v_service_source := CASE
      WHEN EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                    WHERE esd.engineer_id = v_engineer AND esd.source = 'engineer') THEN 'engineer'
      WHEN EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                    WHERE esd.engineer_id = v_engineer AND esd.source = 'legacy_backfill') THEN 'legacy_backfill'
      ELSE 'none' END;
    -- An engineer-chosen set is stale when the service-area text no longer
    -- names the labels written with the choice (an older app version edited
    -- it). Compared as sets after normalisation, so a repeated name or a
    -- catalogue rename alone is not a change.
    IF v_service_source = 'engineer' THEN
      v_service_stale :=
        (SELECT coalesce(array_agg(DISTINCT n ORDER BY n), '{}')
           FROM (SELECT public.region_normalize_label(a) AS n FROM unnest(coalesce(v_areas, '{}')) a) t
          WHERE n IS NOT NULL)
        IS DISTINCT FROM
        (SELECT coalesce(array_agg(DISTINCT n ORDER BY n), '{}')
           FROM (SELECT public.region_normalize_label(esd.label_snapshot) AS n
                   FROM public.engineer_service_districts esd
                  WHERE esd.engineer_id = v_engineer) t);
    END IF;
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
    'service_source', v_service_source,
    'service_stale', v_service_stale,
    'current_catalog_version', public.region_current_version());
END;
$$;

-- ---------------------------------------------------------------------
-- Service-only legacy backfill (counts only)
-- ---------------------------------------------------------------------

-- Converges derived region data on the current label text with exact-only
-- matching. p_apply=false is a dry run that reports exactly what
-- p_apply=true would change, including queue changes. Rules:
--   * profiles: a user-chosen row whose text is unchanged (after
--     normalisation) is never touched; a resolved row on the current catalogue
--     with unchanged text is current; anything else is re-resolved and
--     written as source=legacy_backfill (the latest text wins). Cleared text
--     removes a backfilled row.
--   * engineers who chose districts in the app are never touched (see the
--     header). For the rest, the legacy_backfill set is exactly the distinct
--     codes their current service-area text resolves to inside their own
--     State/UT (the KYC State/UT; the profile's only when the KYC one is
--     blank), or nothing when that is more than 30 (queued as too_many).
--   * a queue item is added for each unresolved text that has neither an open
--     nor an operator-dismissed item; the backfill closes its own items as
--     'superseded' when their text changes or goes ('resolved' when it
--     resolves), keeps the reason and candidates of open items current, and
--     supersedes the items of users who are no longer engineers.
-- Rows are locked before they are re-read (lock_timeout 2s while applying),
-- so a concurrent user save is never overwritten; run it off-peak. Returns
-- counts only: no ids, labels or codes leave this function.
CREATE OR REPLACE FUNCTION public.region_legacy_backfill_report(p_apply boolean)
RETURNS TABLE(
  profiles_considered integer,
  profiles_already_current integer,
  profiles_resolved integer,
  profiles_needs_confirmation integer,
  profiles_cleared integer,
  engineers_considered integer,
  engineers_already_chosen integer,
  engineers_already_current integer,
  engineers_over_cap integer,
  service_labels_resolved integer,
  service_labels_needs_confirmation integer,
  queue_rows_added integer,
  queue_rows_closed integer,
  queue_rows_updated integer
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_version text := public.region_current_version();
  c_max constant integer := 30;
  c_too_many constant text := '(too many districts)';
  v_p_considered integer := 0; v_p_current integer := 0; v_p_resolved integer := 0;
  v_p_needs integer := 0; v_p_cleared integer := 0;
  v_e_considered integer := 0; v_e_chosen integer := 0; v_e_current integer := 0; v_e_over integer := 0;
  v_s_resolved integer := 0; v_s_needs integer := 0;
  v_added integer := 0; v_closed integer := 0; v_updated integer := 0; v_n integer;
  v_id uuid;
  v_state_label text; v_district_label text;
  v_row public.profile_regions%ROWTYPE; v_has_row boolean; v_same_text boolean;
  r record;
  v_user uuid; v_kyc_state text; v_profile_state text; v_areas text[];
  v_scope text; v_scope_label text;
  v_label text; v_norm text; v_seen text[]; v_candidates text[];
  v_resolved text[]; v_resolved_labels text[]; v_target text[]; v_existing text[];
  v_restamp boolean;
  v_un_labels text[]; v_un_reasons text[]; v_un_candidates jsonb; v_cand text[];
  v_expected text[]; v_open_vanished integer; v_missing integer; v_stale_items integer;
  v_over boolean;
  i integer;
BEGIN
  IF v_version IS NULL THEN
    RAISE EXCEPTION 'region_catalog_missing' USING ERRCODE = 'P0001';
  END IF;
  IF p_apply THEN
    PERFORM set_config('lock_timeout', '2s', true);
  END IF;

  -- Profiles with label text, a backfilled row, or an open item.
  FOR v_id IN
    SELECT pf.id FROM public.profiles pf
     WHERE public.region_normalize_label(pf.state) IS NOT NULL
        OR public.region_normalize_label(pf.district) IS NOT NULL
        OR EXISTS (SELECT 1 FROM public.profile_regions pr
                    WHERE pr.user_id = pf.id AND pr.source = 'legacy_backfill')
        OR EXISTS (SELECT 1 FROM public.region_resolution_queue q
                    WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = pf.id AND q.status = 'open')
     ORDER BY pf.id
  LOOP
    v_p_considered := v_p_considered + 1;
    IF p_apply THEN
      SELECT pf.state, pf.district INTO v_state_label, v_district_label
        FROM public.profiles pf WHERE pf.id = v_id FOR UPDATE;
    ELSE
      SELECT pf.state, pf.district INTO v_state_label, v_district_label
        FROM public.profiles pf WHERE pf.id = v_id;
    END IF;
    SELECT * INTO v_row FROM public.profile_regions pr WHERE pr.user_id = v_id;
    v_has_row := FOUND;
    v_same_text := v_has_row
      AND public.region_labels_equal(v_row.legacy_state_label, v_state_label)
      AND public.region_labels_equal(v_row.legacy_district_label, v_district_label);

    IF public.region_normalize_label(v_state_label) IS NULL
       AND public.region_normalize_label(v_district_label) IS NULL THEN
      -- The text was cleared: drop derived data, keep anything the user chose.
      SELECT count(*) INTO v_n FROM public.region_resolution_queue q
       WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open';
      IF (v_has_row AND v_row.source = 'legacy_backfill') OR v_n > 0 THEN
        v_p_cleared := v_p_cleared + 1;
        v_closed := v_closed + v_n;
        IF p_apply THEN
          DELETE FROM public.profile_regions pr WHERE pr.user_id = v_id AND pr.source = 'legacy_backfill';
          UPDATE public.region_resolution_queue q SET status = 'superseded', resolved_at = now()
           WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open';
        END IF;
      ELSE
        v_p_current := v_p_current + 1;
      END IF;
      CONTINUE;
    END IF;

    IF v_same_text AND (v_row.source = 'user'
                        OR (v_row.status = 'resolved' AND v_row.catalog_version = v_version)) THEN
      v_p_current := v_p_current + 1;
      CONTINUE;
    END IF;

    SELECT * INTO r FROM public.region_resolve_legacy_pair(v_state_label, v_district_label);
    IF v_same_text AND v_row.status = r.status
       AND v_row.state_code IS NOT DISTINCT FROM r.state_code
       AND v_row.district_code IS NOT DISTINCT FROM r.district_code
       AND v_row.catalog_version = v_version THEN
      v_p_current := v_p_current + 1;
      -- Same text, same answer: keep an open item's reason and candidates current.
      SELECT count(*) INTO v_n FROM public.region_resolution_queue q
       WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
         AND public.region_labels_equal(q.raw_state_label, v_state_label)
         AND public.region_labels_equal(q.raw_district_label, v_district_label)
         AND (q.reason IS DISTINCT FROM r.reason OR q.candidate_codes IS DISTINCT FROM r.candidate_codes);
      v_updated := v_updated + v_n;
      IF p_apply AND v_n > 0 THEN
        UPDATE public.region_resolution_queue q SET reason = r.reason, candidate_codes = r.candidate_codes
         WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
           AND public.region_labels_equal(q.raw_state_label, v_state_label)
           AND public.region_labels_equal(q.raw_district_label, v_district_label);
      END IF;
      CONTINUE;
    END IF;

    IF r.status = 'resolved' THEN
      v_p_resolved := v_p_resolved + 1;
    ELSE
      v_p_needs := v_p_needs + 1;
    END IF;
    -- Items this text closes: every open one when it resolves, otherwise those
    -- for other text.
    SELECT count(*) INTO v_n FROM public.region_resolution_queue q
     WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
       AND (r.status = 'resolved'
            OR NOT (public.region_labels_equal(q.raw_state_label, v_state_label)
                    AND public.region_labels_equal(q.raw_district_label, v_district_label)));
    v_closed := v_closed + v_n;
    IF p_apply THEN
      INSERT INTO public.profile_regions AS x
             (user_id, state_code, district_code, catalog_version, status, source,
              legacy_state_label, legacy_district_label, updated_at)
      VALUES (v_id, r.state_code, r.district_code, v_version, r.status, 'legacy_backfill',
              v_state_label, v_district_label, now())
      ON CONFLICT (user_id) DO UPDATE
         SET state_code = EXCLUDED.state_code, district_code = EXCLUDED.district_code,
             catalog_version = EXCLUDED.catalog_version, status = EXCLUDED.status,
             source = EXCLUDED.source, legacy_state_label = EXCLUDED.legacy_state_label,
             legacy_district_label = EXCLUDED.legacy_district_label, updated_at = now()
       WHERE x.source <> 'user'
          OR NOT (public.region_labels_equal(x.legacy_state_label, EXCLUDED.legacy_state_label)
                  AND public.region_labels_equal(x.legacy_district_label, EXCLUDED.legacy_district_label));
      UPDATE public.region_resolution_queue q
         SET status = CASE WHEN r.status = 'resolved' THEN 'resolved' ELSE 'superseded' END,
             resolved_at = now()
       WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
         AND (r.status = 'resolved'
              OR NOT (public.region_labels_equal(q.raw_state_label, v_state_label)
                      AND public.region_labels_equal(q.raw_district_label, v_district_label)));
    END IF;

    IF r.status <> 'resolved' THEN
      IF EXISTS (SELECT 1 FROM public.region_resolution_queue q
                  WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
                    AND public.region_labels_equal(q.raw_state_label, v_state_label)
                    AND public.region_labels_equal(q.raw_district_label, v_district_label)) THEN
        SELECT count(*) INTO v_n FROM public.region_resolution_queue q
         WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
           AND public.region_labels_equal(q.raw_state_label, v_state_label)
           AND public.region_labels_equal(q.raw_district_label, v_district_label)
           AND (q.reason IS DISTINCT FROM r.reason OR q.candidate_codes IS DISTINCT FROM r.candidate_codes);
        v_updated := v_updated + v_n;
        IF p_apply AND v_n > 0 THEN
          UPDATE public.region_resolution_queue q SET reason = r.reason, candidate_codes = r.candidate_codes
           WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id AND q.status = 'open'
             AND public.region_labels_equal(q.raw_state_label, v_state_label)
             AND public.region_labels_equal(q.raw_district_label, v_district_label);
        END IF;
      ELSIF NOT EXISTS (SELECT 1 FROM public.region_resolution_queue q
                         WHERE q.subject_kind = 'profile_home' AND q.subject_user_id = v_id
                           AND q.status = 'dismissed'
                           AND public.region_labels_equal(q.raw_state_label, v_state_label)
                           AND public.region_labels_equal(q.raw_district_label, v_district_label)) THEN
        v_added := v_added + 1;
        IF p_apply THEN
          INSERT INTO public.region_resolution_queue
                 (subject_kind, subject_user_id, raw_state_label, raw_district_label, reason,
                  candidate_codes, catalog_version)
          VALUES ('profile_home', v_id, v_state_label, v_district_label, r.reason, r.candidate_codes, v_version)
          ON CONFLICT DO NOTHING;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- Engineers with service-area text, backfilled rows, or open items.
  FOR v_id IN
    SELECT en.id FROM public.engineers en
     WHERE coalesce(cardinality(en.service_areas), 0) > 0
        OR EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                    WHERE esd.engineer_id = en.id AND esd.source = 'legacy_backfill')
        OR EXISTS (SELECT 1 FROM public.region_resolution_queue q
                    WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = en.user_id
                      AND q.status = 'open')
     ORDER BY en.id
  LOOP
    v_e_considered := v_e_considered + 1;
    IF p_apply THEN
      SELECT en.user_id, en.state, en.service_areas INTO v_user, v_kyc_state, v_areas
        FROM public.engineers en WHERE en.id = v_id FOR UPDATE;
    ELSE
      SELECT en.user_id, en.state, en.service_areas INTO v_user, v_kyc_state, v_areas
        FROM public.engineers en WHERE en.id = v_id;
    END IF;
    IF EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                WHERE esd.engineer_id = v_id AND esd.source = 'engineer') THEN
      v_e_chosen := v_e_chosen + 1;
      CONTINUE;
    END IF;

    SELECT pf.state INTO v_profile_state FROM public.profiles pf WHERE pf.id = v_user;
    v_scope_label := CASE WHEN public.region_normalize_label(v_kyc_state) IS NOT NULL
                          THEN v_kyc_state ELSE v_profile_state END;
    v_scope := public.region_resolve_state_label(v_scope_label);

    v_seen := '{}'; v_resolved := '{}'; v_resolved_labels := '{}';
    v_un_labels := '{}'; v_un_reasons := '{}'; v_un_candidates := '[]'::jsonb;
    FOREACH v_label IN ARRAY coalesce(v_areas, '{}'::text[]) LOOP
      v_norm := public.region_normalize_label(v_label);
      CONTINUE WHEN v_norm IS NULL OR v_norm = ANY (v_seen);
      v_seen := v_seen || v_norm;
      v_candidates := CASE WHEN v_scope IS NULL THEN '{}'::text[]
                           ELSE public.region_district_candidates(v_scope, v_label) END;
      IF cardinality(v_candidates) = 1 THEN
        IF NOT (v_candidates[1] = ANY (v_resolved)) THEN
          v_resolved := v_resolved || v_candidates[1];
          v_resolved_labels := v_resolved_labels || v_label;
        END IF;
      ELSE
        v_un_labels := v_un_labels || v_label;
        v_un_reasons := v_un_reasons || CASE WHEN v_scope IS NULL THEN 'state_unknown'
                                             WHEN cardinality(v_candidates) = 0 THEN 'no_match'
                                             ELSE 'ambiguous' END;
        v_un_candidates := v_un_candidates || jsonb_build_array(to_jsonb(v_candidates));
      END IF;
    END LOOP;

    v_over := cardinality(v_resolved) > c_max;
    v_target := CASE WHEN v_over THEN '{}'::text[]
                     ELSE coalesce((SELECT array_agg(c ORDER BY c) FROM unnest(v_resolved) c), '{}') END;
    SELECT coalesce(array_agg(esd.district_code ORDER BY esd.district_code), '{}')
      INTO v_existing
      FROM public.engineer_service_districts esd
     WHERE esd.engineer_id = v_id AND esd.source = 'legacy_backfill';
    v_restamp := EXISTS (SELECT 1 FROM public.engineer_service_districts esd
                          WHERE esd.engineer_id = v_id AND esd.source = 'legacy_backfill'
                            AND esd.catalog_version <> v_version);
    v_expected := CASE WHEN v_over THEN ARRAY[c_too_many]
                       ELSE coalesce((SELECT array_agg(public.region_normalize_label(l)) FROM unnest(v_un_labels) l), '{}') END;
    SELECT count(*) INTO v_open_vanished
      FROM public.region_resolution_queue q
     WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
       AND NOT (CASE WHEN q.reason = 'too_many' THEN c_too_many
                     ELSE public.region_normalize_label(q.raw_district_label) END = ANY (v_expected));
    SELECT count(*) INTO v_missing
      FROM unnest(v_expected) x(label)
     WHERE NOT EXISTS (
       SELECT 1 FROM public.region_resolution_queue q
        WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user
          AND q.status IN ('open', 'dismissed')
          AND CASE WHEN q.reason = 'too_many' THEN c_too_many
                   ELSE public.region_normalize_label(q.raw_district_label) END = x.label);
    -- Open items for text that is still expected but whose details changed.
    IF v_over THEN
      SELECT count(*) INTO v_stale_items
        FROM public.region_resolution_queue q
       WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
         AND q.reason = 'too_many'
         AND (q.raw_state_label IS DISTINCT FROM v_scope_label
              OR q.candidate_codes IS DISTINCT FROM (SELECT array_agg(c ORDER BY c) FROM unnest(v_resolved) c));
    ELSE
      v_stale_items := 0;
      FOR i IN 1 .. coalesce(cardinality(v_un_labels), 0) LOOP
        v_cand := ARRAY(SELECT jsonb_array_elements_text(v_un_candidates -> (i - 1)));
        SELECT v_stale_items + count(*) INTO v_stale_items
          FROM public.region_resolution_queue q
         WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
           AND q.reason <> 'too_many'
           AND public.region_labels_equal(q.raw_district_label, v_un_labels[i])
           AND (q.reason IS DISTINCT FROM v_un_reasons[i]
                OR q.candidate_codes IS DISTINCT FROM v_cand
                OR q.raw_state_label IS DISTINCT FROM v_scope_label);
      END LOOP;
    END IF;

    IF v_existing = v_target AND NOT v_restamp
       AND v_open_vanished = 0 AND v_missing = 0 AND v_stale_items = 0 THEN
      v_e_current := v_e_current + 1;
      CONTINUE;
    END IF;
    IF v_over THEN
      v_e_over := v_e_over + 1;
    ELSE
      v_s_resolved := v_s_resolved + cardinality(v_resolved);
      v_s_needs := v_s_needs + cardinality(v_un_labels);
    END IF;
    v_closed := v_closed + v_open_vanished;
    v_added := v_added + v_missing;
    v_updated := v_updated + v_stale_items;

    IF p_apply THEN
      DELETE FROM public.engineer_service_districts esd
       WHERE esd.engineer_id = v_id AND esd.source = 'legacy_backfill'
         AND NOT (esd.district_code = ANY (v_target));
      IF NOT v_over THEN
        INSERT INTO public.engineer_service_districts AS esd
               (engineer_id, district_code, catalog_version, source, label_snapshot)
        SELECT v_id, t.code, v_version, 'legacy_backfill', t.label
          FROM unnest(v_resolved, v_resolved_labels) AS t(code, label)
        ON CONFLICT (engineer_id, district_code) DO UPDATE
           SET catalog_version = EXCLUDED.catalog_version, label_snapshot = EXCLUDED.label_snapshot
         WHERE esd.source = 'legacy_backfill';
      END IF;

      UPDATE public.region_resolution_queue q SET status = 'superseded', resolved_at = now()
       WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
         AND NOT (CASE WHEN q.reason = 'too_many' THEN c_too_many
                       ELSE public.region_normalize_label(q.raw_district_label) END = ANY (v_expected));

      IF v_over THEN
        UPDATE public.region_resolution_queue q
           SET raw_state_label = v_scope_label,
               candidate_codes = (SELECT array_agg(c ORDER BY c) FROM unnest(v_resolved) c)
         WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
           AND q.reason = 'too_many';
        INSERT INTO public.region_resolution_queue
               (subject_kind, subject_user_id, raw_state_label, raw_district_label, reason,
                candidate_codes, catalog_version)
        SELECT 'engineer_service', v_user, v_scope_label, NULL, 'too_many',
               (SELECT array_agg(c ORDER BY c) FROM unnest(v_resolved) c), v_version
         WHERE NOT EXISTS (
           SELECT 1 FROM public.region_resolution_queue q
            WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user
              AND q.status IN ('open', 'dismissed') AND q.reason = 'too_many')
        ON CONFLICT DO NOTHING;
      ELSE
        FOR i IN 1 .. coalesce(cardinality(v_un_labels), 0) LOOP
          v_cand := ARRAY(SELECT jsonb_array_elements_text(v_un_candidates -> (i - 1)));
          UPDATE public.region_resolution_queue q
             SET reason = v_un_reasons[i], candidate_codes = v_cand, raw_state_label = v_scope_label
           WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user AND q.status = 'open'
             AND q.reason <> 'too_many'
             AND public.region_labels_equal(q.raw_district_label, v_un_labels[i]);
          INSERT INTO public.region_resolution_queue
                 (subject_kind, subject_user_id, raw_state_label, raw_district_label, reason,
                  candidate_codes, catalog_version)
          SELECT 'engineer_service', v_user, v_scope_label, v_un_labels[i], v_un_reasons[i], v_cand, v_version
           WHERE NOT EXISTS (
             SELECT 1 FROM public.region_resolution_queue q
              WHERE q.subject_kind = 'engineer_service' AND q.subject_user_id = v_user
                AND q.status IN ('open', 'dismissed') AND q.reason <> 'too_many'
                AND public.region_labels_equal(q.raw_district_label, v_un_labels[i]))
          ON CONFLICT DO NOTHING;
        END LOOP;
      END IF;
    END IF;
  END LOOP;

  -- Open service items of users who are no longer engineers.
  SELECT count(*) INTO v_n FROM public.region_resolution_queue q
   WHERE q.subject_kind = 'engineer_service' AND q.status = 'open'
     AND NOT EXISTS (SELECT 1 FROM public.engineers e WHERE e.user_id = q.subject_user_id);
  v_closed := v_closed + v_n;
  IF p_apply AND v_n > 0 THEN
    UPDATE public.region_resolution_queue q SET status = 'superseded', resolved_at = now()
     WHERE q.subject_kind = 'engineer_service' AND q.status = 'open'
       AND NOT EXISTS (SELECT 1 FROM public.engineers e WHERE e.user_id = q.subject_user_id);
  END IF;

  RETURN QUERY SELECT v_p_considered, v_p_current, v_p_resolved, v_p_needs, v_p_cleared,
                      v_e_considered, v_e_chosen, v_e_current, v_e_over,
                      v_s_resolved, v_s_needs, v_added, v_closed, v_updated;
END;
$$;

-- ---------------------------------------------------------------------
-- Function grants
-- ---------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.region_normalize_label(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_labels_equal(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_current_version() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_resolve_state_label(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_district_candidates(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_require_writable_version(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.region_in_version(text, bigint) FROM PUBLIC, anon, authenticated;
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
  v_role text;
  v_priv text;
  v_seq text;
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
    FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
      FOREACH v_priv IN ARRAY ARRAY['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
        IF has_table_privilege(v_role, v_table, v_priv) THEN
          v_bad := v_bad || (lower(v_priv) || ' granted to ' || v_role || ' on ' || v_table);
        END IF;
      END LOOP;
      FOREACH v_priv IN ARRAY ARRAY['INSERT', 'UPDATE', 'REFERENCES'] LOOP
        IF has_any_column_privilege(v_role, v_table, v_priv) THEN
          v_bad := v_bad || ('column ' || lower(v_priv) || ' granted to ' || v_role || ' on ' || v_table);
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  FOREACH v_table IN ARRAY ARRAY['public.profile_regions', 'public.engineer_service_districts',
                                  'public.region_resolution_queue'] LOOP
    IF has_table_privilege('anon', v_table, 'SELECT') OR has_any_column_privilege('anon', v_table, 'SELECT') THEN
      v_bad := v_bad || ('anon select on ' || v_table);
    END IF;
  END LOOP;
  IF has_table_privilege('authenticated', 'public.region_resolution_queue', 'SELECT')
     OR has_any_column_privilege('authenticated', 'public.region_resolution_queue', 'SELECT') THEN
    v_bad := v_bad || 'authenticated select on public.region_resolution_queue'::text;
  END IF;
  FOREACH v_seq IN ARRAY ARRAY['public.region_resolution_queue_id_seq', 'public.region_catalog_versions_ordinal_seq'] LOOP
    FOREACH v_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
      FOREACH v_priv IN ARRAY ARRAY['USAGE', 'SELECT', 'UPDATE'] LOOP
        IF has_sequence_privilege(v_role, v_seq, v_priv) THEN
          v_bad := v_bad || (lower(v_priv) || ' granted to ' || v_role || ' on ' || v_seq);
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

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
    'public.region_normalize_label(text)', 'public.region_labels_equal(text,text)',
    'public.region_current_version()', 'public.region_resolve_state_label(text)',
    'public.region_district_candidates(text,text)', 'public.region_require_writable_version(text)',
    'public.region_in_version(text,bigint)', 'public.region_resolve_legacy_pair(text,text)'
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
