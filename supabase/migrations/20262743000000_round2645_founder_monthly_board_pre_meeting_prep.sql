-- r2645 founder monthly board pre-meeting prep

CREATE TABLE IF NOT EXISTS public.founder_board_pre_meeting_prep_r2645 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  meeting_at timestamptz NOT NULL,
  agenda_md text NOT NULL DEFAULT '',
  anticipated_questions_md text NOT NULL DEFAULT '',
  our_asks_md text NOT NULL DEFAULT '',
  prep_hours numeric NOT NULL DEFAULT 0,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','prepping','done','cancelled')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_pre_meeting_outcomes_r2645 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prep_id uuid NOT NULL REFERENCES public.founder_board_pre_meeting_prep_r2645(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('aligned','concerned','aligned_with_question','diverged')),
  question_accuracy_pct int NOT NULL DEFAULT 0 CHECK (question_accuracy_pct BETWEEN 0 AND 100),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_board_pre_meeting_prep_r2645 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_pre_meeting_outcomes_r2645 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_board_pre_meeting_prep_r2645;
CREATE POLICY founder_all ON public.founder_board_pre_meeting_prep_r2645
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.board_pre_meeting_outcomes_r2645;
CREATE POLICY founder_all ON public.board_pre_meeting_outcomes_r2645
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed prep rows
INSERT INTO public.founder_board_pre_meeting_prep_r2645
  (month_label, meeting_at, agenda_md, anticipated_questions_md, our_asks_md, prep_hours, owner_email, status, notes)
VALUES
  ('2026-04', '2026-04-15 10:00:00+05:30'::timestamptz, 'Q1 burn, runway, AMC churn, hospital chain rollout', 'Why AMC churn ticked up 2pp; Cashfree KYC ETA; engineer NPS dip', 'Approve bridge round term sheet; greenlight Tier-2 expansion', 12, 'founder@equipseva.com', 'done', 'Board pleased with revenue trajectory'),
  ('2026-05', '2026-05-20 10:00:00+05:30'::timestamptz, 'Series A readiness, Tier-2 pilot results, GST compliance', 'Tier-2 unit economics; counterfeit-parts detection rate; CDSCO posture', 'Sign off on Series A deck; approve hospital chain MSA template', 14, 'founder@equipseva.com', 'done', 'Two members flagged GST exposure'),
  ('2026-06', '2026-06-18 10:00:00+05:30'::timestamptz, 'Series A close, v0.5 launch readiness, hospital chain wins', 'Series A timeline; v0.5 risk register; engineer payout pipeline', 'Approve Series A allocation; greenlight v0.5 GA', 16, 'founder@equipseva.com', 'prepping', 'Heavy prep week ahead'),
  ('2026-07', '2026-07-15 10:00:00+05:30'::timestamptz, 'Post-Series A 100-day plan, hiring, SL/BD/NP pilot', 'Hiring velocity; international pilot economics; AI triage progress', 'Approve VP Engineering hire; sign SL/BD/NP pilot budget', 10, 'founder@equipseva.com', 'planned', 'First post-Series A board'),
  ('2026-08', '2026-08-19 10:00:00+05:30'::timestamptz, 'H2 plan, franchise model rollout, investor data room v2', 'Franchise unit economics; data room maturity; AI triage adoption', 'Approve franchise rollout plan; sign data room v2 budget', 8, 'founder@equipseva.com', 'planned', 'Light agenda planned');

-- Seed outcomes
INSERT INTO public.board_pre_meeting_outcomes_r2645
  (prep_id, observed_at, outcome_kind, question_accuracy_pct, owner_email, status, notes)
SELECT id, '2026-04-15 12:00:00+05:30'::timestamptz, 'aligned', 85, 'founder@equipseva.com', 'done', 'Board aligned on bridge round'
FROM public.founder_board_pre_meeting_prep_r2645 WHERE month_label='2026-04';

INSERT INTO public.board_pre_meeting_outcomes_r2645
  (prep_id, observed_at, outcome_kind, question_accuracy_pct, owner_email, status, notes)
SELECT id, '2026-05-20 12:00:00+05:30'::timestamptz, 'aligned_with_question', 70, 'founder@equipseva.com', 'done', 'GST question unanticipated'
FROM public.founder_board_pre_meeting_prep_r2645 WHERE month_label='2026-05';

