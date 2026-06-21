BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_performance_reports_r1749 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  report_period_start date NOT NULL,
  report_period_end date NOT NULL,
  invested_rupees bigint NOT NULL DEFAULT 0,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  distributions_received_rupees bigint NOT NULL DEFAULT 0,
  irr_pct numeric(8,2) NOT NULL DEFAULT 0,
  moic numeric(8,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ipr_r1749_investor ON public.investor_performance_reports_r1749(investor_id);
CREATE INDEX IF NOT EXISTS idx_ipr_r1749_period ON public.investor_performance_reports_r1749(report_period_end DESC);
CREATE INDEX IF NOT EXISTS idx_ipr_r1749_status ON public.investor_performance_reports_r1749(status);

CREATE TABLE IF NOT EXISTS public.investor_report_dispute_log_r1749 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.investor_performance_reports_r1749(id) ON DELETE CASCADE,
  dispute_text text NOT NULL,
  raised_at timestamptz NOT NULL DEFAULT now(),
  raised_by_email text,
  resolution_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irdl_r1749_report ON public.investor_report_dispute_log_r1749(report_id);
CREATE INDEX IF NOT EXISTS idx_irdl_r1749_raised ON public.investor_report_dispute_log_r1749(raised_at DESC);

ALTER TABLE public.investor_performance_reports_r1749 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_report_dispute_log_r1749 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ipr_r1749 ON public.investor_performance_reports_r1749;
CREATE POLICY founder_all_ipr_r1749 ON public.investor_performance_reports_r1749
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irdl_r1749 ON public.investor_report_dispute_log_r1749;
CREATE POLICY founder_all_irdl_r1749 ON public.investor_report_dispute_log_r1749
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_reports
CREATE OR REPLACE FUNCTION public.list_reports_r1749()
RETURNS TABLE(
  id uuid,
  investor_email text,
  report_period_start date,
  report_period_end date,
  invested_rupees bigint,
  current_value_rupees bigint,
  distributions_received_rupees bigint,
  irr_pct numeric,
  moic numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, p.email::text, r.report_period_start, r.report_period_end,
         r.invested_rupees, r.current_value_rupees, r.distributions_received_rupees,
         r.irr_pct, r.moic, r.status, r.created_at
  FROM public.investor_performance_reports_r1749 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: generate_report
CREATE OR REPLACE FUNCTION public.generate_report_r1749(
  p_investor_id uuid,
  p_period_start date,
  p_period_end date,
  p_invested_rupees bigint,
  p_current_value_rupees bigint,
  p_distributions_rupees bigint,
  p_irr_pct numeric,
  p_moic numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_performance_reports_r1749(
    investor_id, report_period_start, report_period_end,
    invested_rupees, current_value_rupees, distributions_received_rupees,
    irr_pct, moic, status
  ) VALUES (
    p_investor_id, p_period_start, p_period_end,
    p_invested_rupees, p_current_value_rupees, p_distributions_rupees,
    p_irr_pct, p_moic, 'draft'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'generate_report_r1749',
          jsonb_build_object('report_id', v_id, 'investor_id', p_investor_id, 'irr_pct', p_irr_pct));

  RETURN v_id;
END;
$$;

-- RPC 3: list_disputes
CREATE OR REPLACE FUNCTION public.list_disputes_r1749()
RETURNS TABLE(
  id uuid,
  report_id uuid,
  investor_email text,
  dispute_text text,
  raised_at timestamptz,
  raised_by_email text,
  resolution_at timestamptz,
  resolution_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.report_id, p.email::text, d.dispute_text, d.raised_at,
         d.raised_by_email, d.resolution_at, d.resolution_note
  FROM public.investor_report_dispute_log_r1749 d
  JOIN public.investor_performance_reports_r1749 r ON r.id = d.report_id
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY d.raised_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_dispute
CREATE OR REPLACE FUNCTION public.log_dispute_r1749(
  p_report_id uuid,
  p_dispute_text text,
  p_raised_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_report_dispute_log_r1749(report_id, dispute_text, raised_by_email)
  VALUES (p_report_id, p_dispute_text, p_raised_by_email)
  RETURNING id INTO v_id;

  UPDATE public.investor_performance_reports_r1749
  SET status = 'disputed', updated_at = now()
  WHERE id = p_report_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_dispute_r1749',
          jsonb_build_object('dispute_id', v_id, 'report_id', p_report_id));

  RETURN v_id;
END;
$$;

-- RPC 5: resolve_dispute
CREATE OR REPLACE FUNCTION public.resolve_dispute_r1749(
  p_dispute_id uuid,
  p_resolution_note text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_report_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_report_dispute_log_r1749
  SET resolution_at = now(), resolution_note = p_resolution_note, updated_at = now()
  WHERE id = p_dispute_id
  RETURNING report_id INTO v_report_id;

  UPDATE public.investor_performance_reports_r1749
  SET status = 'sent', updated_at = now()
  WHERE id = v_report_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'resolve_dispute_r1749',
          jsonb_build_object('dispute_id', p_dispute_id, 'report_id', v_report_id));
END;
$$;

-- RPC 6: irr_leaderboard
CREATE OR REPLACE FUNCTION public.irr_leaderboard_r1749()
RETURNS TABLE(
  investor_email text,
  best_irr_pct numeric,
  best_moic numeric,
  total_invested_rupees bigint,
  total_current_value_rupees bigint,
  report_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email::text,
         MAX(r.irr_pct) AS best_irr_pct,
         MAX(r.moic) AS best_moic,
         SUM(r.invested_rupees)::bigint AS total_invested_rupees,
         SUM(r.current_value_rupees)::bigint AS total_current_value_rupees,
         COUNT(*)::int AS report_count
  FROM public.investor_performance_reports_r1749 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  GROUP BY p.email
  ORDER BY best_irr_pct DESC NULLS LAST
  LIMIT 50;
END;
$$;

-- RPC 7: recent_reports_per_investor
CREATE OR REPLACE FUNCTION public.recent_reports_per_investor_r1749()
RETURNS TABLE(
  investor_email text,
  latest_report_at timestamptz,
  latest_irr_pct numeric,
  latest_moic numeric,
  latest_status text,
  total_reports int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (p.email)
         p.email::text,
         r.created_at,
         r.irr_pct,
         r.moic,
         r.status,
         (SELECT COUNT(*)::int FROM public.investor_performance_reports_r1749 r2 WHERE r2.investor_id = r.investor_id)
  FROM public.investor_performance_reports_r1749 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY p.email, r.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reports_r1749() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.generate_report_r1749(uuid, date, date, bigint, bigint, bigint, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_disputes_r1749() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_dispute_r1749(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_dispute_r1749(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.irr_leaderboard_r1749() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reports_per_investor_r1749() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reports_r1749() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_report_r1749(uuid, date, date, bigint, bigint, bigint, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_disputes_r1749() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_dispute_r1749(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_dispute_r1749(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.irr_leaderboard_r1749() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reports_per_investor_r1749() TO authenticated;

COMMIT;