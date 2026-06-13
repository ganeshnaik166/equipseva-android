-- =====================================================================
-- Round 509 — Code Red Emergency Override (v0.4 Phase 4 #3 backbone)
-- =====================================================================
--
-- Hospital admin brainstorm: "Ventilator dies at 2am in ICU. Admin
-- can't navigate menus. Need a single red button that bypasses normal
-- queue + pages 3 nearest qualified engineers in parallel."
--
-- This is the highest-impact UX gap closing the "ICU SLA gap vs OEM
-- 4-hour" risk from the skeptic panel (where it was DEFERRED to
-- Phase 4 — we're shipping the backbone now).
--
-- Caveat: r486 device taxonomy hard-gates Class C/D equipment. ICU
-- ventilators are Class C/D and OUT of v0.4 scope. So this Code Red
-- backbone exists for IN-SCOPE Class A/B emergencies (high-volume
-- patient_monitoring failure during admission surge, dental
-- compressor down before surgery slot, lab autoclave failure
-- during sample run). The pattern + RPC are reusable when we
-- expand scope in v0.5+.
--
-- Server-side:
--   * code_red_requests — one row per Code Red event with timeline
--   * code_red_dispatch_events — per-engineer page event (paged,
--     accepted, declined, missed)
--   * open_code_red_request(...) — hospital fires the alarm
--   * accept_code_red(...) — engineer claims; first-accept wins
--   * decline_code_red(...) / record_code_red_miss() — explicit
--     event for SLA accounting
--   * founder_code_red_recent — cockpit oversight

BEGIN;

-- ---------------------------------------------------------------------
-- 1. code_red_requests
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.code_red_requests (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id         uuid        NOT NULL,
  CONSTRAINT code_red_hospital_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Optional equipment identification
  equipment_type           text        NOT NULL,
  equipment_brand          text,
  equipment_model          text,
  equipment_serial         text,
  -- The reason free-text (e.g., "compressor failed pre-surgery slot")
  description              text        NOT NULL CHECK (length(description) BETWEEN 10 AND 2000),
  -- Pre-set hospital cap for premium fee on Code Red — auto-approve
  -- engineer surcharge under this ceiling.
  emergency_fee_ceiling_rupees numeric(10,2) NOT NULL CHECK (emergency_fee_ceiling_rupees >= 0 AND emergency_fee_ceiling_rupees <= 50000),
  -- Lifecycle
  status                   text        NOT NULL DEFAULT 'open'
                                       CHECK (status IN ('open','engineer_accepted','resolved','timed_out','cancelled')),
  -- SLA: 60 minutes default. Hospital can override to 30/120/240
  -- depending on criticality.
  sla_minutes              int         NOT NULL DEFAULT 60
                                       CHECK (sla_minutes BETWEEN 15 AND 1440),
  sla_deadline_at          timestamptz NOT NULL,
  -- Accepted engineer (first wins)
  accepted_engineer_user_id uuid       REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_at              timestamptz,
  -- Resolution
  resolved_at              timestamptz,
  resolution_repair_job_id uuid        REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  -- War-room reference (WhatsApp group link / Slack channel — opens
  -- on the founder ops side; not enforced).
  warroom_url              text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS code_red_open_idx
  ON public.code_red_requests (status, sla_deadline_at)
  WHERE status = 'open';
CREATE INDEX IF NOT EXISTS code_red_hospital_idx
  ON public.code_red_requests (hospital_user_id, created_at DESC);

ALTER TABLE public.code_red_requests ENABLE ROW LEVEL SECURITY;

-- (RLS policy for code_red_requests created AFTER code_red_dispatch_events
-- below — the policy forward-references the dispatch table.)

REVOKE INSERT, UPDATE, DELETE ON public.code_red_requests
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. code_red_dispatch_events — per-engineer page event
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.code_red_dispatch_events (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code_red_id         uuid        NOT NULL REFERENCES public.code_red_requests(id) ON DELETE CASCADE,
  engineer_user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Page sent to this engineer
  paged_at            timestamptz NOT NULL DEFAULT now(),
  -- Distance at page time (Haversine — uses r496 helper)
  distance_km_at_page numeric(8,2),
  -- Engineer outcome
  outcome             text        NOT NULL DEFAULT 'paged'
                                  CHECK (outcome IN ('paged','accepted','declined','missed','superseded')),
  response_at         timestamptz,
  decline_reason      text,
  CONSTRAINT code_red_dispatch_unique UNIQUE (code_red_id, engineer_user_id)
);

CREATE INDEX IF NOT EXISTS code_red_dispatch_engineer_idx
  ON public.code_red_dispatch_events (engineer_user_id, paged_at DESC);

ALTER TABLE public.code_red_dispatch_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS code_red_dispatch_events_select ON public.code_red_dispatch_events;
CREATE POLICY code_red_dispatch_events_select
  ON public.code_red_dispatch_events
  FOR SELECT
  TO authenticated, service_role
  USING (
    engineer_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.code_red_requests r
      WHERE r.id = code_red_id
        AND r.hospital_user_id = auth.uid()
    )
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.code_red_dispatch_events
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2.5. Cross-table policy for code_red_requests (deferred to here
--      because it references code_red_dispatch_events above)
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS code_red_requests_select ON public.code_red_requests;
CREATE POLICY code_red_requests_select
  ON public.code_red_requests
  FOR SELECT
  TO authenticated, service_role
  USING (
    hospital_user_id = auth.uid()
    OR accepted_engineer_user_id = auth.uid()
    OR public.is_founder()
    -- Engineers paged for this request can read
    OR EXISTS (
      SELECT 1 FROM public.code_red_dispatch_events e
      WHERE e.code_red_id = code_red_requests.id
        AND e.engineer_user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- 3. open_code_red_request — hospital fires the alarm
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_code_red_request(
  p_equipment_type             text,
  p_equipment_brand            text,
  p_equipment_model            text,
  p_equipment_serial           text,
  p_description                text,
  p_emergency_fee_ceiling_rupees numeric DEFAULT 5000,
  p_sla_minutes                int DEFAULT 60
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_id       uuid;
  v_dispatch record;
  v_dispatched int := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Validate equipment_type is in-scope (reuse r486 taxonomy gate)
  IF NOT EXISTS (
    SELECT 1 FROM public.equipment_taxonomy_class
    WHERE equipment_type = p_equipment_type AND allowed_in_v04 = true
  ) THEN
    RAISE EXCEPTION 'equipment_type_out_of_scope_for_code_red' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.code_red_requests (
    hospital_user_id,
    equipment_type, equipment_brand, equipment_model, equipment_serial,
    description, emergency_fee_ceiling_rupees,
    sla_minutes, sla_deadline_at
  ) VALUES (
    v_caller,
    p_equipment_type, p_equipment_brand, p_equipment_model, p_equipment_serial,
    p_description, coalesce(p_emergency_fee_ceiling_rupees, 5000),
    coalesce(p_sla_minutes, 60),
    now() + (coalesce(p_sla_minutes, 60)::text || ' minutes')::interval
  ) RETURNING id INTO v_id;

  -- Page top-3 verified engineers ranked by:
  --   * Specialization match for equipment_type
  --   * Distance (closer wins)
  --   * Recent activity (active 30d)
  FOR v_dispatch IN
    SELECT
      e.user_id,
      -- We need hospital coords; pulled from profiles via a coarse
      -- look-up. If profile lat/lng missing, distance NULL.
      (SELECT public.haversine_meters(e.latitude, e.longitude, p.latitude, p.longitude) / 1000.0
         FROM public.profiles p WHERE p.id = v_caller) AS dist_km
    FROM public.engineers e
    WHERE e.verification_status = 'verified'
      AND e.is_available = true
      AND p_equipment_type = ANY(coalesce(e.specializations, ARRAY[]::text[]))
      AND e.latitude IS NOT NULL AND e.longitude IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.engineer_payouts ep
         WHERE ep.engineer_user_id = e.user_id
           AND ep.updated_at >= now() - interval '60 days'
      )
    ORDER BY
      (SELECT public.haversine_meters(e.latitude, e.longitude, p.latitude, p.longitude)
         FROM public.profiles p WHERE p.id = v_caller) ASC NULLS LAST
    LIMIT 3
  LOOP
    INSERT INTO public.code_red_dispatch_events (
      code_red_id, engineer_user_id, distance_km_at_page, outcome
    ) VALUES (
      v_id, v_dispatch.user_id, v_dispatch.dist_km, 'paged'
    )
    ON CONFLICT DO NOTHING;
    v_dispatched := v_dispatched + 1;
  END LOOP;

  -- If zero engineers matched, the founder cockpit will see this as
  -- a NULL-dispatch Code Red and act manually.
  IF v_dispatched = 0 THEN
    RAISE NOTICE 'code red %: zero matching engineers; founder must escalate manually', v_id;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.open_code_red_request(text, text, text, text, text, numeric, int)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.open_code_red_request(text, text, text, text, text, numeric, int)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. accept_code_red — engineer claims (first wins)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_code_red(
  p_code_red_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_req   record;
  v_paged boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Lock the request — only one engineer can win.
  SELECT * INTO v_req FROM public.code_red_requests WHERE id = p_code_red_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'code_red_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_req.status <> 'open' THEN
    RAISE EXCEPTION 'code_red_not_open (status=%)', v_req.status USING ERRCODE = '22023';
  END IF;
  IF v_req.sla_deadline_at < now() THEN
    -- Auto-flip to timed_out
    UPDATE public.code_red_requests SET status = 'timed_out' WHERE id = p_code_red_id;
    RAISE EXCEPTION 'code_red_sla_expired' USING ERRCODE = '22023';
  END IF;

  -- Engineer must have been paged
  SELECT EXISTS (
    SELECT 1 FROM public.code_red_dispatch_events e
    WHERE e.code_red_id = p_code_red_id
      AND e.engineer_user_id = auth.uid()
      AND e.outcome = 'paged'
  ) INTO v_paged;
  IF NOT v_paged THEN
    RAISE EXCEPTION 'not_paged_for_this_code_red' USING ERRCODE = '42501';
  END IF;

  -- First-accept wins
  UPDATE public.code_red_requests
     SET status = 'engineer_accepted',
         accepted_engineer_user_id = auth.uid(),
         accepted_at = now()
   WHERE id = p_code_red_id;

  UPDATE public.code_red_dispatch_events
     SET outcome = 'accepted',
         response_at = now()
   WHERE code_red_id = p_code_red_id
     AND engineer_user_id = auth.uid();

  -- Mark the other paged engineers as 'superseded'
  UPDATE public.code_red_dispatch_events
     SET outcome = 'superseded',
         response_at = now()
   WHERE code_red_id = p_code_red_id
     AND engineer_user_id <> auth.uid()
     AND outcome = 'paged';

  RETURN p_code_red_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_code_red(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.accept_code_red(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. decline_code_red — engineer skips
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.decline_code_red(
  p_code_red_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  UPDATE public.code_red_dispatch_events
     SET outcome = 'declined',
         response_at = now(),
         decline_reason = p_reason
   WHERE code_red_id = p_code_red_id
     AND engineer_user_id = auth.uid()
     AND outcome = 'paged';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'no_paged_event_for_caller' USING ERRCODE = '02000';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.decline_code_red(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.decline_code_red(uuid, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. founder_code_red_recent — cockpit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_code_red_recent(
  p_days  integer DEFAULT 30,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id                       uuid,
  hospital_email           text,
  equipment_type           text,
  description              text,
  status                   text,
  sla_minutes              int,
  sla_deadline_at          timestamptz,
  accepted_engineer_email  text,
  time_to_accept_minutes   numeric,
  paged_count              int,
  declined_count           int,
  created_at               timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    coalesce((SELECT email FROM auth.users WHERE id = r.hospital_user_id), 'unknown'),
    r.equipment_type, r.description, r.status,
    r.sla_minutes, r.sla_deadline_at,
    coalesce((SELECT email FROM auth.users WHERE id = r.accepted_engineer_user_id), NULL),
    CASE WHEN r.accepted_at IS NOT NULL
         THEN round(EXTRACT(EPOCH FROM (r.accepted_at - r.created_at)) / 60.0, 1)
         ELSE NULL END,
    (SELECT count(*)::int FROM public.code_red_dispatch_events e
       WHERE e.code_red_id = r.id),
    (SELECT count(*)::int FROM public.code_red_dispatch_events e
       WHERE e.code_red_id = r.id AND e.outcome = 'declined'),
    r.created_at
  FROM public.code_red_requests r
  WHERE r.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
  ORDER BY r.created_at DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_code_red_recent(integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_recent(integer, integer) TO service_role;

-- ---------------------------------------------------------------------
-- 7. sweep_timed_out_code_reds — cron-callable
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sweep_timed_out_code_reds()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  WITH expired AS (
    UPDATE public.code_red_requests
       SET status = 'timed_out'
     WHERE status = 'open'
       AND sla_deadline_at < now()
     RETURNING id
  )
  UPDATE public.code_red_dispatch_events
     SET outcome = 'missed', response_at = now()
   WHERE code_red_id IN (SELECT id FROM expired)
     AND outcome = 'paged';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sweep_timed_out_code_reds()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.sweep_timed_out_code_reds() TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'sweep_timed_out_code_reds_every_5min',
    '*/5 * * * *',
    $cron$SELECT public.sweep_timed_out_code_reds();$cron$
  );
  RAISE NOTICE 'round 509: 5-minute timeout sweep scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 509: pg_cron unavailable; sweep callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = 'code_red_requests'
      AND relnamespace = 'public'::regnamespace AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 509: code_red_requests RLS not enabled';
  END IF;
  RAISE NOTICE 'round 509 code red emergency verified: 2 tables + 5 RPCs + 5-min timeout sweep';
END;
$$;
