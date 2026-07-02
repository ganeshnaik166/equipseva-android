BEGIN;

-- =====================================================================
-- Round 1613 — Founder Investor Reference Checks Log
-- Back-channel reference checks with portfolio founders before accepting investor
-- Per-investor 360 reference rating · founder go/no-go decision
-- =====================================================================

-- Drop any prior shape (safety)
DROP TABLE IF EXISTS public.founder_investor_references CASCADE;
DROP TABLE IF EXISTS public.founder_investor_prospects CASCADE;

-- -------------------------------------------------------------
-- TABLE 1 — investor prospects (one row per investor being vetted)
-- -------------------------------------------------------------
CREATE TABLE public.founder_investor_prospects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm_name text NOT NULL,
  fund_stage text NOT NULL CHECK (fund_stage IN ('angel','pre_seed','seed','series_a','series_b','growth')),
  proposed_ticket_lakhs numeric(12,2) NOT NULL CHECK (proposed_ticket_lakhs >= 0),
  proposed_valuation_cr numeric(12,2),
  intro_source text,
  first_meeting_at timestamptz,
  founder_gut_score int CHECK (founder_gut_score BETWEEN 1 AND 10),
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending','go','no_go','park')),
  decision_reason text,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_fip_decision ON public.founder_investor_prospects(decision);
CREATE INDEX idx_fip_created ON public.founder_investor_prospects(created_at DESC);

ALTER TABLE public.founder_investor_prospects ENABLE ROW LEVEL SECURITY;

