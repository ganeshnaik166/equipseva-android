BEGIN;
-- r1432 — Founder engineer recruitment ATS v2.
-- Extends r1346 founder_hiring_candidates with:
--   (a) interview panel scheduling + structured outcomes
--   (b) offer tracker (drafted -> sent -> negotiating -> accepted/rejected/withdrawn/expired)
-- Strictly founder-only. Surfaces 16 KPIs + upcoming panels + recent panels + recent offers.

-- ============================================================================
-- TABLE: founder_ats_interview_panels
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_ats_interview_panels (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id        uuid NOT NULL REFERENCES public.founder_hiring_candidates(id) ON DELETE CASCADE,
  panel_label         text NOT NULL,
  panel_kind          text NOT NULL CHECK (panel_kind IN (
                        'hr_screen','technical','culture_fit','founder_close','reference_check')),
  scheduled_at        timestamptz,
  panelist_user_ids   uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  status              text NOT NULL DEFAULT 'scheduled' CHECK (status IN (
                        'scheduled','completed','cancelled','rescheduled')),
  aggregate_score     numeric,
  completed_at        timestamptz,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_ats_interview_panels IS
  'Founder-only ATS v2: interview panel sessions with aggregate scoring. Extends r1346.';

CREATE INDEX IF NOT EXISTS idx_ats_panels_candidate   ON public.founder_ats_interview_panels (candidate_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_ats_panels_status      ON public.founder_ats_interview_panels (status, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_ats_panels_scheduled   ON public.founder_ats_interview_panels (scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_ats_panels_kind        ON public.founder_ats_interview_panels (panel_kind, scheduled_at DESC);

ALTER TABLE public.founder_ats_interview_panels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ats_panels_no_direct ON public.founder_ats_interview_panels;
CREATE POLICY ats_panels_no_direct ON public.founder_ats_interview_panels FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_ats_interview_panels FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- TABLE: founder_ats_offers
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_ats_offers (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id           uuid NOT NULL UNIQUE REFERENCES public.founder_hiring_candidates(id) ON DELETE CASCADE,
  offered_role           text,
  offered_ctc_rupees     numeric,
  offered_band           text,
  offered_start_date     date,
  status                 text NOT NULL DEFAULT 'drafted' CHECK (status IN (
                           'drafted','sent','negotiating','accepted','rejected','withdrawn','expired')),
  sent_at                timestamptz,
  response_at            timestamptz,
  signed_at              timestamptz,
  signing_bonus_rupees   numeric NOT NULL DEFAULT 0,
  notes                  text,
  created_at             timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_ats_offers IS
  'Founder-only ATS v2: one offer per candidate. Tracks CTC, band, start date, signing bonus, status.';

CREATE INDEX IF NOT EXISTS idx_ats_offers_status    ON public.founder_ats_offers (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ats_offers_sent      ON public.founder_ats_offers (sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_ats_offers_signed    ON public.founder_ats_offers (signed_at DESC);

ALTER TABLE public.founder_ats_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ats_offers_no_direct ON public.founder_ats_offers;
CREATE POLICY ats_offers_no_direct ON public.founder_ats_offers FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_ats_offers FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC 1/7: founder_ats_v2_summary — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ats_v2_summary();
CREATE OR REPLACE FUNCTION public.founder_ats_v2_summary()
RETURNS TABLE (
  total_candidates             bigint,
  candidates_with_panels       bigint,
  panels_scheduled             bigint,
  panels_completed             bigint,
  panels_cancelled             bigint,
  panels_rescheduled           bigint,
  panels_upcoming_7d           bigint,
  avg_aggregate_score          numeric,
  offers_total                 bigint,
  offers_drafted               bigint,
  offers_sent                  bigint,
  offers_negotiating           bigint,
  offers_accepted              bigint,
  offers_rejected_or_withdrawn bigint,
  offer_acceptance_pct         numeric,
  avg_offered_ctc_rupees       numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_offers_total       bigint;
  v_offers_accepted    bigint;
  v_offers_resolved    bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT count(*) INTO v_offers_total FROM public.founder_ats_offers;
  SELECT count(*) INTO v_offers_accepted FROM public.founder_ats_offers WHERE status='accepted';
  SELECT count(*) INTO v_offers_resolved FROM public.founder_ats_offers
    WHERE status IN ('accepted','rejected','withdrawn','expired');

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_hiring_candidates),
    (SELECT count(DISTINCT candidate_id) FROM public.founder_ats_interview_panels),
    (SELECT count(*) FROM public.founder_ats_interview_panels WHERE status='scheduled'),
    (SELECT count(*) FROM public.founder_ats_interview_panels WHERE status='completed'),
    (SELECT count(*) FROM public.founder_ats_interview_panels WHERE status='cancelled'),
    (SELECT count(*) FROM public.founder_ats_interview_panels WHERE status='rescheduled'),
    (SELECT count(*) FROM public.founder_ats_interview_panels
       WHERE status='scheduled' AND scheduled_at IS NOT NULL
         AND scheduled_at BETWEEN now() AND now() + interval '7 days'),
    COALESCE((SELECT ROUND(avg(aggregate_score)::numeric, 2)
              FROM public.founder_ats_interview_panels
              WHERE status='completed' AND aggregate_score IS NOT NULL), 0),
    v_offers_total,
    (SELECT count(*) FROM public.founder_ats_offers WHERE status='drafted'),
    (SELECT count(*) FROM public.founder_ats_offers WHERE status='sent'),
    (SELECT count(*) FROM public.founder_ats_offers WHERE status='negotiating'),
    v_offers_accepted,
    (SELECT count(*) FROM public.founder_ats_offers WHERE status IN ('rejected','withdrawn','expired')),
    CASE WHEN v_offers_resolved=0 THEN 0
         ELSE ROUND(100.0 * v_offers_accepted / v_offers_resolved, 2) END,
    COALESCE((SELECT ROUND(avg(offered_ctc_rupees)::numeric, 0)
              FROM public.founder_ats_offers
              WHERE offered_ctc_rupees IS NOT NULL), 0);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_ats_v2_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ats_v2_summary() TO authenticated;

-- ============================================================================
-- RPC 2/7: founder_ats_v2_panels_recent — recent panel sessions ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ats_v2_panels_recent(int);
CREATE OR REPLACE FUNCTION public.founder_ats_v2_panels_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id              uuid,
  candidate_id    uuid,
  candidate_name  text,
  candidate_role  text,
  panel_label     text,
  panel_kind      text,
  scheduled_at    timestamptz,
  status          text,
  aggregate_score numeric,
  completed_at    timestamptz,
  panelist_count  int,
  notes           text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.candidate_id,
    c.candidate_name,
    c.role,
    p.panel_label,
    p.panel_kind,
    p.scheduled_at,
    p.status,
    p.aggregate_score,
    p.completed_at,
    COALESCE(array_length(p.panelist_user_ids, 1), 0),
    p.notes
  FROM public.founder_ats_interview_panels p
  JOIN public.founder_hiring_candidates c ON c.id = p.candidate_id
  ORDER BY COALESCE(p.scheduled_at, p.created_at) DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_ats_v2_panels_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ats_v2_panels_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3/7: founder_ats_v2_offers_recent — offer ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ats_v2_offers_recent(int);
CREATE OR REPLACE FUNCTION public.founder_ats_v2_offers_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id                   uuid,
  candidate_id         uuid,
  candidate_name       text,
  offered_role         text,
  offered_ctc_rupees   numeric,
  offered_band         text,
  offered_start_date   date,
  status               text,
  sent_at              timestamptz,
  response_at          timestamptz,
  signed_at            timestamptz,
  signing_bonus_rupees numeric,
  days_since_sent      numeric,
  notes                text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.candidate_id,
    c.candidate_name,
    o.offered_role,
    o.offered_ctc_rupees,
    o.offered_band,
    o.offered_start_date,
    o.status,
    o.sent_at,
    o.response_at,
    o.signed_at,
    o.signing_bonus_rupees,
    CASE WHEN o.sent_at IS NULL THEN NULL
         ELSE ROUND(EXTRACT(EPOCH FROM (COALESCE(o.response_at, now()) - o.sent_at))/86400.0, 1)
    END,
    o.notes
  FROM public.founder_ats_offers o
  JOIN public.founder_hiring_candidates c ON c.id = o.candidate_id
  ORDER BY
    CASE o.status
      WHEN 'negotiating' THEN 1
      WHEN 'sent'        THEN 2
      WHEN 'drafted'     THEN 3
      WHEN 'accepted'    THEN 4
      WHEN 'rejected'    THEN 5
      WHEN 'withdrawn'   THEN 6
      WHEN 'expired'     THEN 7
      ELSE 8
    END,
    o.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_ats_v2_offers_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ats_v2_offers_recent(int) TO authenticated;

-- ============================================================================
-- RPC 4/7: founder_ats_v2_panels_upcoming — next 14d panels
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ats_v2_panels_upcoming(int);
CREATE OR REPLACE FUNCTION public.founder_ats_v2_panels_upcoming(p_days_ahead int DEFAULT 14)
RETURNS TABLE (
  id             uuid,
  candidate_id   uuid,
  candidate_name text,
  candidate_role text,
  panel_label    text,
  panel_kind     text,
  scheduled_at   timestamptz,
  hours_until    numeric,
  panelist_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.candidate_id,
    c.candidate_name,
    c.role,
    p.panel_label,
    p.panel_kind,
    p.scheduled_at,
    ROUND(EXTRACT(EPOCH FROM (p.scheduled_at - now()))/3600.0, 1),
    COALESCE(array_length(p.panelist_user_ids, 1), 0)
  FROM public.founder_ats_interview_panels p
  JOIN public.founder_hiring_candidates c ON c.id = p.candidate_id
  WHERE p.status = 'scheduled'
    AND p.scheduled_at IS NOT NULL
    AND p.scheduled_at BETWEEN now() AND now() + (GREATEST(p_days_ahead, 1) * interval '1 day')
  ORDER BY p.scheduled_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_ats_v2_panels_upcoming(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ats_v2_panels_upcoming(int) TO authenticated;

-- ============================================================================
-- WRITE RPC 5/7: log_founder_ats_v2_schedule_panel
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ats_v2_schedule_panel(uuid, text, text, timestamptz, uuid[]);
CREATE OR REPLACE FUNCTION public.log_founder_ats_v2_schedule_panel(
  p_candidate_id uuid,
  p_panel_label  text,
  p_panel_kind   text,
  p_scheduled_at timestamptz,
  p_panelists    uuid[] DEFAULT ARRAY[]::uuid[]
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_candidate_id IS NULL THEN
    RAISE EXCEPTION 'candidate_id required' USING ERRCODE='22023';
  END IF;
  IF p_panel_kind NOT IN ('hr_screen','technical','culture_fit','founder_close','reference_check') THEN
    RAISE EXCEPTION 'invalid panel_kind' USING ERRCODE='22023';
  END IF;
  IF p_panel_label IS NULL OR length(trim(p_panel_label))=0 THEN
    RAISE EXCEPTION 'panel_label required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_ats_interview_panels
    (candidate_id, panel_label, panel_kind, scheduled_at, panelist_user_ids, status)
  VALUES
    (p_candidate_id, trim(p_panel_label), p_panel_kind, p_scheduled_at,
     COALESCE(p_panelists, ARRAY[]::uuid[]), 'scheduled')
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ats_v2_schedule_panel(uuid, text, text, timestamptz, uuid[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ats_v2_schedule_panel(uuid, text, text, timestamptz, uuid[]) TO authenticated;

-- ============================================================================
-- WRITE RPC 6/7: log_founder_ats_v2_record_panel_outcome
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ats_v2_record_panel_outcome(uuid, text, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_ats_v2_record_panel_outcome(
  p_panel_id    uuid,
  p_new_status  text,
  p_score       numeric DEFAULT NULL,
  p_notes       text    DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_status NOT IN ('scheduled','completed','cancelled','rescheduled') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE='22023';
  END IF;
  IF p_score IS NOT NULL AND (p_score < 0 OR p_score > 10) THEN
    RAISE EXCEPTION 'score must be 0..10' USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_ats_interview_panels
     SET status          = p_new_status,
         aggregate_score = COALESCE(p_score, aggregate_score),
         notes           = COALESCE(p_notes, notes),
         completed_at    = CASE WHEN p_new_status='completed' THEN now() ELSE completed_at END,
         updated_at      = now()
   WHERE id = p_panel_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'panel not found' USING ERRCODE='P0002';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ats_v2_record_panel_outcome(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ats_v2_record_panel_outcome(uuid, text, numeric, text) TO authenticated;

-- ============================================================================
-- WRITE RPC 7/7: log_founder_ats_v2_send_offer
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_ats_v2_send_offer(uuid, text, numeric, text, date, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_ats_v2_send_offer(
  p_candidate_id        uuid,
  p_offered_role        text,
  p_offered_ctc_rupees  numeric,
  p_offered_band        text,
  p_offered_start_date  date,
  p_signing_bonus       numeric DEFAULT 0,
  p_notes               text    DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_candidate_id IS NULL THEN
    RAISE EXCEPTION 'candidate_id required' USING ERRCODE='22023';
  END IF;
  IF p_offered_ctc_rupees IS NULL OR p_offered_ctc_rupees <= 0 THEN
    RAISE EXCEPTION 'offered_ctc_rupees must be positive' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_ats_offers
    (candidate_id, offered_role, offered_ctc_rupees, offered_band, offered_start_date,
     signing_bonus_rupees, notes, status, sent_at)
  VALUES
    (p_candidate_id, NULLIF(trim(p_offered_role), ''), p_offered_ctc_rupees,
     NULLIF(trim(p_offered_band), ''), p_offered_start_date,
     COALESCE(p_signing_bonus, 0), NULLIF(trim(p_notes), ''), 'sent', now())
  ON CONFLICT (candidate_id) DO UPDATE
    SET offered_role         = EXCLUDED.offered_role,
        offered_ctc_rupees   = EXCLUDED.offered_ctc_rupees,
        offered_band         = EXCLUDED.offered_band,
        offered_start_date   = EXCLUDED.offered_start_date,
        signing_bonus_rupees = EXCLUDED.signing_bonus_rupees,
        notes                = COALESCE(EXCLUDED.notes, public.founder_ats_offers.notes),
        status               = 'sent',
        sent_at              = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_ats_v2_send_offer(uuid, text, numeric, text, date, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_ats_v2_send_offer(uuid, text, numeric, text, date, numeric, text) TO authenticated;

COMMIT;