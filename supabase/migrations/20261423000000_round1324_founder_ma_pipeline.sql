BEGIN;
-- r1324 — Founder M&A pipeline tracker.
-- Internal corp-dev surface. Tracks acquisition targets, deal stage,
-- integration status, and per-target activity log. Strictly founder-only.
-- Not customer-facing. Not exposed in any public route.

-- ============================================================================
-- TABLE: founder_ma_targets
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_ma_targets (
  id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_company_name             text NOT NULL UNIQUE,
  industry_segment                text CHECK (industry_segment IN (
                                    'biomedical_repair','hospital_chain','spare_parts_distributor',
                                    'dental_clinic_chain','radiology_services','other')),
  target_revenue_rupees_annual    numeric,
  target_engineer_count           int,
  target_hospital_count           int,
  estimated_acquisition_rupees    numeric,
  deal_status                     text NOT NULL DEFAULT 'identified' CHECK (deal_status IN (
                                    'identified','contacted','nda_signed','dd_in_progress',
                                    'loi_sent','term_sheet','closed','passed')),
  deal_priority                   text NOT NULL DEFAULT 'medium' CHECK (deal_priority IN (
                                    'p0_critical','p1_high','medium','p3_low')),
  primary_rationale               text,
  primary_contact_name            text,
  primary_contact_email           text,
  primary_contact_phone           text,
  identified_at                   timestamptz NOT NULL DEFAULT now(),
  closed_at                       timestamptz,
  integration_status              text NOT NULL DEFAULT 'not_started' CHECK (integration_status IN (
                                    'not_started','planning','migrating','live','rolled_back')),
  notes                           text,
  created_at                      timestamptz NOT NULL DEFAULT now(),
  updated_at                      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_ma_targets IS
  'Founder-only corp-dev tracker. Acquisition pipeline. Not customer-facing.';

CREATE INDEX IF NOT EXISTS idx_founder_ma_targets_status   ON public.founder_ma_targets (deal_status, identified_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_ma_targets_priority ON public.founder_ma_targets (deal_priority, identified_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_ma_targets_integ    ON public.founder_ma_targets (integration_status);

ALTER TABLE public.founder_ma_targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_ma_targets_no_direct ON public.founder_ma_targets;
CREATE POLICY founder_ma_targets_no_direct ON public.founder_ma_targets FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_ma_targets FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- TABLE: founder_ma_activity_log
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_ma_activity_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id       uuid NOT NULL REFERENCES public.founder_ma_targets(id) ON DELETE CASCADE,
  activity_kind   text NOT NULL CHECK (activity_kind IN (
                    'contact_made','meeting','document_received','document_sent',
                    'term_negotiation','status_change','note_added')),
  description     text NOT NULL,
  performed_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  happened_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_ma_activity_log IS
  'Per-target activity log for M&A pipeline. Every contact, meeting, document, status change.';

CREATE INDEX IF NOT EXISTS idx_founder_ma_activity_target ON public.founder_ma_activity_log (target_id, happened_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_ma_activity_kind   ON public.founder_ma_activity_log (activity_kind, happened_at DESC);

ALTER TABLE public.founder_ma_activity_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_ma_activity_no_direct ON public.founder_ma_activity_log;
CREATE POLICY founder_ma_activity_no_direct ON public.founder_ma_activity_log FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_ma_activity_log FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC: founder_ma_pipeline_summary — 15 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ma_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_summary()
RETURNS TABLE (
  total_targets                       bigint,
  identified_count                    bigint,
  contacted_count                     bigint,
  nda_signed_count                    bigint,
  dd_count                            bigint,
  loi_count                           bigint,
  term_sheet_count                    bigint,
  closed_count                        bigint,
  passed_count                        bigint,
  total_estimated_acquisition_rupees  numeric,
  total_closed_rupees                 numeric,
  total_pipeline_value                numeric,
  top_priority_open_count             bigint,
  days_since_last_activity_median     numeric,
  active_integrations_count           bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_ma_targets
  ),
  last_activity AS (
    SELECT target_id, MAX(happened_at) AS last_at
    FROM public.founder_ma_activity_log
    GROUP BY target_id
  )
  SELECT
    (SELECT COUNT(*) FROM base),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'identified'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'contacted'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'nda_signed'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'dd_in_progress'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'loi_sent'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'term_sheet'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'closed'),
    (SELECT COUNT(*) FROM base WHERE deal_status = 'passed'),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base), 0),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base WHERE deal_status = 'closed'), 0),
    COALESCE((SELECT SUM(estimated_acquisition_rupees) FROM base
              WHERE deal_status NOT IN ('closed','passed')), 0),
    (SELECT COUNT(*) FROM base
       WHERE deal_priority IN ('p0_critical','p1_high')
         AND deal_status NOT IN ('closed','passed')),
    COALESCE((
      SELECT percentile_cont(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (now() - la.last_at)) / 86400.0
      )
      FROM last_activity la
      JOIN base b ON b.id = la.target_id
      WHERE b.deal_status NOT IN ('closed','passed')
    ), 0),
    (SELECT COUNT(*) FROM base WHERE integration_status IN ('planning','migrating'));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ma_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ma_pipeline_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_ma_targets_recent — pipeline view
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ma_targets_recent(int);
CREATE OR REPLACE FUNCTION public.founder_ma_targets_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id                              uuid,
  target_company_name             text,
  industry_segment                text,
  deal_status                     text,
  deal_priority                   text,
  target_revenue_rupees_annual    numeric,
  estimated_acquisition_rupees    numeric,
  target_hospital_count           int,
  target_engineer_count           int,
  integration_status              text,
  primary_contact_name            text,
  identified_at                   timestamptz,
  closed_at                       timestamptz,
  last_activity_at                timestamptz,
  activity_count                  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH act AS (
    SELECT target_id, MAX(happened_at) AS last_at, COUNT(*)::bigint AS cnt
    FROM public.founder_ma_activity_log
    GROUP BY target_id
  )
  SELECT
    t.id,
    t.target_company_name,
    COALESCE(t.industry_segment::text, 'other'),
    t.deal_status::text,
    t.deal_priority::text,
    t.target_revenue_rupees_annual,
    t.estimated_acquisition_rupees,
    t.target_hospital_count,
    t.target_engineer_count,
    t.integration_status::text,
    t.primary_contact_name,
    t.identified_at,
    t.closed_at,
    a.last_at,
    COALESCE(a.cnt, 0)
  FROM public.founder_ma_targets t
  LEFT JOIN act a ON a.target_id = t.id
  ORDER BY
    CASE t.deal_priority
      WHEN 'p0_critical' THEN 0
      WHEN 'p1_high'     THEN 1
      WHEN 'medium'      THEN 2
      WHEN 'p3_low'      THEN 3
      ELSE 4
    END,
    COALESCE(a.last_at, t.identified_at) DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ma_targets_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ma_targets_recent(int) TO authenticated;

