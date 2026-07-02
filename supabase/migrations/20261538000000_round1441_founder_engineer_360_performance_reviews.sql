BEGIN;
-- r1441 — Founder Engineer 360° Performance Reviews
-- 2 tables + 7 RPCs · is_founder() gate · LANGUAGE plpgsql



-- ============================================================================
-- TABLE 1 · review cycles
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_360_perf_review_cycles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_label text NOT NULL UNIQUE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','in_progress','collecting','complete','published')),
  target_engineer_count int NOT NULL DEFAULT 0,
  responses_collected int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_e360_perf_cycles_status
  ON public.engineer_360_perf_review_cycles(status);
CREATE INDEX IF NOT EXISTS idx_e360_perf_cycles_period
  ON public.engineer_360_perf_review_cycles(period_start DESC);

ALTER TABLE public.engineer_360_perf_review_cycles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TABLE 2 · responses
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_360_perf_review_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.engineer_360_perf_review_cycles(id) ON DELETE CASCADE,
  subject_engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewer_kind text NOT NULL
    CHECK (reviewer_kind IN ('self','peer','supervisor','customer','founder_360')),
  reviewer_user_id uuid,
  technical_skill_score int NOT NULL CHECK (technical_skill_score BETWEEN 1 AND 10),
  customer_service_score int NOT NULL CHECK (customer_service_score BETWEEN 1 AND 10),
  team_collaboration_score int NOT NULL CHECK (team_collaboration_score BETWEEN 1 AND 10),
  reliability_score int NOT NULL CHECK (reliability_score BETWEEN 1 AND 10),
  avg_score numeric(4,2),
  strength_text text,
  growth_area_text text,
  qualitative_feedback text,
  responded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(cycle_id, subject_engineer_user_id, reviewer_kind, reviewer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_e360_perf_resp_cycle
  ON public.engineer_360_perf_review_responses(cycle_id);
CREATE INDEX IF NOT EXISTS idx_e360_perf_resp_subject
  ON public.engineer_360_perf_review_responses(subject_engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_e360_perf_resp_kind
  ON public.engineer_360_perf_review_responses(reviewer_kind);
CREATE INDEX IF NOT EXISTS idx_e360_perf_resp_responded_at
  ON public.engineer_360_perf_review_responses(responded_at DESC);

ALTER TABLE public.engineer_360_perf_review_responses ENABLE ROW LEVEL SECURITY;

-- auto-compute avg_score on insert/update
CREATE OR REPLACE FUNCTION public._e360_perf_set_avg()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.avg_score := round(
    (COALESCE(NEW.technical_skill_score,0)
     + COALESCE(NEW.customer_service_score,0)
     + COALESCE(NEW.team_collaboration_score,0)
     + COALESCE(NEW.reliability_score,0))::numeric / 4.0, 2);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_e360_perf_set_avg ON public.engineer_360_perf_review_responses;
CREATE TRIGGER trg_e360_perf_set_avg
  BEFORE INSERT OR UPDATE ON public.engineer_360_perf_review_responses
  FOR EACH ROW EXECUTE FUNCTION public._e360_perf_set_avg();

-- ============================================================================
-- RPC 1 · summary (16 KPIs)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_360_perf_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_360_perf_summary()
RETURNS TABLE (
  total_cycles int,
  draft_cycles int,
  in_progress_cycles int,
  collecting_cycles int,
  complete_cycles int,
  published_cycles int,
  total_responses int,
  unique_subjects int,
  self_response_count int,
  peer_response_count int,
  supervisor_response_count int,
  customer_response_count int,
  avg_overall_score numeric,
  avg_technical_score numeric,
  avg_customer_service_score numeric,
  responses_last_30d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles),
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles WHERE status='draft'),
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles WHERE status='in_progress'),
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles WHERE status='collecting'),
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles WHERE status='complete'),
    (SELECT count(*)::int FROM engineer_360_perf_review_cycles WHERE status='published'),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses),
    (SELECT count(DISTINCT subject_engineer_user_id)::int FROM engineer_360_perf_review_responses),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses WHERE reviewer_kind='self'),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses WHERE reviewer_kind='peer'),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses WHERE reviewer_kind='supervisor'),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses WHERE reviewer_kind='customer'),
    (SELECT round(avg(avg_score)::numeric, 2) FROM engineer_360_perf_review_responses),
    (SELECT round(avg(technical_skill_score)::numeric, 2) FROM engineer_360_perf_review_responses),
    (SELECT round(avg(customer_service_score)::numeric, 2) FROM engineer_360_perf_review_responses),
    (SELECT count(*)::int FROM engineer_360_perf_review_responses WHERE responded_at >= now() - interval '30 days');
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_engineer_360_perf_summary() TO authenticated;

