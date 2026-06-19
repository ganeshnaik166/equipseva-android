BEGIN;
-- r1336 — Founder decision log.
--
-- Discipline goal: 3 decisions/day, every day. Write them down WHEN you make them,
-- with the reasoning + alternatives + expected outcome BEFORE the result is known.
-- Then revisit on a stamped date and write the actual outcome. This is the
-- anti-revisionist-history layer — proof we're thinking, not just reacting.
--
-- Frameworks used:
--   * Bezos one-way / two-way door (reversibility classification)
--   * Confidence at decision time (low / medium / high / very_high) → calibrates us
--   * Impact band (low / medium / high / existential) → triages attention
--   * Kind (8 buckets) — product / people / strategy / tactical / financial /
--     partnership / regulatory / other
--
-- Writing rules (norms, not constraints):
--   1. Every decision logged WITHIN 24h of being made — fresh recall only.
--   2. revisit_at MUST be stamped at write-time (otherwise we never review).
--   3. actual_outcome MUST be filled at revisit; calibration tracked over time.

-- ============================================================================
-- Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_decisions (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decided_on               date NOT NULL DEFAULT current_date,
  decision_title           text NOT NULL,
  decision_summary         text NOT NULL,
  decision_kind            text CHECK (decision_kind IN
                             ('product','people','strategy','tactical','financial','partnership','regulatory','other')),
  reasoning                text NOT NULL,
  alternatives_considered  text,
  expected_outcome         text,
  actual_outcome           text,
  reviewed_at              timestamptz,
  revisit_at               date,
  revisited_at             timestamptz,
  confidence_at_decision   text CHECK (confidence_at_decision IN ('low','medium','high','very_high')),
  reversibility            text CHECK (reversibility IN ('one_way_door','reversible_costly','reversible_cheap','easily_reversible')),
  impact_band              text CHECK (impact_band IN ('low','medium','high','existential')),
  created_at               timestamptz NOT NULL DEFAULT now(),
  created_by               uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
COMMENT ON TABLE public.founder_decisions IS
  '3 decisions/day discipline log. Bezos reversibility + confidence + impact framework. Institutional memory of judgement quality.';

CREATE INDEX IF NOT EXISTS idx_founder_decisions_decided_on   ON public.founder_decisions (decided_on DESC);
CREATE INDEX IF NOT EXISTS idx_founder_decisions_kind         ON public.founder_decisions (decision_kind);
CREATE INDEX IF NOT EXISTS idx_founder_decisions_impact       ON public.founder_decisions (impact_band);
CREATE INDEX IF NOT EXISTS idx_founder_decisions_revisit      ON public.founder_decisions (revisit_at) WHERE revisited_at IS NULL;

ALTER TABLE public.founder_decisions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_decisions_no_direct ON public.founder_decisions;
CREATE POLICY founder_decisions_no_direct ON public.founder_decisions FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_decisions FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_decision_record(text, text, text, text, text, text, date, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_decision_record(
  p_title           text,
  p_summary         text,
  p_reasoning       text,
  p_kind            text DEFAULT NULL,
  p_alternatives    text DEFAULT NULL,
  p_expected        text DEFAULT NULL,
  p_revisit_at      date DEFAULT NULL,
  p_confidence      text DEFAULT NULL,
  p_reversibility   text DEFAULT NULL,
  p_impact_band     text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  INSERT INTO public.founder_decisions
    (decision_title, decision_summary, reasoning, decision_kind,
     alternatives_considered, expected_outcome, revisit_at,
     confidence_at_decision, reversibility, impact_band, created_by)
  VALUES
    (p_title, p_summary, p_reasoning, p_kind,
     p_alternatives, p_expected, p_revisit_at,
     p_confidence, p_reversibility, p_impact_band, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decision_record(text, text, text, text, text, text, date, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decision_record(text, text, text, text, text, text, date, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_decision_record_outcome(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_decision_record_outcome(
  p_decision_id uuid,
  p_actual_outcome text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_decisions
    SET actual_outcome = p_actual_outcome,
        reviewed_at = now()
    WHERE id = p_decision_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decision_record_outcome(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decision_record_outcome(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_decision_revisit(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_decision_revisit(p_decision_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_decisions
    SET revisited_at = now()
    WHERE id = p_decision_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decision_revisit(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decision_revisit(uuid) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_decisions_summary();
CREATE OR REPLACE FUNCTION public.founder_decisions_summary()
RETURNS TABLE (
  total_decisions                   bigint,
  decisions_last_30d                bigint,
  decisions_last_7d                 bigint,
  decisions_today                   bigint,
  avg_decisions_per_day_30d         numeric,
  one_way_door_count                bigint,
  reversible_count                  bigint,
  high_impact_count                 bigint,
  existential_impact_count          bigint,
  decisions_due_revisit             bigint,
  decisions_overdue_revisit         bigint,
  decisions_reviewed_with_outcome   bigint,
  last_decision_at                  timestamptz,
  days_since_last_decision          int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE decided_on >= current_date - 30), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE decided_on >= current_date - 7), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE decided_on = current_date), 0),
    coalesce((SELECT round((count(*)::numeric / 30.0), 2)
              FROM public.founder_decisions WHERE decided_on >= current_date - 30), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE reversibility = 'one_way_door'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE reversibility IN ('reversible_costly','reversible_cheap','easily_reversible')), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE impact_band = 'high'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE impact_band = 'existential'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions
              WHERE revisit_at IS NOT NULL AND revisit_at <= current_date AND revisited_at IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions
              WHERE revisit_at IS NOT NULL AND revisit_at < current_date - 7 AND revisited_at IS NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_decisions WHERE actual_outcome IS NOT NULL), 0),
    (SELECT max(created_at) FROM public.founder_decisions),
    coalesce((SELECT extract(day from (now() - max(created_at)))::int FROM public.founder_decisions), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decisions_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decisions_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_decisions_recent(int);
CREATE OR REPLACE FUNCTION public.founder_decisions_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id                       uuid,
  decided_on               date,
  decision_title           text,
  decision_summary         text,
  decision_kind            text,
  confidence_at_decision   text,
  reversibility            text,
  impact_band              text,
  revisit_at               date,
  revisited_at             timestamptz,
  has_outcome              boolean,
  created_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id, d.decided_on, d.decision_title, d.decision_summary,
    d.decision_kind, d.confidence_at_decision, d.reversibility, d.impact_band,
    d.revisit_at, d.revisited_at,
    (d.actual_outcome IS NOT NULL) AS has_outcome,
    d.created_at
  FROM public.founder_decisions d
  ORDER BY d.decided_on DESC, d.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decisions_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decisions_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_decisions_due_revisit();
CREATE OR REPLACE FUNCTION public.founder_decisions_due_revisit()
RETURNS TABLE (
  id                       uuid,
  decided_on               date,
  decision_title           text,
  decision_kind            text,
  impact_band              text,
  reversibility            text,
  revisit_at               date,
  days_overdue             int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    d.id, d.decided_on, d.decision_title, d.decision_kind,
    d.impact_band, d.reversibility, d.revisit_at,
    (current_date - d.revisit_at)::int AS days_overdue
  FROM public.founder_decisions d
  WHERE d.revisit_at IS NOT NULL
    AND d.revisit_at <= current_date
    AND d.revisited_at IS NULL
  ORDER BY d.revisit_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_decisions_due_revisit() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_decisions_due_revisit() TO authenticated;

COMMIT;