CREATE POLICY fip_founder_only ON public.founder_investor_prospects
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -------------------------------------------------------------
-- TABLE 2 — reference checks (one row per portfolio-founder call)
-- -------------------------------------------------------------
CREATE TABLE public.founder_investor_references (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid NOT NULL REFERENCES public.founder_investor_prospects(id) ON DELETE CASCADE,
  portfolio_founder_name text NOT NULL,
  portfolio_company text NOT NULL,
  contact_channel text CHECK (contact_channel IN ('warm_intro','cold_linkedin','common_friend','founder_network','direct')),
  call_completed_at timestamptz,
  -- 360 ratings (1-5)
  responsiveness_rating int CHECK (responsiveness_rating BETWEEN 1 AND 5),
  value_add_rating int CHECK (value_add_rating BETWEEN 1 AND 5),
  founder_friendly_rating int CHECK (founder_friendly_rating BETWEEN 1 AND 5),
  follow_on_rating int CHECK (follow_on_rating BETWEEN 1 AND 5),
  pressure_in_downturn_rating int CHECK (pressure_in_downturn_rating BETWEEN 1 AND 5),
  network_strength_rating int CHECK (network_strength_rating BETWEEN 1 AND 5),
  would_take_again_rating int CHECK (would_take_again_rating BETWEEN 1 AND 5),
  red_flag_notes text,
  green_flag_notes text,
  verbatim_quote text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_fir_prospect ON public.founder_investor_references(prospect_id);
CREATE INDEX idx_fir_completed ON public.founder_investor_references(call_completed_at DESC);

ALTER TABLE public.founder_investor_references ENABLE ROW LEVEL SECURITY;

CREATE POLICY fir_founder_only ON public.founder_investor_references
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

-- 1. Prospect roster with aggregate rating
CREATE OR REPLACE FUNCTION public.founder_investor_prospects_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  fund_stage text,
  proposed_ticket_lakhs numeric,
  proposed_valuation_cr numeric,
  decision text,
  refs_completed int,
  avg_rating numeric,
  founder_gut_score int,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ref_stats AS (
    SELECT prospect_id,
           COUNT(*) FILTER (WHERE call_completed_at IS NOT NULL)::int AS done,
           AVG((COALESCE(responsiveness_rating,0)+COALESCE(value_add_rating,0)+COALESCE(founder_friendly_rating,0)+COALESCE(follow_on_rating,0)+COALESCE(pressure_in_downturn_rating,0)+COALESCE(network_strength_rating,0)+COALESCE(would_take_again_rating,0))::numeric/NULLIF(7,0)) AS avgr
    FROM founder_investor_references
    GROUP BY prospect_id
  )
  SELECT p.id, p.investor_name, p.firm_name, p.fund_stage,
         p.proposed_ticket_lakhs, p.proposed_valuation_cr, p.decision,
         COALESCE(r.done,0), ROUND(COALESCE(r.avgr,0),2),
         p.founder_gut_score, p.created_at
  FROM founder_investor_prospects p
  LEFT JOIN ref_stats r ON r.prospect_id = p.id
  ORDER BY p.created_at DESC
  LIMIT 200;
END $$;

-- 2. KPI summary
CREATE OR REPLACE FUNCTION public.founder_investor_prospects_kpis()
RETURNS TABLE (
  total_prospects int,
  pending_count int,
  go_count int,
  no_go_count int,
  parked_count int,
  total_refs int,
  refs_completed int,
  avg_refs_per_prospect numeric,
  avg_rating_overall numeric,
  avg_gut_score numeric,
  total_proposed_lakhs numeric,
  go_proposed_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH p AS (
    SELECT COUNT(*)::int AS tot,
           COUNT(*) FILTER (WHERE decision='pending')::int AS pend,
           COUNT(*) FILTER (WHERE decision='go')::int AS gocnt,
           COUNT(*) FILTER (WHERE decision='no_go')::int AS nogocnt,
           COUNT(*) FILTER (WHERE decision='park')::int AS parkcnt,
           COALESCE(AVG(founder_gut_score),0)::numeric AS gut,
           COALESCE(SUM(proposed_ticket_lakhs),0)::numeric AS prop_tot,
           COALESCE(SUM(proposed_ticket_lakhs) FILTER (WHERE decision='go'),0)::numeric AS prop_go
    FROM founder_investor_prospects
  ),
  r AS (
    SELECT COUNT(*)::int AS tot,
           COUNT(*) FILTER (WHERE call_completed_at IS NOT NULL)::int AS done,
           COALESCE(AVG((COALESCE(responsiveness_rating,0)+COALESCE(value_add_rating,0)+COALESCE(founder_friendly_rating,0)+COALESCE(follow_on_rating,0)+COALESCE(pressure_in_downturn_rating,0)+COALESCE(network_strength_rating,0)+COALESCE(would_take_again_rating,0))::numeric/NULLIF(7,0)),0) AS avgr
    FROM founder_investor_references
  )
  SELECT p.tot, p.pend, p.gocnt, p.nogocnt, p.parkcnt,
         r.tot, r.done,
         CASE WHEN p.tot>0 THEN ROUND(r.tot::numeric / p.tot, 2) ELSE 0 END,
         ROUND(r.avgr, 2),
         ROUND(p.gut, 2),
         p.prop_tot,
         p.prop_go
  FROM p, r;
END $$;

-- 3. Recent reference calls
CREATE OR REPLACE FUNCTION public.founder_investor_references_recent()
RETURNS TABLE (
  id uuid,
  prospect_id uuid,
  investor_name text,
  firm_name text,
  portfolio_founder_name text,
  portfolio_company text,
  contact_channel text,
  call_completed_at timestamptz,
  avg_rating numeric,
  red_flag_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.prospect_id, p.investor_name, p.firm_name,
         r.portfolio_founder_name, r.portfolio_company,
         r.contact_channel, r.call_completed_at,
         ROUND(((COALESCE(r.responsiveness_rating,0)+COALESCE(r.value_add_rating,0)+COALESCE(r.founder_friendly_rating,0)+COALESCE(r.follow_on_rating,0)+COALESCE(r.pressure_in_downturn_rating,0)+COALESCE(r.network_strength_rating,0)+COALESCE(r.would_take_again_rating,0))::numeric/7),2) AS avgr,
         r.red_flag_notes, r.created_at
  FROM founder_investor_references r
  JOIN founder_investor_prospects p ON p.id = r.prospect_id
  ORDER BY r.created_at DESC
  LIMIT 100;
END $$;

-- 4. Dimension breakdown
CREATE OR REPLACE FUNCTION public.founder_investor_reference_dimensions()
RETURNS TABLE (
  dimension text,
  avg_rating numeric,
  samples int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'responsiveness'::text, ROUND(AVG(responsiveness_rating)::numeric,2), COUNT(responsiveness_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'value_add', ROUND(AVG(value_add_rating)::numeric,2), COUNT(value_add_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'founder_friendly', ROUND(AVG(founder_friendly_rating)::numeric,2), COUNT(founder_friendly_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'follow_on', ROUND(AVG(follow_on_rating)::numeric,2), COUNT(follow_on_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'pressure_in_downturn', ROUND(AVG(pressure_in_downturn_rating)::numeric,2), COUNT(pressure_in_downturn_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'network_strength', ROUND(AVG(network_strength_rating)::numeric,2), COUNT(network_strength_rating)::int FROM founder_investor_references
  UNION ALL
  SELECT 'would_take_again', ROUND(AVG(would_take_again_rating)::numeric,2), COUNT(would_take_again_rating)::int FROM founder_investor_references
  ORDER BY 2 DESC NULLS LAST;
END $$;

-- 5. Stage breakdown
CREATE OR REPLACE FUNCTION public.founder_investor_stage_breakdown()
RETURNS TABLE (
  fund_stage text,
  prospects int,
  go_decisions int,
  avg_ticket_lakhs numeric,
  avg_rating numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH refs AS (
    SELECT prospect_id,
           AVG((COALESCE(responsiveness_rating,0)+COALESCE(value_add_rating,0)+COALESCE(founder_friendly_rating,0)+COALESCE(follow_on_rating,0)+COALESCE(pressure_in_downturn_rating,0)+COALESCE(network_strength_rating,0)+COALESCE(would_take_again_rating,0))::numeric/7) AS avgr
    FROM founder_investor_references GROUP BY prospect_id
  )
  SELECT p.fund_stage,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE p.decision='go')::int,
         ROUND(AVG(p.proposed_ticket_lakhs)::numeric,2),
         ROUND(AVG(r.avgr)::numeric,2)
  FROM founder_investor_prospects p
  LEFT JOIN refs r ON r.prospect_id = p.id
  GROUP BY p.fund_stage
  ORDER BY 2 DESC;
END $$;

-- 6. Red-flag log (any reference with red_flag_notes)
CREATE OR REPLACE FUNCTION public.founder_investor_red_flags()
RETURNS TABLE (
  id uuid,
  investor_name text,
  firm_name text,
  portfolio_founder_name text,
  red_flag_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, p.investor_name, p.firm_name, r.portfolio_founder_name,
         r.red_flag_notes, r.created_at
  FROM founder_investor_references r
  JOIN founder_investor_prospects p ON p.id = r.prospect_id
  WHERE r.red_flag_notes IS NOT NULL AND length(trim(r.red_flag_notes)) > 0
  ORDER BY r.created_at DESC
  LIMIT 50;
END $$;

-- 7. Channel breakdown
CREATE OR REPLACE FUNCTION public.founder_investor_channel_breakdown()
RETURNS TABLE (
  contact_channel text,
  refs_count int,
  avg_rating numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(contact_channel,'unspecified')::text,
         COUNT(*)::int,
         ROUND(AVG((COALESCE(responsiveness_rating,0)+COALESCE(value_add_rating,0)+COALESCE(founder_friendly_rating,0)+COALESCE(follow_on_rating,0)+COALESCE(pressure_in_downturn_rating,0)+COALESCE(network_strength_rating,0)+COALESCE(would_take_again_rating,0))::numeric/7)::numeric,2)
  FROM founder_investor_references
  GROUP BY contact_channel
  ORDER BY 2 DESC;
END $$;

-- =====================================================================
-- WRITE HELPERS (VOLATILE)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.log_founder_investor_prospect_add(
  p_investor_name text,
  p_firm_name text,
  p_fund_stage text,
  p_proposed_ticket_lakhs numeric,
  p_proposed_valuation_cr numeric,
  p_intro_source text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_prospects(investor_name, firm_name, fund_stage, proposed_ticket_lakhs, proposed_valuation_cr, intro_source)
  VALUES (p_investor_name, p_firm_name, p_fund_stage, p_proposed_ticket_lakhs, p_proposed_valuation_cr, p_intro_source)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_prospect_add',
          jsonb_build_object('id', v_id, 'investor_name', p_investor_name, 'firm_name', p_firm_name), now());
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_investor_reference_add(
  p_prospect_id uuid,
  p_portfolio_founder_name text,
  p_portfolio_company text,
  p_contact_channel text,
  p_responsiveness int,
  p_value_add int,
  p_founder_friendly int,
  p_follow_on int,
  p_pressure int,
  p_network int,
  p_take_again int,
  p_red_flag text,
  p_green_flag text,
  p_quote text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_references(
    prospect_id, portfolio_founder_name, portfolio_company, contact_channel, call_completed_at,
    responsiveness_rating, value_add_rating, founder_friendly_rating, follow_on_rating,
    pressure_in_downturn_rating, network_strength_rating, would_take_again_rating,
    red_flag_notes, green_flag_notes, verbatim_quote)
  VALUES (p_prospect_id, p_portfolio_founder_name, p_portfolio_company, p_contact_channel, now(),
          p_responsiveness, p_value_add, p_founder_friendly, p_follow_on,
          p_pressure, p_network, p_take_again,
          p_red_flag, p_green_flag, p_quote)
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_reference_add',
          jsonb_build_object('id', v_id, 'prospect_id', p_prospect_id, 'portfolio_founder', p_portfolio_founder_name), now());
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_investor_decide(
  p_prospect_id uuid,
  p_decision text,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('pending','go','no_go','park') THEN
    RAISE EXCEPTION 'invalid_decision';
  END IF;
  UPDATE founder_investor_prospects
  SET decision = p_decision,
      decision_reason = p_reason,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_prospect_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_decide',
          jsonb_build_object('prospect_id', p_prospect_id, 'decision', p_decision, 'reason', p_reason), now());
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_investor_gut_score(
  p_prospect_id uuid,
  p_score int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score < 1 OR p_score > 10 THEN RAISE EXCEPTION 'score_out_of_range'; END IF;
  UPDATE founder_investor_prospects
  SET founder_gut_score = p_score, updated_at = now()
  WHERE id = p_prospect_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_gut_score',
          jsonb_build_object('prospect_id', p_prospect_id, 'score', p_score), now());
END $$;

-- =====================================================================
-- PERMISSIONS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.founder_investor_prospects_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_prospects_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_references_recent() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_reference_dimensions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_stage_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_red_flags() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_investor_channel_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_prospect_add(text,text,text,numeric,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_reference_add(uuid,text,text,text,int,int,int,int,int,int,int,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_decide(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_investor_gut_score(uuid,int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_investor_prospects_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_prospects_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_references_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_reference_dimensions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_stage_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_red_flags() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_investor_channel_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_investor_prospect_add(text,text,text,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_investor_reference_add(uuid,text,text,text,int,int,int,int,int,int,int,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_investor_decide(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_investor_gut_score(uuid,int) TO authenticated;

COMMIT;