-- ============================================================================
-- RPC: founder_ma_activity_log_recent — per-target activity stream
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ma_activity_log_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_ma_activity_log_recent(p_target_id uuid, p_limit int DEFAULT 20)
RETURNS TABLE (
  id              uuid,
  target_id       uuid,
  activity_kind   text,
  description     text,
  performed_by    uuid,
  happened_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.target_id, a.activity_kind::text, a.description, a.performed_by, a.happened_at
  FROM public.founder_ma_activity_log a
  WHERE (p_target_id IS NULL OR a.target_id = p_target_id)
  ORDER BY a.happened_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ma_activity_log_recent(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ma_activity_log_recent(uuid, int) TO authenticated;

-- ============================================================================
-- WRITER: log_founder_ma_register_target
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ma_register_target(text, text, numeric, int, int, numeric, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_ma_register_target(
  p_company_name    text,
  p_segment         text,
  p_revenue_annual  numeric,
  p_engineer_count  int,
  p_hospital_count  int,
  p_est_acquisition numeric,
  p_priority        text,
  p_rationale       text,
  p_contact_name    text,
  p_contact_email   text,
  p_contact_phone   text,
  p_notes           text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_ma_targets (
    target_company_name, industry_segment, target_revenue_rupees_annual,
    target_engineer_count, target_hospital_count, estimated_acquisition_rupees,
    deal_priority, primary_rationale, primary_contact_name,
    primary_contact_email, primary_contact_phone, notes
  ) VALUES (
    p_company_name, p_segment, p_revenue_annual,
    p_engineer_count, p_hospital_count, p_est_acquisition,
    COALESCE(p_priority, 'medium'), p_rationale, p_contact_name,
    p_contact_email, p_contact_phone, p_notes
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_ma_activity_log (target_id, activity_kind, description, performed_by)
  VALUES (v_id, 'note_added', 'Target registered in pipeline', auth.uid());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ma_register_target(text, text, numeric, int, int, numeric, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ma_register_target(text, text, numeric, int, int, numeric, text, text, text, text, text, text) TO authenticated;

-- ============================================================================
-- WRITER: log_founder_ma_status_change
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ma_status_change(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_ma_status_change(
  p_target_id  uuid,
  p_new_status text,
  p_note       text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  UPDATE public.founder_ma_targets
  SET deal_status = p_new_status,
      closed_at = CASE WHEN p_new_status IN ('closed','passed') THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_ma_activity_log (target_id, activity_kind, description, performed_by)
  VALUES (p_target_id, 'status_change',
          'Status -> ' || p_new_status || COALESCE(' · ' || p_note, ''),
          auth.uid());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ma_status_change(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ma_status_change(uuid, text, text) TO authenticated;

-- ============================================================================
-- WRITER: log_founder_ma_activity
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ma_activity(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_ma_activity(
  p_target_id uuid,
  p_kind      text,
  p_desc      text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_ma_activity_log (target_id, activity_kind, description, performed_by)
  VALUES (p_target_id, p_kind, p_desc, auth.uid())
  RETURNING id INTO v_id;

  UPDATE public.founder_ma_targets SET updated_at = now() WHERE id = p_target_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ma_activity(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ma_activity(uuid, text, text) TO authenticated;

COMMIT;