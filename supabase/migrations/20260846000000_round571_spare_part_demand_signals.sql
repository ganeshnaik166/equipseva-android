-- Round 571 — Spare-part demand signals (v0.5 P3 #2 marketplace seed)
--
-- WHY: r500 bonded provenance solves WHO supplies parts. But we have no
-- intel on WHAT parts the market wants and we don't carry. Today a
-- hospital types "Mindray BeneView power board" into the in-app search,
-- gets zero results, and we never hear about it. This migration plants
-- a tiny ledger that captures every "search → no results" or "RFQ → no
-- supplier" event, lets the founder dashboard surface aggregated
-- demand, and tracks resolution (which signals turned into a bonded
-- intake or supplier onboarding).
--
-- 4 entry points (low-tax to the client):
--   record_spare_part_demand_signal(...)  — auth required, called by
--     the spare-parts search endpoint when a query returns 0 rows OR
--     by the RFQ flow when a hospital's request has no eligible
--     supplier. Engineers can also call it manually from a "couldn't
--     find this part" UI.
--   founder_demand_signal_dashboard()     — top-25 aggregated by
--     (brand, model, part_number) with count + last_seen + max
--     urgency. Drives the /demand-signals web console surface.
--   founder_resolve_demand_signal(id,via,notes)
--   founder_set_demand_signal_priority(id, p)
--
-- Append-only-ish: rows can be UPDATEd by founder-only RPC (mutates
-- resolved_at/resolved_via/founder_priority/notes only). No DELETE.

BEGIN;

CREATE TABLE IF NOT EXISTS public.spare_part_demand_signals (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Who reported (NULL for sysgen/anon — we still want the signal
  -- even if the user is not authenticated, but in practice the RPC
  -- is auth-gated so this is mostly redundant w/ auth.uid()).
  reporter_user_id      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  reporter_role         text        CHECK (reporter_role IS NULL OR reporter_role IN ('engineer','hospital','founder','system')),

  -- Demand subject — at least one of part_number/equipment_model must
  -- be supplied, enforced below.
  equipment_brand       text,
  equipment_model       text,
  part_number           text,
  part_description      text,
  search_query_norm     text,

  -- Source channel that emitted this signal.
  source                text        NOT NULL
                                    CHECK (source IN (
                                      'search_no_results',
                                      'rfq_no_supplier',
                                      'low_stock_match',
                                      'manual_founder',
                                      'engineer_report'
                                    )),

  hospital_org_id       uuid        REFERENCES public.organizations(id) ON DELETE SET NULL,
  job_id                uuid        REFERENCES public.repair_jobs(id)   ON DELETE SET NULL,

  urgency               text        NOT NULL DEFAULT 'standard'
                                    CHECK (urgency IN ('standard','urgent','critical')),

  occurred_at           timestamptz NOT NULL DEFAULT now(),
  resolved_at           timestamptz,
  resolved_via          text        CHECK (resolved_via IS NULL OR resolved_via IN (
                                      'supplier_onboarded',
                                      'bonded_intake',
                                      'duplicate_of_existing',
                                      'wont_fulfill',
                                      'fulfilled_offplatform'
                                    )),
  resolved_by_user_id   uuid        REFERENCES auth.users(id) ON DELETE SET NULL,

  founder_priority      text        CHECK (founder_priority IS NULL OR founder_priority IN ('low','med','high')),
  notes                 text,

  -- At least one of part_number or equipment_model must be present so
  -- the founder dashboard can group by something meaningful.
  CONSTRAINT spds_subject_present
    CHECK (part_number IS NOT NULL OR equipment_model IS NOT NULL OR equipment_brand IS NOT NULL OR part_description IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_spds_unresolved
  ON public.spare_part_demand_signals (occurred_at DESC)
  WHERE resolved_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_spds_brand_model
  ON public.spare_part_demand_signals (equipment_brand, equipment_model);

CREATE INDEX IF NOT EXISTS idx_spds_part_number
  ON public.spare_part_demand_signals (part_number)
  WHERE part_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_spds_reporter
  ON public.spare_part_demand_signals (reporter_user_id, occurred_at DESC);

-- ----------------------------------------------------------------
-- RLS: hard lock. All access via SECDEF RPCs.
-- ----------------------------------------------------------------
ALTER TABLE public.spare_part_demand_signals ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  -- No SELECT policy for anon/authenticated. Founder uses SECDEF RPC.
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'spare_part_demand_signals'
      AND policyname = 'spds_no_access'
  ) THEN
    -- Empty USING clause = nothing visible. Explicit deny-all is more
    -- legible than absent-policy = no-access.
    CREATE POLICY spds_no_access
      ON public.spare_part_demand_signals
      FOR ALL
      TO public, anon, authenticated
      USING (false)
      WITH CHECK (false);
  END IF;
END $$;

-- Defensive REVOKE — table-level first, then column-level grants if we
-- ever need them. Per the [[pg-column-revoke-gotcha]] memory.
REVOKE ALL ON public.spare_part_demand_signals FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------
-- RPC: record_spare_part_demand_signal
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid);
CREATE OR REPLACE FUNCTION public.record_spare_part_demand_signal(
  p_part_number      text,
  p_brand            text,
  p_model            text,
  p_query            text,
  p_source           text,
  p_urgency          text DEFAULT 'standard',
  p_job_id           uuid DEFAULT NULL,
  p_hospital_org_id  uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   uuid := auth.uid();
  v_role  text;
  v_id    uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required'
      USING ERRCODE = '42501';
  END IF;

  IF p_source NOT IN ('search_no_results','rfq_no_supplier','low_stock_match','manual_founder','engineer_report') THEN
    RAISE EXCEPTION 'unknown source: %', p_source
      USING ERRCODE = '22023';
  END IF;

  IF p_urgency NOT IN ('standard','urgent','critical') THEN
    RAISE EXCEPTION 'unknown urgency: %', p_urgency
      USING ERRCODE = '22023';
  END IF;

  -- Subject sanity — must have something to group on.
  IF coalesce(nullif(trim(p_part_number),''), nullif(trim(p_model),''), nullif(trim(p_brand),''), nullif(trim(p_query),'')) IS NULL THEN
    RAISE EXCEPTION 'demand signal must include part_number, brand/model, or a non-empty query'
      USING ERRCODE = '22023';
  END IF;

  -- Best-effort role classification from profiles. Silently 'system'
  -- if not derivable.
  BEGIN
    SELECT lower(coalesce(p.role::text,'system')) INTO v_role
      FROM public.profiles p
     WHERE p.id = v_uid
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_role := 'system';
  END;
  IF v_role NOT IN ('engineer','hospital','founder','system') THEN
    v_role := 'system';
  END IF;

  INSERT INTO public.spare_part_demand_signals (
    reporter_user_id, reporter_role,
    equipment_brand, equipment_model, part_number, part_description, search_query_norm,
    source, hospital_org_id, job_id, urgency
  ) VALUES (
    v_uid, v_role,
    nullif(trim(p_brand),''), nullif(trim(p_model),''), nullif(trim(p_part_number),''),
    NULL, nullif(trim(p_query),''),
    p_source, p_hospital_org_id, p_job_id, p_urgency
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_spare_part_demand_signal(text,text,text,text,text,text,uuid,uuid) TO authenticated;

-- ----------------------------------------------------------------
-- RPC: founder_demand_signal_dashboard
-- Returns one row per (brand, model, part_number) group with rollup
-- stats. Unresolved rows only. Sorted by signal_count DESC, last_seen
-- DESC. Top 25.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_demand_signal_dashboard();
CREATE OR REPLACE FUNCTION public.founder_demand_signal_dashboard()
RETURNS TABLE (
  group_key          text,
  equipment_brand    text,
  equipment_model    text,
  part_number        text,
  signal_count       bigint,
  unique_reporters   bigint,
  last_seen          timestamptz,
  max_urgency        text,
  has_critical       boolean,
  founder_priority   text,
  any_unresolved_id  uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT
      coalesce(lower(s.equipment_brand),'?')   ||'|'||
      coalesce(lower(s.equipment_model),'?')   ||'|'||
      coalesce(lower(s.part_number),'?')              AS group_key,
      max(s.equipment_brand)                          AS equipment_brand,
      max(s.equipment_model)                          AS equipment_model,
      max(s.part_number)                              AS part_number,
      count(*)::bigint                                AS signal_count,
      count(DISTINCT s.reporter_user_id)::bigint      AS unique_reporters,
      max(s.occurred_at)                              AS last_seen,
      CASE
        WHEN bool_or(s.urgency = 'critical') THEN 'critical'
        WHEN bool_or(s.urgency = 'urgent')   THEN 'urgent'
        ELSE 'standard'
      END                                             AS max_urgency,
      bool_or(s.urgency = 'critical')                 AS has_critical,
      -- Any non-null priority on the most-recent unresolved row
      max(s.founder_priority)                         AS founder_priority,
      (array_agg(s.id ORDER BY s.occurred_at DESC))[1] AS any_unresolved_id
    FROM public.spare_part_demand_signals s
    WHERE s.resolved_at IS NULL
    GROUP BY 1
  )
  SELECT * FROM agg
  ORDER BY signal_count DESC, last_seen DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_demand_signal_dashboard() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signal_dashboard() TO authenticated;

-- ----------------------------------------------------------------
-- RPC: founder_resolve_demand_signal
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_resolve_demand_signal(uuid,text,text);
CREATE OR REPLACE FUNCTION public.founder_resolve_demand_signal(
  p_id    uuid,
  p_via   text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text;
  v_before jsonb;
  v_row    public.spare_part_demand_signals;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_via NOT IN ('supplier_onboarded','bonded_intake','duplicate_of_existing','wont_fulfill','fulfilled_offplatform') THEN
    RAISE EXCEPTION 'unknown resolved_via: %', p_via USING ERRCODE = '22023';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  -- Lock + read existing.
  SELECT * INTO v_row
    FROM public.spare_part_demand_signals
   WHERE id = p_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demand signal not found: %', p_id USING ERRCODE = 'P0002';
  END IF;
  IF v_row.resolved_at IS NOT NULL THEN
    RAISE EXCEPTION 'demand signal already resolved at %', v_row.resolved_at USING ERRCODE = '0L000';
  END IF;

  v_before := to_jsonb(v_row);

  UPDATE public.spare_part_demand_signals
     SET resolved_at         = now(),
         resolved_via        = p_via,
         resolved_by_user_id = v_uid,
         notes               = coalesce(p_notes, notes)
   WHERE id = p_id;

  INSERT INTO public.founder_action_log (
    actor_user_id, actor_email, op_name, target_table, target_row_id,
    before_value, after_value, reason, outcome
  ) VALUES (
    v_uid, coalesce(v_email,'?'), 'resolve_demand_signal',
    'spare_part_demand_signals', p_id,
    v_before,
    jsonb_build_object('resolved_via', p_via, 'notes', p_notes),
    p_notes,
    'success'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_resolve_demand_signal(uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_resolve_demand_signal(uuid,text,text) TO authenticated;

-- ----------------------------------------------------------------
-- RPC: founder_set_demand_signal_priority
-- Bulk-set priority on every unresolved signal sharing the group key.
-- We accept the group_key string so the founder can prioritize "every
-- mindray|beneview|*" row, not just a single one.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_set_demand_signal_priority(uuid,text);
CREATE OR REPLACE FUNCTION public.founder_set_demand_signal_priority(
  p_any_signal_id uuid,
  p_priority      text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_email  text;
  v_brand  text;
  v_model  text;
  v_part   text;
  v_count  bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_priority NOT IN ('low','med','high') AND p_priority IS NOT NULL THEN
    RAISE EXCEPTION 'unknown priority: %', p_priority USING ERRCODE = '22023';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  SELECT lower(equipment_brand), lower(equipment_model), lower(part_number)
    INTO v_brand, v_model, v_part
    FROM public.spare_part_demand_signals
   WHERE id = p_any_signal_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'demand signal not found: %', p_any_signal_id USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.spare_part_demand_signals
     SET founder_priority = p_priority
   WHERE resolved_at IS NULL
     AND coalesce(lower(equipment_brand),'?') = coalesce(v_brand,'?')
     AND coalesce(lower(equipment_model),'?') = coalesce(v_model,'?')
     AND coalesce(lower(part_number),'?')     = coalesce(v_part,'?');
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log (
    actor_user_id, actor_email, op_name, target_table, target_row_id,
    after_value, reason, outcome
  ) VALUES (
    v_uid, coalesce(v_email,'?'), 'set_demand_signal_priority',
    'spare_part_demand_signals', p_any_signal_id,
    jsonb_build_object('priority', p_priority, 'affected_rows', v_count, 'group_brand', v_brand, 'group_model', v_model, 'group_part', v_part),
    p_priority,
    'success'
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_set_demand_signal_priority(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_set_demand_signal_priority(uuid,text) TO authenticated;

COMMIT;
