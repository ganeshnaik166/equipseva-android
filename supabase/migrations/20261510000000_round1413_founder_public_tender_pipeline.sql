BEGIN;
-- Round 1413 — Founder public tender pipeline
-- Government / hospital tender tracking. 2 tables + 8 RPCs.
-- All RPCs founder-only.



-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_public_tenders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_label text NOT NULL UNIQUE,
  tender_kind text NOT NULL CHECK (tender_kind IN ('govt_central','govt_state','govt_district','phc_chc_sc','autonomous_body','psu_company','private_chain')),
  procuring_authority text,
  scope text,
  estimated_value_rupees numeric(14,2),
  bid_submission_deadline date NOT NULL,
  our_bid_status text NOT NULL DEFAULT 'researching' CHECK (our_bid_status IN ('not_pursuing','researching','preparing_bid','submitted','shortlisted','awarded','rejected','withdrawn')),
  awarded_to text,
  awarded_amount_rupees numeric(14,2),
  awarded_at date,
  document_urls text[] NOT NULL DEFAULT ARRAY[]::text[],
  notes text,
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpt_status ON public.founder_public_tenders(our_bid_status);
CREATE INDEX IF NOT EXISTS idx_fpt_kind ON public.founder_public_tenders(tender_kind);
CREATE INDEX IF NOT EXISTS idx_fpt_deadline ON public.founder_public_tenders(bid_submission_deadline);

CREATE TABLE IF NOT EXISTS public.founder_public_tender_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid NOT NULL REFERENCES public.founder_public_tenders(id) ON DELETE CASCADE,
  activity_kind text NOT NULL CHECK (activity_kind IN ('research','site_visit','clarification_request','clarification_received','bid_drafted','bid_submitted','status_inquiry','result_received')),
  description text,
  happened_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpta_tender ON public.founder_public_tender_activities(tender_id);
CREATE INDEX IF NOT EXISTS idx_fpta_happened ON public.founder_public_tender_activities(happened_at DESC);

ALTER TABLE public.founder_public_tenders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_public_tender_activities ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.founder_public_tenders FROM authenticated, anon;
REVOKE ALL ON public.founder_public_tender_activities FROM authenticated, anon;

-- ============================================================
-- RPC 1: summary (16 KPIs)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_public_tender_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_public_tender_pipeline_summary()
RETURNS TABLE (
  total_tenders bigint,
  researching_count bigint,
  preparing_bid_count bigint,
  submitted_count bigint,
  shortlisted_count bigint,
  awarded_count bigint,
  rejected_count bigint,
  withdrawn_count bigint,
  total_estimated_value_rupees numeric,
  total_awarded_amount_rupees numeric,
  win_rate_pct numeric,
  deadlines_within_14d bigint,
  overdue_no_submission bigint,
  avg_days_research_to_submit numeric,
  top_authority text,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH base AS (SELECT * FROM public.founder_public_tenders),
  decided AS (SELECT * FROM base WHERE our_bid_status IN ('awarded','rejected')),
  auth_top AS (
    SELECT procuring_authority, COUNT(*) AS c FROM base
    WHERE procuring_authority IS NOT NULL
    GROUP BY procuring_authority ORDER BY c DESC LIMIT 1
  )
  SELECT
    (SELECT COUNT(*) FROM base),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='researching'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='preparing_bid'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='submitted'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='shortlisted'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='awarded'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='rejected'),
    (SELECT COUNT(*) FROM base WHERE our_bid_status='withdrawn'),
    COALESCE((SELECT SUM(estimated_value_rupees) FROM base),0)::numeric,
    COALESCE((SELECT SUM(awarded_amount_rupees) FROM base WHERE our_bid_status='awarded'),0)::numeric,
    CASE WHEN (SELECT COUNT(*) FROM decided)=0 THEN 0::numeric
         ELSE ROUND(((SELECT COUNT(*) FROM decided WHERE our_bid_status='awarded')::numeric * 100.0)
              / (SELECT COUNT(*) FROM decided)::numeric, 2) END,
    (SELECT COUNT(*) FROM base WHERE bid_submission_deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + 14
      AND our_bid_status IN ('researching','preparing_bid')),
    (SELECT COUNT(*) FROM base WHERE bid_submission_deadline < CURRENT_DATE
      AND our_bid_status IN ('researching','preparing_bid')),
    COALESCE((
      SELECT ROUND(AVG(EXTRACT(EPOCH FROM (b.updated_at - b.created_at))/86400.0)::numeric, 2)
      FROM base b WHERE b.our_bid_status IN ('submitted','shortlisted','awarded','rejected')
    ), 0::numeric),
    (SELECT procuring_authority FROM auth_top),
    now();
END $$;
REVOKE ALL ON FUNCTION public.founder_public_tender_pipeline_summary() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_public_tender_pipeline_summary() TO authenticated;

