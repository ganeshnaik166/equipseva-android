BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_engagement_score_r2308 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scored_for_month date NOT NULL,
  portal_login_count integer NOT NULL DEFAULT 0,
  amc_renewals_count integer NOT NULL DEFAULT 0,
  nps_score integer,
  referrals_made integer NOT NULL DEFAULT 0,
  composite_score numeric(6,2) NOT NULL DEFAULT 0,
  tier text NOT NULL DEFAULT 'cold',
  computed_at timestamptz NOT NULL DEFAULT now(),
  computed_by uuid REFERENCES public.profiles(id),
  notes text,
  UNIQUE (customer_user_id, scored_for_month)
);

CREATE INDEX IF NOT EXISTS idx_ces_r2308_month ON public.customer_engagement_score_r2308 (scored_for_month DESC);
CREATE INDEX IF NOT EXISTS idx_ces_r2308_tier ON public.customer_engagement_score_r2308 (tier);
CREATE INDEX IF NOT EXISTS idx_ces_r2308_score ON public.customer_engagement_score_r2308 (composite_score DESC);

ALTER TABLE public.customer_engagement_score_r2308 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ces_r2308_founder_all ON public.customer_engagement_score_r2308;
CREATE POLICY ces_r2308_founder_all ON public.customer_engagement_score_r2308
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_engagement_score_actions_r2308 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.customer_engagement_score_r2308(id) ON DELETE CASCADE,
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  action_status text NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES public.profiles(id),
  due_by date,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_ces_actions_r2308_score ON public.customer_engagement_score_actions_r2308 (score_id);
CREATE INDEX IF NOT EXISTS idx_ces_actions_r2308_status ON public.customer_engagement_score_actions_r2308 (action_status);
CREATE INDEX IF NOT EXISTS idx_ces_actions_r2308_customer ON public.customer_engagement_score_actions_r2308 (customer_user_id);

