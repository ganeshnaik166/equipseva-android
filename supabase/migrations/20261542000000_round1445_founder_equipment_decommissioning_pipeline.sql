BEGIN;
-- r1445 ★★★★ — Equipment decommissioning + disposal pipeline.
--
-- Extends r1414 founder_hospital_equipment_lifecycle. Tracks every piece of
-- equipment we're proposing to retire from active service — through approval,
-- physical disconnect, staging, disposal (vendor return / scrap / resale /
-- donation / e-waste) and final salvage-value reconciliation. Gives founder
-- one board to see what's leaving the fleet, what's stuck, how much we're
-- recovering, and our environmental exposure (e-waste compliance).
--
-- 2 tables:
--   founder_equipment_decommissioning_pipeline
--   founder_equipment_decommissioning_events
--
-- 7 RPCs:
--   founder_decommissioning_pipeline_summary      — 16 KPIs
--   founder_decommissioning_pipeline_recent       — pipeline rows
--   founder_decommissioning_events_recent         — combined event feed
--   founder_decommissioning_at_risk               — staged-too-long / no-cert
--   log_founder_decommissioning_register          — propose decomm
--   log_founder_decommissioning_status            — move status forward
--   log_founder_decommissioning_event             — append event

-- ============================================================================
-- 1. TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_equipment_decommissioning_pipeline (
  id                                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id                      uuid NOT NULL REFERENCES public.founder_hospital_equipment_lifecycle(id) ON DELETE CASCADE,
  decommission_reason               text NOT NULL DEFAULT 'end_of_life' CHECK (decommission_reason IN (
    'end_of_life','irreparable_damage','obsolete','customer_replaced',
    'warranty_writeoff','regulatory_non_compliant','other'
  )),
  status                            text NOT NULL DEFAULT 'proposed' CHECK (status IN (
    'proposed','approved','disconnected','staged','disposed','salvaged','rejected'
  )),
  proposed_at                       timestamptz NOT NULL DEFAULT now(),
  approved_at                       timestamptz,
  disposed_at                       timestamptz,
  salvage_value_recovered_rupees    numeric NOT NULL DEFAULT 0 CHECK (salvage_value_recovered_rupees >= 0),
  disposal_method                   text NOT NULL DEFAULT 'unknown' CHECK (disposal_method IN (
    'returned_to_vendor','sold_for_scrap','sold_resale','donated',
    'landfill_certified','e_waste_certified','unknown'
  )),
  disposal_certificate_url          text,
  e_waste_handler_org_id            uuid,
  environmental_impact_band         text NOT NULL DEFAULT 'unknown' CHECK (environmental_impact_band IN (
    'low','medium','high','unknown'
  )),
  notes                             text,
  created_at                        timestamptz NOT NULL DEFAULT now(),
  updated_at                        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_decomm_pipeline_status
  ON public.founder_equipment_decommissioning_pipeline (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_decomm_pipeline_equipment
  ON public.founder_equipment_decommissioning_pipeline (equipment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_decomm_pipeline_reason
  ON public.founder_equipment_decommissioning_pipeline (decommission_reason);
CREATE INDEX IF NOT EXISTS idx_founder_decomm_pipeline_disposed
  ON public.founder_equipment_decommissioning_pipeline (disposed_at DESC)
  WHERE disposed_at IS NOT NULL;

ALTER TABLE public.founder_equipment_decommissioning_pipeline ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_decomm_pipeline
  ON public.founder_equipment_decommissioning_pipeline;
CREATE POLICY founder_only_decomm_pipeline
  ON public.founder_equipment_decommissioning_pipeline
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_equipment_decommissioning_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decomm_id       uuid NOT NULL REFERENCES public.founder_equipment_decommissioning_pipeline(id) ON DELETE CASCADE,
  event_kind      text NOT NULL CHECK (event_kind IN (
    'proposed','approved','disconnect_scheduled','disconnected','staged',
    'disposed','certificate_received','salvage_revenue','rejected'
  )),
  description     text,
  value_rupees    numeric NOT NULL DEFAULT 0 CHECK (value_rupees >= 0),
  happened_at     timestamptz NOT NULL DEFAULT now(),
  performed_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_decomm_events_decomm
  ON public.founder_equipment_decommissioning_events (decomm_id, happened_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_decomm_events_happened
  ON public.founder_equipment_decommissioning_events (happened_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_decomm_events_kind
  ON public.founder_equipment_decommissioning_events (event_kind, happened_at DESC);

ALTER TABLE public.founder_equipment_decommissioning_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_decomm_events
  ON public.founder_equipment_decommissioning_events;
CREATE POLICY founder_only_decomm_events
  ON public.founder_equipment_decommissioning_events
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. SUMMARY — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_decommissioning_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_decommissioning_pipeline_summary()
RETURNS TABLE (
  total_pipeline_count             int,
  active_count                     int,
  proposed_count                   int,
  approved_count                   int,
  disconnected_count               int,
  staged_count                     int,
  disposed_count                   int,
  salvaged_count                   int,
  rejected_count                   int,
  high_environmental_impact_count  int,
  missing_certificate_count        int,
  e_waste_certified_count          int,
  total_salvage_recovered_rupees   numeric,
  avg_days_propose_to_dispose      numeric,
  proposed_last_30d                int,
  disposed_last_30d                int,
  generated_at                     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_active int;
  v_proposed int;
  v_approved int;
  v_disc int;
  v_staged int;
  v_disposed int;
  v_salvaged int;
  v_rejected int;
  v_high_env int;
  v_missing_cert int;
  v_ewaste int;
  v_salvage_sum numeric;
  v_avg_days numeric;
  v_prop_30d int;
  v_disp_30d int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*)::int,
         count(*) FILTER (WHERE status NOT IN ('disposed','salvaged','rejected'))::int,
         count(*) FILTER (WHERE status = 'proposed')::int,
         count(*) FILTER (WHERE status = 'approved')::int,
         count(*) FILTER (WHERE status = 'disconnected')::int,
         count(*) FILTER (WHERE status = 'staged')::int,
         count(*) FILTER (WHERE status = 'disposed')::int,
         count(*) FILTER (WHERE status = 'salvaged')::int,
         count(*) FILTER (WHERE status = 'rejected')::int,
         count(*) FILTER (WHERE environmental_impact_band = 'high')::int,
         count(*) FILTER (
           WHERE status IN ('disposed','salvaged')
             AND (disposal_certificate_url IS NULL OR length(trim(disposal_certificate_url)) = 0)
         )::int,
         count(*) FILTER (WHERE disposal_method = 'e_waste_certified')::int,
         coalesce(sum(salvage_value_recovered_rupees), 0),
         count(*) FILTER (WHERE proposed_at >= now() - interval '30 days')::int,
         count(*) FILTER (WHERE disposed_at IS NOT NULL AND disposed_at >= now() - interval '30 days')::int
    INTO v_total, v_active, v_proposed, v_approved, v_disc, v_staged,
         v_disposed, v_salvaged, v_rejected, v_high_env, v_missing_cert,
         v_ewaste, v_salvage_sum, v_prop_30d, v_disp_30d
    FROM public.founder_equipment_decommissioning_pipeline;

  SELECT round(avg(extract(epoch FROM (disposed_at - proposed_at)) / 86400.0)::numeric, 1)
    INTO v_avg_days
    FROM public.founder_equipment_decommissioning_pipeline
   WHERE disposed_at IS NOT NULL
     AND proposed_at IS NOT NULL;

  RETURN QUERY SELECT
    coalesce(v_total, 0),
    coalesce(v_active, 0),
    coalesce(v_proposed, 0),
    coalesce(v_approved, 0),
    coalesce(v_disc, 0),
    coalesce(v_staged, 0),
    coalesce(v_disposed, 0),
    coalesce(v_salvaged, 0),
    coalesce(v_rejected, 0),
    coalesce(v_high_env, 0),
    coalesce(v_missing_cert, 0),
    coalesce(v_ewaste, 0),
    coalesce(v_salvage_sum, 0),
    coalesce(v_avg_days, 0),
    coalesce(v_prop_30d, 0),
    coalesce(v_disp_30d, 0),
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decommissioning_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decommissioning_pipeline_summary() TO authenticated;

-- ============================================================================
-- 3. RECENT PIPELINE ROWS
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_decommissioning_pipeline_recent();
CREATE OR REPLACE FUNCTION public.founder_decommissioning_pipeline_recent()
RETURNS TABLE (
  id                                uuid,
  equipment_id                      uuid,
  equipment_label                   text,
  decommission_reason               text,
  status                            text,
  disposal_method                   text,
  environmental_impact_band         text,
  salvage_value_recovered_rupees    numeric,
  proposed_at                       timestamptz,
  approved_at                       timestamptz,
  disposed_at                       timestamptz,
  days_since_propose                int,
  has_certificate                   boolean,
  created_at                        timestamptz,
  updated_at                        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         p.equipment_id,
         coalesce(eq.equipment_label, 'equipment'::text) AS equipment_label,
         p.decommission_reason,
         p.status,
         p.disposal_method,
         p.environmental_impact_band,
         p.salvage_value_recovered_rupees,
         p.proposed_at,
         p.approved_at,
         p.disposed_at,
         extract(day FROM (now() - p.proposed_at))::int AS days_since_propose,
         (p.disposal_certificate_url IS NOT NULL
            AND length(trim(p.disposal_certificate_url)) > 0) AS has_certificate,
         p.created_at,
         p.updated_at
    FROM public.founder_equipment_decommissioning_pipeline p
    LEFT JOIN public.founder_hospital_equipment_lifecycle eq ON eq.id = p.equipment_id
   ORDER BY
     CASE p.status
       WHEN 'disposed' THEN 8 WHEN 'salvaged' THEN 9 WHEN 'rejected' THEN 10
       WHEN 'staged' THEN 4 WHEN 'disconnected' THEN 3 WHEN 'approved' THEN 2
       WHEN 'proposed' THEN 1 ELSE 0 END,
     p.updated_at DESC
   LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decommissioning_pipeline_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decommissioning_pipeline_recent() TO authenticated;

-- ============================================================================
-- 4. RECENT EVENTS — combined feed
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_decommissioning_events_recent();
CREATE OR REPLACE FUNCTION public.founder_decommissioning_events_recent()
RETURNS TABLE (
  id              uuid,
  decomm_id       uuid,
  equipment_label text,
  event_kind      text,
  description     text,
  value_rupees    numeric,
  happened_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT e.id,
         e.decomm_id,
         coalesce(eq.equipment_label, 'equipment'::text) AS equipment_label,
         e.event_kind,
         e.description,
         e.value_rupees,
         e.happened_at
    FROM public.founder_equipment_decommissioning_events e
    JOIN public.founder_equipment_decommissioning_pipeline p ON p.id = e.decomm_id
    LEFT JOIN public.founder_hospital_equipment_lifecycle eq ON eq.id = p.equipment_id
   ORDER BY e.happened_at DESC
   LIMIT 60;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decommissioning_events_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decommissioning_events_recent() TO authenticated;

-- ============================================================================
-- 5. AT RISK — staged-too-long OR disposed without certificate
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_decommissioning_at_risk();
CREATE OR REPLACE FUNCTION public.founder_decommissioning_at_risk()
RETURNS TABLE (
  id                          uuid,
  equipment_label             text,
  status                      text,
  decommission_reason         text,
  disposal_method             text,
  environmental_impact_band   text,
  days_in_status              int,
  risk_reason                 text,
  proposed_at                 timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         coalesce(eq.equipment_label, 'equipment'::text) AS equipment_label,
         p.status,
         p.decommission_reason,
         p.disposal_method,
         p.environmental_impact_band,
         extract(day FROM (now() - p.updated_at))::int AS days_in_status,
         CASE
           WHEN p.status = 'staged'
                AND p.updated_at < now() - interval '30 days'
             THEN 'staged > 30 days'
           WHEN p.status IN ('disposed','salvaged')
                AND (p.disposal_certificate_url IS NULL
                     OR length(trim(p.disposal_certificate_url)) = 0)
             THEN 'disposed without certificate'
           WHEN p.environmental_impact_band = 'high'
                AND p.status NOT IN ('disposed','salvaged','rejected')
             THEN 'high environmental impact pending'
           WHEN p.status = 'proposed'
                AND p.proposed_at < now() - interval '14 days'
             THEN 'proposed > 14 days, no decision'
           ELSE 'other'
         END AS risk_reason,
         p.proposed_at
    FROM public.founder_equipment_decommissioning_pipeline p
    LEFT JOIN public.founder_hospital_equipment_lifecycle eq ON eq.id = p.equipment_id
   WHERE (p.status = 'staged' AND p.updated_at < now() - interval '30 days')
      OR (p.status IN ('disposed','salvaged')
          AND (p.disposal_certificate_url IS NULL
               OR length(trim(p.disposal_certificate_url)) = 0))
      OR (p.environmental_impact_band = 'high'
          AND p.status NOT IN ('disposed','salvaged','rejected'))
      OR (p.status = 'proposed' AND p.proposed_at < now() - interval '14 days')
   ORDER BY p.updated_at ASC
   LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decommissioning_at_risk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decommissioning_at_risk() TO authenticated;

-- ============================================================================
-- 6. WRITE — register / propose decommissioning
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_decommissioning_register(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_decommissioning_register(
  p_equipment_id              uuid,
  p_decommission_reason       text,
  p_environmental_impact_band text,
  p_disposal_method           text,
  p_notes                     text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_equipment_id IS NULL THEN
    RAISE EXCEPTION 'equipment_id required' USING ERRCODE='22023';
  END IF;
  IF coalesce(p_decommission_reason, 'end_of_life') NOT IN (
    'end_of_life','irreparable_damage','obsolete','customer_replaced',
    'warranty_writeoff','regulatory_non_compliant','other') THEN
    RAISE EXCEPTION 'invalid decommission_reason %', p_decommission_reason USING ERRCODE='22023';
  END IF;
  IF coalesce(p_environmental_impact_band, 'unknown') NOT IN ('low','medium','high','unknown') THEN
    RAISE EXCEPTION 'invalid environmental_impact_band %', p_environmental_impact_band USING ERRCODE='22023';
  END IF;
  IF coalesce(p_disposal_method, 'unknown') NOT IN (
    'returned_to_vendor','sold_for_scrap','sold_resale','donated',
    'landfill_certified','e_waste_certified','unknown') THEN
    RAISE EXCEPTION 'invalid disposal_method %', p_disposal_method USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.founder_hospital_equipment_lifecycle WHERE id = p_equipment_id) THEN
    RAISE EXCEPTION 'equipment not found' USING ERRCODE='02000';
  END IF;

  INSERT INTO public.founder_equipment_decommissioning_pipeline (
    equipment_id, decommission_reason, environmental_impact_band,
    disposal_method, notes
  ) VALUES (
    p_equipment_id,
    coalesce(p_decommission_reason, 'end_of_life'),
    coalesce(p_environmental_impact_band, 'unknown'),
    coalesce(p_disposal_method, 'unknown'),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_equipment_decommissioning_events (
    decomm_id, event_kind, description, performed_by
  ) VALUES (
    v_id, 'proposed',
    'decommission proposed: ' || coalesce(p_decommission_reason, 'end_of_life'),
    auth.uid()
  );

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decommissioning_register(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decommissioning_register(uuid, text, text, text, text) TO authenticated;

-- ============================================================================
-- 7. WRITE — status change
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_decommissioning_status(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_decommissioning_status(
  p_decomm_id  uuid,
  p_new_status text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_decomm_id IS NULL THEN
    RAISE EXCEPTION 'decomm_id required' USING ERRCODE='22023';
  END IF;
  IF p_new_status NOT IN ('proposed','approved','disconnected','staged','disposed','salvaged','rejected') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_equipment_decommissioning_pipeline
     SET status        = p_new_status,
         approved_at   = CASE
           WHEN p_new_status = 'approved' AND approved_at IS NULL THEN now()
           ELSE approved_at END,
         disposed_at   = CASE
           WHEN p_new_status IN ('disposed','salvaged') AND disposed_at IS NULL THEN now()
           ELSE disposed_at END,
         updated_at    = now()
   WHERE id = p_decomm_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'decommissioning row not found' USING ERRCODE='02000';
  END IF;

  INSERT INTO public.founder_equipment_decommissioning_events (
    decomm_id, event_kind, description, performed_by
  ) VALUES (
    v_id,
    CASE
      WHEN p_new_status = 'approved' THEN 'approved'
      WHEN p_new_status = 'disconnected' THEN 'disconnected'
      WHEN p_new_status = 'staged' THEN 'staged'
      WHEN p_new_status = 'disposed' THEN 'disposed'
      WHEN p_new_status = 'salvaged' THEN 'salvage_revenue'
      WHEN p_new_status = 'rejected' THEN 'rejected'
      ELSE 'proposed' END,
    'status -> ' || p_new_status,
    auth.uid()
  );

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decommissioning_status(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decommissioning_status(uuid, text) TO authenticated;

-- ============================================================================
-- 8. WRITE — append event
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_decommissioning_event(uuid, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_decommissioning_event(
  p_decomm_id    uuid,
  p_event_kind   text,
  p_description  text,
  p_value_rupees numeric
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_decomm_id IS NULL THEN
    RAISE EXCEPTION 'decomm_id required' USING ERRCODE='22023';
  END IF;
  IF p_event_kind NOT IN (
    'proposed','approved','disconnect_scheduled','disconnected','staged',
    'disposed','certificate_received','salvage_revenue','rejected') THEN
    RAISE EXCEPTION 'invalid event_kind %', p_event_kind USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.founder_equipment_decommissioning_pipeline WHERE id = p_decomm_id) THEN
    RAISE EXCEPTION 'decommissioning row not found' USING ERRCODE='02000';
  END IF;

  INSERT INTO public.founder_equipment_decommissioning_events (
    decomm_id, event_kind, description, value_rupees, performed_by
  ) VALUES (
    p_decomm_id,
    p_event_kind,
    nullif(trim(coalesce(p_description, '')), ''),
    greatest(coalesce(p_value_rupees, 0), 0),
    auth.uid()
  )
  RETURNING id INTO v_id;

  -- bookkeeping: salvage_revenue rolls into recovered total
  IF p_event_kind = 'salvage_revenue' AND coalesce(p_value_rupees, 0) > 0 THEN
    UPDATE public.founder_equipment_decommissioning_pipeline
       SET salvage_value_recovered_rupees = salvage_value_recovered_rupees + p_value_rupees,
           updated_at = now()
     WHERE id = p_decomm_id;
  ELSE
    UPDATE public.founder_equipment_decommissioning_pipeline
       SET updated_at = now()
     WHERE id = p_decomm_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decommissioning_event(uuid, text, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decommissioning_event(uuid, text, text, numeric) TO authenticated;

COMMIT;