-- r2461 founder-fundraising-funnel
-- Track investor pipeline: intro -> meeting -> diligence -> term sheet -> close
-- ARR + valuation offers, stalled investors, conversion analytics

CREATE TABLE IF NOT EXISTS public.founder_fundraising_funnel_r2461 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm_name text NOT NULL,
  intro_at timestamptz,
  first_meeting_at timestamptz,
  diligence_started_at timestamptz,
  term_sheet_at timestamptz,
  closed_at timestamptz,
  stage text NOT NULL CHECK (stage IN ('intro','first_meeting','diligence','term_sheet','closed','passed')),
  pass_reason text,
  arr_offered_rupees bigint,
  valuation_offered_rupees bigint,
  lead_owner_email text NOT NULL,
  stalled_since timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fundraising_stage_actions_r2461 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.founder_fundraising_funnel_r2461(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('call','email','meeting','dataroom_share','follow_up')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  next_step text,
  next_step_due_at timestamptz,
  owner_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_fundraising_funnel_r2461 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fundraising_stage_actions_r2461 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_fundraising_funnel_r2461;
CREATE POLICY founder_all ON public.founder_fundraising_funnel_r2461
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.fundraising_stage_actions_r2461;
CREATE POLICY founder_all ON public.fundraising_stage_actions_r2461
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed investors
INSERT INTO public.founder_fundraising_funnel_r2461
  (investor_name, firm_name, intro_at, first_meeting_at, diligence_started_at, term_sheet_at, closed_at, stage, pass_reason, arr_offered_rupees, valuation_offered_rupees, lead_owner_email, stalled_since, notes)
VALUES
  ('Anita Rao', 'Blume Ventures', '2026-04-02'::timestamptz, '2026-04-12'::timestamptz, '2026-05-01'::timestamptz, '2026-06-10'::timestamptz, NULL, 'term_sheet', NULL, 30000000, 1200000000, 'founder@equipseva.in', NULL, 'Term sheet under review'),
  ('Karthik Reddy', 'Stellaris', '2026-03-20'::timestamptz, '2026-04-05'::timestamptz, '2026-05-15'::timestamptz, NULL, NULL, 'diligence', NULL, 25000000, 900000000, 'founder@equipseva.in', '2026-06-05'::timestamptz, 'Awaiting unit economics deck'),
  ('Priya Iyer', 'Elevation Capital', '2026-05-10'::timestamptz, '2026-05-25'::timestamptz, NULL, NULL, NULL, 'first_meeting', NULL, NULL, NULL, 'founder@equipseva.in', NULL, 'Positive first call'),
  ('Rohan Mehta', 'Matrix Partners', '2026-02-15'::timestamptz, '2026-03-01'::timestamptz, '2026-03-20'::timestamptz, NULL, NULL, 'passed', 'TAM concerns', NULL, NULL, 'founder@equipseva.in', NULL, 'Passed after diligence'),
  ('Sneha Kapoor', 'Accel', '2026-05-28'::timestamptz, NULL, NULL, NULL, NULL, 'intro', NULL, NULL, NULL, 'founder@equipseva.in', NULL, 'Warm intro from portfolio CEO');

-- Seed stage actions
INSERT INTO public.fundraising_stage_actions_r2461
  (investor_id, action_at, action_kind, outcome, next_step, next_step_due_at, owner_email, notes)
SELECT id, '2026-06-15'::timestamptz, 'meeting', 'positive', 'Send legal redlines', '2026-06-22'::timestamptz, 'founder@equipseva.in', 'Partner meeting cleared'
FROM public.founder_fundraising_funnel_r2461 WHERE investor_name = 'Anita Rao';

INSERT INTO public.fundraising_stage_actions_r2461
  (investor_id, action_at, action_kind, outcome, next_step, next_step_due_at, owner_email, notes)
SELECT id, '2026-06-18'::timestamptz, 'email', 'pending', 'Follow up on DD checklist', '2026-06-25'::timestamptz, 'founder@equipseva.in', 'Sent metrics pack'
FROM public.founder_fundraising_funnel_r2461 WHERE investor_name = 'Karthik Reddy';

INSERT INTO public.fundraising_stage_actions_r2461
  (investor_id, action_at, action_kind, outcome, next_step, next_step_due_at, owner_email, notes)
SELECT id, '2026-06-19'::timestamptz, 'dataroom_share', 'neutral', 'Schedule deep dive', '2026-06-26'::timestamptz, 'founder@equipseva.in', 'Dataroom invite sent'
FROM public.founder_fundraising_funnel_r2461 WHERE investor_name = 'Priya Iyer';

INSERT INTO public.fundraising_stage_actions_r2461
  (investor_id, action_at, action_kind, outcome, next_step, next_step_due_at, owner_email, notes)
SELECT id, '2026-06-20'::timestamptz, 'call', 'positive', 'Send intro deck', '2026-06-23'::timestamptz, 'founder@equipseva.in', 'First call scheduled'
FROM public.founder_fundraising_funnel_r2461 WHERE investor_name = 'Sneha Kapoor';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_funnel_r2461()
RETURNS TABLE (id uuid, investor_name text, firm_name text, stage text, arr_offered_rupees bigint, valuation_offered_rupees bigint, lead_owner_email text, stalled_since timestamptz, intro_at timestamptz, term_sheet_at timestamptz, closed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.investor_name, f.firm_name, f.stage, f.arr_offered_rupees, f.valuation_offered_rupees, f.lead_owner_email, f.stalled_since, f.intro_at, f.term_sheet_at, f.closed_at
  FROM public.founder_fundraising_funnel_r2461 f
  ORDER BY f.intro_at DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_funnel_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_funnel_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_stage_actions_r2461()
RETURNS TABLE (id uuid, investor_name text, firm_name text, action_at timestamptz, action_kind text, outcome text, next_step text, next_step_due_at timestamptz, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, f.investor_name, f.firm_name, a.action_at, a.action_kind, a.outcome, a.next_step, a.next_step_due_at, a.owner_email
  FROM public.fundraising_stage_actions_r2461 a
  JOIN public.founder_fundraising_funnel_r2461 f ON f.id = a.investor_id
  ORDER BY a.action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_stage_actions_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stage_actions_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.stage_distribution_r2461()
RETURNS TABLE (stage text, investor_count bigint, total_arr_offered_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.stage, COUNT(*)::bigint, COALESCE(SUM(f.arr_offered_rupees), 0)::bigint
  FROM public.founder_fundraising_funnel_r2461 f
  GROUP BY f.stage
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.stage_distribution_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_distribution_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_arr_offers_r2461()
RETURNS TABLE (investor_name text, firm_name text, stage text, arr_offered_rupees bigint, valuation_offered_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.investor_name, f.firm_name, f.stage, f.arr_offered_rupees, f.valuation_offered_rupees
  FROM public.founder_fundraising_funnel_r2461 f
  WHERE f.arr_offered_rupees IS NOT NULL
  ORDER BY f.arr_offered_rupees DESC NULLS LAST
  LIMIT 10;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_arr_offers_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_offers_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.stalled_investors_r2461()
RETURNS TABLE (investor_name text, firm_name text, stage text, stalled_since timestamptz, days_stalled integer, lead_owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.investor_name, f.firm_name, f.stage, f.stalled_since,
         EXTRACT(DAY FROM (now() - f.stalled_since))::integer,
         f.lead_owner_email
  FROM public.founder_fundraising_funnel_r2461 f
  WHERE f.stalled_since IS NOT NULL AND f.stage NOT IN ('closed','passed')
  ORDER BY f.stalled_since ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.stalled_investors_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stalled_investors_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.conversion_rate_r2461()
RETURNS TABLE (total_intros bigint, reached_meeting bigint, reached_diligence bigint, reached_term_sheet bigint, reached_closed bigint, intro_to_meeting_pct numeric, meeting_to_diligence_pct numeric, diligence_to_term_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_intro bigint;
  v_meet bigint;
  v_dil bigint;
  v_term bigint;
  v_closed bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_intro FROM public.founder_fundraising_funnel_r2461 WHERE intro_at IS NOT NULL;
  SELECT COUNT(*) INTO v_meet FROM public.founder_fundraising_funnel_r2461 WHERE first_meeting_at IS NOT NULL;
  SELECT COUNT(*) INTO v_dil FROM public.founder_fundraising_funnel_r2461 WHERE diligence_started_at IS NOT NULL;
  SELECT COUNT(*) INTO v_term FROM public.founder_fundraising_funnel_r2461 WHERE term_sheet_at IS NOT NULL;
  SELECT COUNT(*) INTO v_closed FROM public.founder_fundraising_funnel_r2461 WHERE closed_at IS NOT NULL;
  RETURN QUERY SELECT
    v_intro, v_meet, v_dil, v_term, v_closed,
    CASE WHEN v_intro > 0 THEN ROUND((v_meet::numeric / v_intro::numeric) * 100, 1) ELSE 0 END,
    CASE WHEN v_meet > 0 THEN ROUND((v_dil::numeric / v_meet::numeric) * 100, 1) ELSE 0 END,
    CASE WHEN v_dil > 0 THEN ROUND((v_term::numeric / v_dil::numeric) * 100, 1) ELSE 0 END;
END; $$;
REVOKE EXECUTE ON FUNCTION public.conversion_rate_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conversion_rate_r2461() TO authenticated;

CREATE OR REPLACE FUNCTION public.this_week_actions_r2461()
RETURNS TABLE (investor_name text, firm_name text, action_kind text, outcome text, action_at timestamptz, next_step text, next_step_due_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.investor_name, f.firm_name, a.action_kind, a.outcome, a.action_at, a.next_step, a.next_step_due_at
  FROM public.fundraising_stage_actions_r2461 a
  JOIN public.founder_fundraising_funnel_r2461 f ON f.id = a.investor_id
  WHERE a.action_at >= (now() - INTERVAL '7 days')
  ORDER BY a.action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.this_week_actions_r2461() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_actions_r2461() TO authenticated;
