BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_bet_capital_allocation_r2369 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_name text NOT NULL,
  bet_category text NOT NULL CHECK (bet_category IN ('vertical','geography','product','channel','technology','partnership')),
  bet_thesis text NOT NULL,
  initial_capital_rupees bigint NOT NULL DEFAULT 0,
  capital_deployed_rupees bigint NOT NULL DEFAULT 0,
  capital_remaining_rupees bigint NOT NULL DEFAULT 0,
  revenue_generated_rupees bigint NOT NULL DEFAULT 0,
  gross_margin_rupees bigint NOT NULL DEFAULT 0,
  roi_percent numeric(8,2) NOT NULL DEFAULT 0,
  payback_months numeric(6,2),
  bet_started_at timestamptz NOT NULL DEFAULT now(),
  bet_status text NOT NULL DEFAULT 'active' CHECK (bet_status IN ('active','scaling','pausing','killing','redeployed','succeeded')),
  redeployment_target text,
  redeployment_decision_at timestamptz,
  decision_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsbca_r2369_status ON public.founder_strategic_bet_capital_allocation_r2369(bet_status);
CREATE INDEX IF NOT EXISTS idx_fsbca_r2369_category ON public.founder_strategic_bet_capital_allocation_r2369(bet_category);
CREATE INDEX IF NOT EXISTS idx_fsbca_r2369_roi ON public.founder_strategic_bet_capital_allocation_r2369(roi_percent DESC);

ALTER TABLE public.founder_strategic_bet_capital_allocation_r2369 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsbca_r2369_founder_all ON public.founder_strategic_bet_capital_allocation_r2369;
CREATE POLICY fsbca_r2369_founder_all ON public.founder_strategic_bet_capital_allocation_r2369
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_strategic_bet_capital_events_r2369 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bet_capital_allocation_r2369(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('deploy','recoup','redeploy','writedown','milestone','review')),
  amount_rupees bigint NOT NULL DEFAULT 0,
  event_note text,
  recorded_by_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsbce_r2369_bet ON public.founder_strategic_bet_capital_events_r2369(bet_id);
CREATE INDEX IF NOT EXISTS idx_fsbce_r2369_recorded ON public.founder_strategic_bet_capital_events_r2369(recorded_at DESC);

ALTER TABLE public.founder_strategic_bet_capital_events_r2369 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsbce_r2369_founder_all ON public.founder_strategic_bet_capital_events_r2369;
CREATE POLICY fsbce_r2369_founder_all ON public.founder_strategic_bet_capital_events_r2369
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.fsbca_r2369_list_bets()
RETURNS SETOF public.founder_strategic_bet_capital_allocation_r2369
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_strategic_bet_capital_allocation_r2369
    ORDER BY roi_percent DESC, bet_started_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_summary()
RETURNS TABLE(
  total_bets int,
  active_bets int,
  total_initial_capital bigint,
  total_deployed bigint,
  total_revenue bigint,
  total_margin bigint,
  avg_roi numeric,
  best_roi numeric,
  worst_roi numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE bet_status IN ('active','scaling'))::int,
    COALESCE(SUM(initial_capital_rupees),0),
    COALESCE(SUM(capital_deployed_rupees),0),
    COALESCE(SUM(revenue_generated_rupees),0),
    COALESCE(SUM(gross_margin_rupees),0),
    COALESCE(AVG(roi_percent),0)::numeric,
    COALESCE(MAX(roi_percent),0)::numeric,
    COALESCE(MIN(roi_percent),0)::numeric
  FROM public.founder_strategic_bet_capital_allocation_r2369;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_by_category()
RETURNS TABLE(
  bet_category text,
  bet_count int,
  total_deployed bigint,
  total_revenue bigint,
  avg_roi numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.bet_category,
    COUNT(*)::int,
    COALESCE(SUM(b.capital_deployed_rupees),0),
    COALESCE(SUM(b.revenue_generated_rupees),0),
    COALESCE(AVG(b.roi_percent),0)::numeric
  FROM public.founder_strategic_bet_capital_allocation_r2369 b
  GROUP BY b.bet_category
  ORDER BY 4 DESC;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_top_bets(p_limit int DEFAULT 10)
RETURNS SETOF public.founder_strategic_bet_capital_allocation_r2369
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_strategic_bet_capital_allocation_r2369
    WHERE bet_status IN ('active','scaling','succeeded')
    ORDER BY roi_percent DESC
    LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_redeployment_candidates()
RETURNS SETOF public.founder_strategic_bet_capital_allocation_r2369
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_strategic_bet_capital_allocation_r2369
    WHERE bet_status IN ('pausing','killing')
       OR (roi_percent < 0 AND bet_status = 'active')
    ORDER BY roi_percent ASC;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_recent_events(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  bet_id uuid,
  bet_name text,
  event_type text,
  amount_rupees bigint,
  event_note text,
  recorded_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.bet_id, b.bet_name, e.event_type, e.amount_rupees, e.event_note, e.recorded_at
  FROM public.founder_strategic_bet_capital_events_r2369 e
  JOIN public.founder_strategic_bet_capital_allocation_r2369 b ON b.id = e.bet_id
  ORDER BY e.recorded_at DESC
  LIMIT p_limit;
END $$;

CREATE OR REPLACE FUNCTION public.fsbca_r2369_capital_efficiency()
RETURNS TABLE(
  bet_id uuid,
  bet_name text,
  capital_deployed_rupees bigint,
  revenue_generated_rupees bigint,
  efficiency_ratio numeric,
  payback_months numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.id,
    b.bet_name,
    b.capital_deployed_rupees,
    b.revenue_generated_rupees,
    CASE WHEN b.capital_deployed_rupees > 0
      THEN (b.revenue_generated_rupees::numeric / b.capital_deployed_rupees::numeric)
      ELSE 0 END,
    b.payback_months
  FROM public.founder_strategic_bet_capital_allocation_r2369 b
  WHERE b.bet_status IN ('active','scaling','succeeded')
  ORDER BY 5 DESC NULLS LAST;
END $$;

REVOKE ALL ON FUNCTION public.fsbca_r2369_list_bets() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_by_category() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_top_bets(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_redeployment_candidates() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_recent_events(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fsbca_r2369_capital_efficiency() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fsbca_r2369_list_bets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_by_category() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_top_bets(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_redeployment_candidates() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_recent_events(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fsbca_r2369_capital_efficiency() TO authenticated;

COMMIT;