-- ============================================================================
-- RPC 2 · recent cycles
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_360_perf_cycles_recent();
CREATE OR REPLACE FUNCTION public.founder_engineer_360_perf_cycles_recent()
RETURNS TABLE (
  id uuid,
  cycle_label text,
  period_start date,
  period_end date,
  status text,
  target_engineer_count int,
  responses_collected int,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT c.id, c.cycle_label, c.period_start, c.period_end, c.status,
         c.target_engineer_count, c.responses_collected, c.created_at
  FROM engineer_360_perf_review_cycles c
  ORDER BY c.created_at DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_engineer_360_perf_cycles_recent() TO authenticated;

-- ============================================================================
-- RPC 3 · recent responses
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_360_perf_responses_recent();
CREATE OR REPLACE FUNCTION public.founder_engineer_360_perf_responses_recent()
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  cycle_label text,
  subject_engineer_user_id uuid,
  reviewer_kind text,
  reviewer_user_id uuid,
  technical_skill_score int,
  customer_service_score int,
  team_collaboration_score int,
  reliability_score int,
  avg_score numeric,
  strength_text text,
  growth_area_text text,
  qualitative_feedback text,
  responded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT r.id, r.cycle_id, c.cycle_label, r.subject_engineer_user_id,
         r.reviewer_kind, r.reviewer_user_id,
         r.technical_skill_score, r.customer_service_score,
         r.team_collaboration_score, r.reliability_score,
         r.avg_score, r.strength_text, r.growth_area_text,
         r.qualitative_feedback, r.responded_at
  FROM engineer_360_perf_review_responses r
  JOIN engineer_360_perf_review_cycles c ON c.id = r.cycle_id
  ORDER BY r.responded_at DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_engineer_360_perf_responses_recent() TO authenticated;

-- ============================================================================
-- RPC 4 · top performers
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_360_perf_top_performers();
CREATE OR REPLACE FUNCTION public.founder_engineer_360_perf_top_performers()
RETURNS TABLE (
  subject_engineer_user_id uuid,
  response_count int,
  avg_overall_score numeric,
  avg_technical numeric,
  avg_customer_service numeric,
  avg_collab numeric,
  avg_reliability numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  RETURN QUERY
  SELECT r.subject_engineer_user_id,
         count(*)::int AS response_count,
         round(avg(r.avg_score)::numeric, 2) AS avg_overall_score,
         round(avg(r.technical_skill_score)::numeric, 2) AS avg_technical,
         round(avg(r.customer_service_score)::numeric, 2) AS avg_customer_service,
         round(avg(r.team_collaboration_score)::numeric, 2) AS avg_collab,
         round(avg(r.reliability_score)::numeric, 2) AS avg_reliability
  FROM engineer_360_perf_review_responses r
  GROUP BY r.subject_engineer_user_id
  HAVING count(*) >= 1
  ORDER BY avg(r.avg_score) DESC NULLS LAST
  LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_engineer_360_perf_top_performers() TO authenticated;

-- ============================================================================
-- RPC 5 · log create cycle
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_eperf_create_cycle(text, date, date, int);
CREATE OR REPLACE FUNCTION public.log_founder_eperf_create_cycle(
  p_cycle_label text,
  p_period_start date,
  p_period_end date,
  p_target_engineer_count int
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  INSERT INTO engineer_360_perf_review_cycles
    (cycle_label, period_start, period_end, status, target_engineer_count)
  VALUES (p_cycle_label, p_period_start, p_period_end, 'draft', COALESCE(p_target_engineer_count,0))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_founder_eperf_create_cycle(text, date, date, int) TO authenticated;

-- ============================================================================
-- RPC 6 · log record response
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_eperf_record_response(uuid, uuid, text, uuid, int, int, int, int, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_eperf_record_response(
  p_cycle_id uuid,
  p_subject_engineer_user_id uuid,
  p_reviewer_kind text,
  p_reviewer_user_id uuid,
  p_technical_skill_score int,
  p_customer_service_score int,
  p_team_collaboration_score int,
  p_reliability_score int,
  p_strength_text text,
  p_growth_area_text text,
  p_qualitative_feedback text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  INSERT INTO engineer_360_perf_review_responses
    (cycle_id, subject_engineer_user_id, reviewer_kind, reviewer_user_id,
     technical_skill_score, customer_service_score, team_collaboration_score, reliability_score,
     strength_text, growth_area_text, qualitative_feedback)
  VALUES (p_cycle_id, p_subject_engineer_user_id, p_reviewer_kind, p_reviewer_user_id,
          p_technical_skill_score, p_customer_service_score, p_team_collaboration_score, p_reliability_score,
          p_strength_text, p_growth_area_text, p_qualitative_feedback)
  RETURNING id INTO v_id;

  UPDATE engineer_360_perf_review_cycles
    SET responses_collected = responses_collected + 1,
        updated_at = now(),
        status = CASE WHEN status = 'draft' THEN 'collecting' ELSE status END
   WHERE id = p_cycle_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_founder_eperf_record_response(uuid, uuid, text, uuid, int, int, int, int, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 7 · log close cycle
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_eperf_close_cycle(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_eperf_close_cycle(p_cycle_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;
  UPDATE engineer_360_perf_review_cycles
    SET status = 'complete', updated_at = now()
   WHERE id = p_cycle_id;
  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_founder_eperf_close_cycle(uuid) TO authenticated;

COMMIT;