-- ============================================================
-- RPC 2: recent tenders ledger
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_public_tenders_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_public_tenders_recent(p_limit integer DEFAULT 30)
RETURNS TABLE (
  id uuid, tender_label text, tender_kind text, procuring_authority text,
  estimated_value_rupees numeric, bid_submission_deadline date,
  our_bid_status text, awarded_to text, awarded_amount_rupees numeric, awarded_at date,
  days_to_deadline integer, created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT t.id, t.tender_label, t.tender_kind, t.procuring_authority,
         t.estimated_value_rupees, t.bid_submission_deadline, t.our_bid_status,
         t.awarded_to, t.awarded_amount_rupees, t.awarded_at,
         (t.bid_submission_deadline - CURRENT_DATE)::integer,
         t.created_at, t.updated_at
  FROM public.founder_public_tenders t
  ORDER BY t.bid_submission_deadline ASC, t.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END $$;
REVOKE ALL ON FUNCTION public.founder_public_tenders_recent(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_public_tenders_recent(integer) TO authenticated;

-- ============================================================
-- RPC 3: recent activity feed
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_public_tender_activities_recent(integer);
CREATE OR REPLACE FUNCTION public.founder_public_tender_activities_recent(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid, tender_id uuid, tender_label text, activity_kind text,
  description text, happened_at timestamptz, created_by uuid
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT a.id, a.tender_id, t.tender_label, a.activity_kind, a.description,
         a.happened_at, a.created_by
  FROM public.founder_public_tender_activities a
  JOIN public.founder_public_tenders t ON t.id = a.tender_id
  ORDER BY a.happened_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END $$;
REVOKE ALL ON FUNCTION public.founder_public_tender_activities_recent(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_public_tender_activities_recent(integer) TO authenticated;

-- ============================================================
-- RPC 4: upcoming deadlines (within 14d)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_public_tenders_upcoming_deadlines();
CREATE OR REPLACE FUNCTION public.founder_public_tenders_upcoming_deadlines()
RETURNS TABLE (
  id uuid, tender_label text, procuring_authority text,
  bid_submission_deadline date, days_remaining integer,
  our_bid_status text, estimated_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT t.id, t.tender_label, t.procuring_authority,
         t.bid_submission_deadline,
         (t.bid_submission_deadline - CURRENT_DATE)::integer,
         t.our_bid_status, t.estimated_value_rupees
  FROM public.founder_public_tenders t
  WHERE t.bid_submission_deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + 14
    AND t.our_bid_status IN ('researching','preparing_bid')
  ORDER BY t.bid_submission_deadline ASC;
END $$;
REVOKE ALL ON FUNCTION public.founder_public_tenders_upcoming_deadlines() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_public_tenders_upcoming_deadlines() TO authenticated;

-- ============================================================
-- RPC 5: register tender (writer)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_tender_register(text, text, text, text, numeric, date, text);
CREATE OR REPLACE FUNCTION public.log_founder_tender_register(
  p_tender_label text,
  p_tender_kind text,
  p_procuring_authority text,
  p_scope text,
  p_estimated_value_rupees numeric,
  p_bid_submission_deadline date,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_public_tenders(
    tender_label, tender_kind, procuring_authority, scope,
    estimated_value_rupees, bid_submission_deadline, notes, owner_user_id
  ) VALUES (
    p_tender_label, p_tender_kind, p_procuring_authority, p_scope,
    p_estimated_value_rupees, p_bid_submission_deadline, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_tender_register(text,text,text,text,numeric,date,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_tender_register(text,text,text,text,numeric,date,text) TO authenticated;

-- ============================================================
-- RPC 6: status change (writer)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_tender_status_change(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_tender_status_change(p_tender_id uuid, p_new_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_public_tenders
  SET our_bid_status = p_new_status, updated_at = now()
  WHERE id = p_tender_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_tender_status_change(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_tender_status_change(uuid,text) TO authenticated;

-- ============================================================
-- RPC 7: log activity (writer)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_tender_activity(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_tender_activity(
  p_tender_id uuid, p_activity_kind text, p_description text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_public_tender_activities(tender_id, activity_kind, description, created_by)
  VALUES (p_tender_id, p_activity_kind, p_description, auth.uid())
  RETURNING id INTO v_id;
  UPDATE public.founder_public_tenders SET updated_at = now() WHERE id = p_tender_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_tender_activity(uuid,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_tender_activity(uuid,text,text) TO authenticated;

-- ============================================================
-- RPC 8: record award (writer)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_tender_record_award(uuid, text, numeric, date);
CREATE OR REPLACE FUNCTION public.log_founder_tender_record_award(
  p_tender_id uuid, p_awarded_to text, p_awarded_amount_rupees numeric, p_awarded_at date
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_public_tenders
  SET awarded_to = p_awarded_to,
      awarded_amount_rupees = p_awarded_amount_rupees,
      awarded_at = COALESCE(p_awarded_at, CURRENT_DATE),
      our_bid_status = 'awarded',
      updated_at = now()
  WHERE id = p_tender_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_tender_record_award(uuid,text,numeric,date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_tender_record_award(uuid,text,numeric,date) TO authenticated;

COMMIT;