ALTER TABLE public.customer_engagement_score_actions_r2308 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ces_actions_r2308_founder_all ON public.customer_engagement_score_actions_r2308;
CREATE POLICY ces_actions_r2308_founder_all ON public.customer_engagement_score_actions_r2308
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.ces_r2308_record_score(uuid, date, integer, integer, integer, integer, text);
CREATE OR REPLACE FUNCTION public.ces_r2308_record_score(
  p_customer_user_id uuid,
  p_scored_for_month date,
  p_portal_logins integer,
  p_amc_renewals integer,
  p_nps integer,
  p_referrals integer,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid;
  v_score numeric(6,2);
  v_tier text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;

  v_score := LEAST(100, GREATEST(0,
    (COALESCE(p_portal_logins,0) * 2.0)
    + (COALESCE(p_amc_renewals,0) * 15.0)
    + (COALESCE(p_nps,0) * 3.0)
    + (COALESCE(p_referrals,0) * 10.0)
  ));

  v_tier := CASE
    WHEN v_score >= 75 THEN 'champion'
    WHEN v_score >= 50 THEN 'warm'
    WHEN v_score >= 25 THEN 'lukewarm'
    ELSE 'cold'
  END;

  INSERT INTO public.customer_engagement_score_r2308 (
    customer_user_id, scored_for_month, portal_login_count, amc_renewals_count,
    nps_score, referrals_made, composite_score, tier, computed_by, notes
  )
  VALUES (
    p_customer_user_id, p_scored_for_month, COALESCE(p_portal_logins,0),
    COALESCE(p_amc_renewals,0), p_nps, COALESCE(p_referrals,0), v_score, v_tier, v_caller, p_notes
  )
  ON CONFLICT (customer_user_id, scored_for_month) DO UPDATE
  SET portal_login_count = EXCLUDED.portal_login_count,
      amc_renewals_count = EXCLUDED.amc_renewals_count,
      nps_score = EXCLUDED.nps_score,
      referrals_made = EXCLUDED.referrals_made,
      composite_score = EXCLUDED.composite_score,
      tier = EXCLUDED.tier,
      computed_at = now(),
      computed_by = v_caller,
      notes = EXCLUDED.notes
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_record_score(uuid, date, integer, integer, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_record_score(uuid, date, integer, integer, integer, integer, text) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_open_action(uuid, text, uuid, date);
CREATE OR REPLACE FUNCTION public.ces_r2308_open_action(
  p_score_id uuid,
  p_action_type text,
  p_assigned_to uuid DEFAULT NULL,
  p_due_by date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid;
  v_customer uuid;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_caller FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  SELECT customer_user_id INTO v_customer FROM public.customer_engagement_score_r2308 WHERE id = p_score_id;

  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'score_not_found';
  END IF;

  INSERT INTO public.customer_engagement_score_actions_r2308 (
    score_id, customer_user_id, action_type, assigned_to, due_by, created_by
  ) VALUES (
    p_score_id, v_customer, p_action_type, p_assigned_to, p_due_by, v_caller
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_open_action(uuid, text, uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_open_action(uuid, text, uuid, date) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_close_action(uuid, text);
CREATE OR REPLACE FUNCTION public.ces_r2308_close_action(
  p_action_id uuid,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.customer_engagement_score_actions_r2308
  SET action_status = 'closed',
      outcome = p_outcome,
      closed_at = now()
  WHERE id = p_action_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_close_action(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_close_action(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_latest_scores(integer);
CREATE OR REPLACE FUNCTION public.ces_r2308_latest_scores(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  customer_email text,
  scored_for_month date,
  portal_login_count integer,
  amc_renewals_count integer,
  nps_score integer,
  referrals_made integer,
  composite_score numeric,
  tier text,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.id, p.email, s.scored_for_month, s.portal_login_count, s.amc_renewals_count,
         s.nps_score, s.referrals_made, s.composite_score, s.tier, s.computed_at
  FROM public.customer_engagement_score_r2308 s
  JOIN public.profiles p ON p.id = s.customer_user_id
  ORDER BY s.scored_for_month DESC, s.composite_score DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_latest_scores(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_latest_scores(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_tier_distribution(date);
CREATE OR REPLACE FUNCTION public.ces_r2308_tier_distribution(p_month date DEFAULT NULL)
RETURNS TABLE (
  tier text,
  customers integer,
  avg_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_month date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_month := COALESCE(p_month, (SELECT MAX(scored_for_month) FROM public.customer_engagement_score_r2308));

  RETURN QUERY
  SELECT s.tier, COUNT(*)::integer AS customers, ROUND(AVG(s.composite_score), 2) AS avg_score
  FROM public.customer_engagement_score_r2308 s
  WHERE s.scored_for_month = v_month
  GROUP BY s.tier
  ORDER BY avg_score DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_tier_distribution(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_tier_distribution(date) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_open_actions(integer);
CREATE OR REPLACE FUNCTION public.ces_r2308_open_actions(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  customer_email text,
  action_type text,
  action_status text,
  due_by date,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT a.id, p.email, a.action_type, a.action_status, a.due_by, a.created_at
  FROM public.customer_engagement_score_actions_r2308 a
  JOIN public.profiles p ON p.id = a.customer_user_id
  WHERE a.action_status = 'open'
  ORDER BY a.due_by NULLS LAST, a.created_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_open_actions(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_open_actions(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_summary();
CREATE OR REPLACE FUNCTION public.ces_r2308_summary()
RETURNS TABLE (
  total_scored integer,
  champions integer,
  cold integer,
  avg_score numeric,
  open_actions integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM public.customer_engagement_score_r2308),
    (SELECT COUNT(*)::integer FROM public.customer_engagement_score_r2308 WHERE tier = 'champion'),
    (SELECT COUNT(*)::integer FROM public.customer_engagement_score_r2308 WHERE tier = 'cold'),
    (SELECT ROUND(AVG(composite_score), 2) FROM public.customer_engagement_score_r2308),
    (SELECT COUNT(*)::integer FROM public.customer_engagement_score_actions_r2308 WHERE action_status = 'open');
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.ces_r2308_top_at_risk(integer);
CREATE OR REPLACE FUNCTION public.ces_r2308_top_at_risk(p_limit integer DEFAULT 20)
RETURNS TABLE (
  id uuid,
  customer_email text,
  composite_score numeric,
  tier text,
  scored_for_month date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.id, p.email, s.composite_score, s.tier, s.scored_for_month
  FROM public.customer_engagement_score_r2308 s
  JOIN public.profiles p ON p.id = s.customer_user_id
  WHERE s.tier IN ('cold', 'lukewarm')
  ORDER BY s.composite_score ASC, s.scored_for_month DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 20));
END;
$$;

REVOKE ALL ON FUNCTION public.ces_r2308_top_at_risk(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ces_r2308_top_at_risk(integer) TO authenticated;

COMMIT;
