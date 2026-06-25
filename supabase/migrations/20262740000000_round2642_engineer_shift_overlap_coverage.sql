-- Round 2642: Engineer shift overlap coverage
-- Tracks overlap windows between outgoing and incoming engineers + gap remediation actions

BEGIN;

-- =====================================================================
-- Table 1: engineer_shift_overlap_r2642
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.engineer_shift_overlap_r2642 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outgoing_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  incoming_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  overlap_at timestamptz NOT NULL DEFAULT now(),
  overlap_minutes int NOT NULL DEFAULT 0 CHECK (overlap_minutes >= 0),
  coverage_zone text NOT NULL DEFAULT 'general',
  knowledge_transfer_ok boolean NOT NULL DEFAULT false,
  gap_minutes int NOT NULL DEFAULT 0 CHECK (gap_minutes >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','done','skipped','disputed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eso_r2642_overlap_at ON public.engineer_shift_overlap_r2642 (overlap_at DESC);
CREATE INDEX IF NOT EXISTS idx_eso_r2642_status ON public.engineer_shift_overlap_r2642 (status);
CREATE INDEX IF NOT EXISTS idx_eso_r2642_zone ON public.engineer_shift_overlap_r2642 (coverage_zone);

ALTER TABLE public.engineer_shift_overlap_r2642 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_shift_overlap_r2642;
CREATE POLICY founder_all ON public.engineer_shift_overlap_r2642
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- Table 2: overlap_gap_actions_r2642
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.overlap_gap_actions_r2642 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  overlap_id uuid REFERENCES public.engineer_shift_overlap_r2642(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('reschedule','extend_overlap','buddy_pair','manager_review')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oga_r2642_overlap ON public.overlap_gap_actions_r2642 (overlap_id);
CREATE INDEX IF NOT EXISTS idx_oga_r2642_action_at ON public.overlap_gap_actions_r2642 (action_at DESC);
CREATE INDEX IF NOT EXISTS idx_oga_r2642_status ON public.overlap_gap_actions_r2642 (status);

ALTER TABLE public.overlap_gap_actions_r2642 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.overlap_gap_actions_r2642;
CREATE POLICY founder_all ON public.overlap_gap_actions_r2642
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- Seed data
-- =====================================================================
INSERT INTO public.engineer_shift_overlap_r2642 (overlap_at, overlap_minutes, coverage_zone, knowledge_transfer_ok, gap_minutes, owner_email, status, notes)
VALUES
  ((now() - interval '1 day')::timestamptz, 30, 'north_zone', true, 0, 'ops1@equipseva.in', 'done', 'Smooth handover with checklist'),
  ((now() - interval '2 days')::timestamptz, 15, 'south_zone', false, 25, 'ops2@equipseva.in', 'disputed', 'Incoming engineer late by 25m'),
  ((now() - interval '3 days')::timestamptz, 45, 'central', true, 0, 'ops1@equipseva.in', 'done', 'Extra 15m for AMC walkthrough'),
  ((now() - interval '4 days')::timestamptz, 0, 'east_zone', false, 60, 'ops3@equipseva.in', 'skipped', 'Outgoing engineer no-show'),
  ((now() + interval '6 hours')::timestamptz, 20, 'north_zone', false, 0, 'ops2@equipseva.in', 'scheduled', 'Standard overlap window');

INSERT INTO public.overlap_gap_actions_r2642 (overlap_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '1 day')::timestamptz, 'manager_review', 'negative', 'ops2@equipseva.in', 'done', 'Counselled incoming engineer on tardiness'
FROM public.engineer_shift_overlap_r2642 WHERE notes = 'Incoming engineer late by 25m' LIMIT 1;

INSERT INTO public.overlap_gap_actions_r2642 (overlap_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '3 days')::timestamptz, 'buddy_pair', 'positive', 'ops3@equipseva.in', 'done', 'Buddy pairing for next 2 shifts'
FROM public.engineer_shift_overlap_r2642 WHERE notes = 'Outgoing engineer no-show' LIMIT 1;

INSERT INTO public.overlap_gap_actions_r2642 (overlap_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '2 days')::timestamptz, 'extend_overlap', 'pending', 'ops1@equipseva.in', 'open', 'Extended overlap to 45m going forward'
FROM public.engineer_shift_overlap_r2642 WHERE notes = 'Smooth handover with checklist' LIMIT 1;

INSERT INTO public.overlap_gap_actions_r2642 (overlap_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, (now() - interval '4 hours')::timestamptz, 'reschedule', 'neutral', 'ops2@equipseva.in', 'open', 'Rescheduled to morning slot'
FROM public.engineer_shift_overlap_r2642 WHERE notes = 'Standard overlap window' LIMIT 1;

-- =====================================================================
-- RPC 1: list_overlap_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_overlap_r2642()
RETURNS TABLE (
  id uuid,
  overlap_at timestamptz,
  overlap_minutes int,
  coverage_zone text,
  knowledge_transfer_ok boolean,
  gap_minutes int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.overlap_at, e.overlap_minutes, e.coverage_zone, e.knowledge_transfer_ok,
         e.gap_minutes, e.owner_email, e.status, e.notes
  FROM public.engineer_shift_overlap_r2642 e
  ORDER BY e.overlap_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_overlap_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_overlap_r2642() TO authenticated;

-- =====================================================================
-- RPC 2: list_gap_actions_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_gap_actions_r2642()
RETURNS TABLE (
  id uuid,
  overlap_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.overlap_id, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.overlap_gap_actions_r2642 a
  ORDER BY a.action_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_gap_actions_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_gap_actions_r2642() TO authenticated;

-- =====================================================================
-- RPC 3: top_gap_focus_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_gap_focus_r2642()
RETURNS TABLE (
  coverage_zone text,
  total_gap_minutes bigint,
  overlap_count bigint,
  avg_gap_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.coverage_zone,
         SUM(e.gap_minutes)::bigint AS total_gap_minutes,
         COUNT(*)::bigint AS overlap_count,
         ROUND(AVG(e.gap_minutes)::numeric, 2) AS avg_gap_minutes
  FROM public.engineer_shift_overlap_r2642 e
  GROUP BY e.coverage_zone
  ORDER BY total_gap_minutes DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_gap_focus_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_gap_focus_r2642() TO authenticated;

-- =====================================================================
-- RPC 4: status_funnel_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2642()
RETURNS TABLE (
  status text,
  overlap_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.status, COUNT(*)::bigint AS overlap_count
  FROM public.engineer_shift_overlap_r2642 e
  GROUP BY e.status
  ORDER BY overlap_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2642() TO authenticated;

-- =====================================================================
-- RPC 5: monthly_overlap_trend_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_overlap_trend_r2642()
RETURNS TABLE (
  month_start date,
  overlap_count bigint,
  total_overlap_minutes bigint,
  total_gap_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', e.overlap_at)::date AS month_start,
         COUNT(*)::bigint AS overlap_count,
         SUM(e.overlap_minutes)::bigint AS total_overlap_minutes,
         SUM(e.gap_minutes)::bigint AS total_gap_minutes
  FROM public.engineer_shift_overlap_r2642 e
  GROUP BY date_trunc('month', e.overlap_at)
  ORDER BY month_start DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_overlap_trend_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_overlap_trend_r2642() TO authenticated;

-- =====================================================================
-- RPC 6: coverage_zone_summary_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.coverage_zone_summary_r2642()
RETURNS TABLE (
  coverage_zone text,
  overlap_count bigint,
  knowledge_transfer_ok_count bigint,
  avg_overlap_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.coverage_zone,
         COUNT(*)::bigint AS overlap_count,
         COUNT(*) FILTER (WHERE e.knowledge_transfer_ok)::bigint AS knowledge_transfer_ok_count,
         ROUND(AVG(e.overlap_minutes)::numeric, 2) AS avg_overlap_minutes
  FROM public.engineer_shift_overlap_r2642 e
  GROUP BY e.coverage_zone
  ORDER BY overlap_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.coverage_zone_summary_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.coverage_zone_summary_r2642() TO authenticated;

-- =====================================================================
-- RPC 7: owner_load_r2642
-- =====================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2642()
RETURNS TABLE (
  owner_email text,
  overlap_count bigint,
  open_action_count bigint,
  total_gap_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(e.owner_email, 'unassigned') AS owner_email,
         COUNT(DISTINCT e.id)::bigint AS overlap_count,
         COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'open')::bigint AS open_action_count,
         SUM(e.gap_minutes)::bigint AS total_gap_minutes
  FROM public.engineer_shift_overlap_r2642 e
  LEFT JOIN public.overlap_gap_actions_r2642 a ON a.overlap_id = e.id
  GROUP BY COALESCE(e.owner_email, 'unassigned')
  ORDER BY overlap_count DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2642() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2642() TO authenticated;

COMMIT;