INSERT INTO public.board_pre_meeting_outcomes_r2645
  (prep_id, observed_at, outcome_kind, question_accuracy_pct, owner_email, status, notes)
SELECT id, '2026-05-20 12:30:00+05:30'::timestamptz, 'concerned', 60, 'founder@equipseva.com', 'open', 'Member flagged Tier-2 burn'
FROM public.founder_board_pre_meeting_prep_r2645 WHERE month_label='2026-05';

INSERT INTO public.board_pre_meeting_outcomes_r2645
  (prep_id, observed_at, outcome_kind, question_accuracy_pct, owner_email, status, notes)
SELECT id, '2026-06-18 12:00:00+05:30'::timestamptz, 'aligned', 90, 'founder@equipseva.com', 'open', 'Series A momentum strong'
FROM public.founder_board_pre_meeting_prep_r2645 WHERE month_label='2026-06';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_prep_r2645()
RETURNS TABLE (
  id uuid,
  month_label text,
  meeting_at timestamptz,
  agenda_md text,
  anticipated_questions_md text,
  our_asks_md text,
  prep_hours numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.month_label, p.meeting_at, p.agenda_md, p.anticipated_questions_md,
         p.our_asks_md, p.prep_hours, p.owner_email, p.status, p.notes, p.created_at
  FROM public.founder_board_pre_meeting_prep_r2645 p
  ORDER BY p.meeting_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_prep_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_prep_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2645()
RETURNS TABLE (
  id uuid,
  prep_id uuid,
  month_label text,
  observed_at timestamptz,
  outcome_kind text,
  question_accuracy_pct int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.prep_id, p.month_label, o.observed_at, o.outcome_kind,
         o.question_accuracy_pct, o.owner_email, o.status, o.notes
  FROM public.board_pre_meeting_outcomes_r2645 o
  JOIN public.founder_board_pre_meeting_prep_r2645 p ON p.id = o.prep_id
  ORDER BY o.observed_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_prep_hours_focus_r2645()
RETURNS TABLE (
  month_label text,
  prep_hours numeric,
  status text,
  meeting_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.month_label, p.prep_hours, p.status, p.meeting_at
  FROM public.founder_board_pre_meeting_prep_r2645 p
  ORDER BY p.prep_hours DESC NULLS LAST, p.meeting_at DESC
  LIMIT 5;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_prep_hours_focus_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_prep_hours_focus_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.outcome_kind_distribution_r2645()
RETURNS TABLE (
  outcome_kind text,
  outcome_count bigint,
  avg_accuracy_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outcome_kind,
         count(*)::bigint AS outcome_count,
         round(avg(o.question_accuracy_pct)::numeric, 1) AS avg_accuracy_pct
  FROM public.board_pre_meeting_outcomes_r2645 o
  GROUP BY o.outcome_kind
  ORDER BY outcome_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.outcome_kind_distribution_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_kind_distribution_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2645()
RETURNS TABLE (
  status text,
  prep_count bigint,
  total_prep_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.status,
         count(*)::bigint AS prep_count,
         coalesce(sum(p.prep_hours), 0)::numeric AS total_prep_hours
  FROM public.founder_board_pre_meeting_prep_r2645 p
  GROUP BY p.status
  ORDER BY prep_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_prep_trend_r2645()
RETURNS TABLE (
  month_label text,
  meeting_at timestamptz,
  prep_hours numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.month_label, p.meeting_at, p.prep_hours, p.status
  FROM public.founder_board_pre_meeting_prep_r2645 p
  ORDER BY p.meeting_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.monthly_prep_trend_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_prep_trend_r2645() TO authenticated;

CREATE OR REPLACE FUNCTION public.question_accuracy_summary_r2645()
RETURNS TABLE (
  outcomes_logged bigint,
  avg_accuracy_pct numeric,
  min_accuracy_pct int,
  max_accuracy_pct int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         round(coalesce(avg(o.question_accuracy_pct), 0)::numeric, 1),
         coalesce(min(o.question_accuracy_pct), 0)::int,
         coalesce(max(o.question_accuracy_pct), 0)::int
  FROM public.board_pre_meeting_outcomes_r2645 o;
END; $$;
REVOKE EXECUTE ON FUNCTION public.question_accuracy_summary_r2645() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.question_accuracy_summary_r2645() TO authenticated;
