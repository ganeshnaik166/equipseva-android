-- Round 2422 — Engineer Incentive Leakage Detector
-- Track per-cycle incentive earned vs paid, surface leakage, and drive audit closure.

BEGIN;

-- ============================================================================
-- TABLE: engineer_incentive_payouts_r2422
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_incentive_payouts_r2422 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  pay_cycle_start date NOT NULL,
  pay_cycle_end date NOT NULL,
  incentive_kind text NOT NULL CHECK (incentive_kind IN ('amc_signup','cross_sell','upsell','csat_bonus','referral','code_red')),
  earned_rupees integer NOT NULL DEFAULT 0 CHECK (earned_rupees >= 0),
  paid_rupees integer NOT NULL DEFAULT 0 CHECK (paid_rupees >= 0),
  delta_rupees integer NOT NULL DEFAULT 0,
  leakage_reason text NOT NULL DEFAULT 'none' CHECK (leakage_reason IN ('none','wrong_kpi','calc_error','duplicate','manual_override','missing_signoff')),
  reason_notes text,
  paid_at timestamptz,
  paid_by_email text,
  notes text,
  CHECK (pay_cycle_end >= pay_cycle_start)
);

ALTER TABLE public.engineer_incentive_payouts_r2422 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.engineer_incentive_payouts_r2422
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: incentive_leakage_audit_r2422
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.incentive_leakage_audit_r2422 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_period_start date NOT NULL,
  audit_period_end date NOT NULL,
  total_earned_rupees bigint NOT NULL DEFAULT 0 CHECK (total_earned_rupees >= 0),
  total_paid_rupees bigint NOT NULL DEFAULT 0 CHECK (total_paid_rupees >= 0),
  total_leakage_rupees bigint NOT NULL DEFAULT 0,
  leakage_pct numeric NOT NULL DEFAULT 0,
  top_leakage_kind text,
  top_leakage_reason text,
  action_taken text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  notes text,
  CHECK (audit_period_end >= audit_period_start)
);

ALTER TABLE public.incentive_leakage_audit_r2422 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.incentive_leakage_audit_r2422
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_payouts_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_payouts_r2422()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  pay_cycle_start date,
  pay_cycle_end date,
  incentive_kind text,
  earned_rupees integer,
  paid_rupees integer,
  delta_rupees integer,
  leakage_reason text,
  reason_notes text,
  paid_at timestamptz,
  paid_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_user_id, p.pay_cycle_start, p.pay_cycle_end,
           p.incentive_kind, p.earned_rupees, p.paid_rupees, p.delta_rupees,
           p.leakage_reason, p.reason_notes, p.paid_at, p.paid_by_email, p.notes
      FROM public.engineer_incentive_payouts_r2422 p
      ORDER BY p.pay_cycle_end DESC, p.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_payouts_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_payouts_r2422() TO authenticated;

-- ============================================================================
-- RPC: list_audits_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_audits_r2422()
RETURNS TABLE (
  id uuid,
  audit_period_start date,
  audit_period_end date,
  total_earned_rupees bigint,
  total_paid_rupees bigint,
  total_leakage_rupees bigint,
  leakage_pct numeric,
  top_leakage_kind text,
  top_leakage_reason text,
  action_taken text,
  status text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.audit_period_start, a.audit_period_end,
           a.total_earned_rupees, a.total_paid_rupees, a.total_leakage_rupees,
           a.leakage_pct, a.top_leakage_kind, a.top_leakage_reason,
           a.action_taken, a.status, a.closed_at, a.closed_by_email, a.notes
      FROM public.incentive_leakage_audit_r2422 a
      ORDER BY a.audit_period_end DESC, a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_audits_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2422() TO authenticated;

-- ============================================================================
-- RPC: top_leakage_engineers_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_leakage_engineers_r2422()
RETURNS TABLE (
  engineer_user_id uuid,
  payout_count bigint,
  total_earned_rupees bigint,
  total_paid_rupees bigint,
  total_leakage_rupees bigint,
  leakage_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.engineer_user_id,
           COUNT(*)::bigint AS payout_count,
           COALESCE(SUM(p.earned_rupees),0)::bigint AS total_earned_rupees,
           COALESCE(SUM(p.paid_rupees),0)::bigint AS total_paid_rupees,
           COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::bigint AS total_leakage_rupees,
           CASE WHEN COALESCE(SUM(p.earned_rupees),0) > 0
                THEN ROUND((COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::numeric / SUM(p.earned_rupees)::numeric) * 100, 2)
                ELSE 0::numeric END AS leakage_pct
      FROM public.engineer_incentive_payouts_r2422 p
     GROUP BY p.engineer_user_id
     ORDER BY total_leakage_rupees DESC
     LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_leakage_engineers_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_leakage_engineers_r2422() TO authenticated;

-- ============================================================================
-- RPC: leakage_by_kind_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.leakage_by_kind_r2422()
RETURNS TABLE (
  incentive_kind text,
  payout_count bigint,
  total_earned_rupees bigint,
  total_paid_rupees bigint,
  total_leakage_rupees bigint,
  leakage_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.incentive_kind,
           COUNT(*)::bigint AS payout_count,
           COALESCE(SUM(p.earned_rupees),0)::bigint AS total_earned_rupees,
           COALESCE(SUM(p.paid_rupees),0)::bigint AS total_paid_rupees,
           COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::bigint AS total_leakage_rupees,
           CASE WHEN COALESCE(SUM(p.earned_rupees),0) > 0
                THEN ROUND((COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::numeric / SUM(p.earned_rupees)::numeric) * 100, 2)
                ELSE 0::numeric END AS leakage_pct
      FROM public.engineer_incentive_payouts_r2422 p
     GROUP BY p.incentive_kind
     ORDER BY total_leakage_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.leakage_by_kind_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leakage_by_kind_r2422() TO authenticated;

-- ============================================================================
-- RPC: leakage_by_reason_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.leakage_by_reason_r2422()
RETURNS TABLE (
  leakage_reason text,
  payout_count bigint,
  total_leakage_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.leakage_reason,
           COUNT(*)::bigint AS payout_count,
           COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::bigint AS total_leakage_rupees
      FROM public.engineer_incentive_payouts_r2422 p
     GROUP BY p.leakage_reason
     ORDER BY total_leakage_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.leakage_by_reason_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leakage_by_reason_r2422() TO authenticated;

-- ============================================================================
-- RPC: monthly_leakage_trend_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_leakage_trend_r2422()
RETURNS TABLE (
  month_start date,
  payout_count bigint,
  total_earned_rupees bigint,
  total_paid_rupees bigint,
  total_leakage_rupees bigint,
  leakage_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', p.pay_cycle_end)::date AS month_start,
           COUNT(*)::bigint AS payout_count,
           COALESCE(SUM(p.earned_rupees),0)::bigint AS total_earned_rupees,
           COALESCE(SUM(p.paid_rupees),0)::bigint AS total_paid_rupees,
           COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::bigint AS total_leakage_rupees,
           CASE WHEN COALESCE(SUM(p.earned_rupees),0) > 0
                THEN ROUND((COALESCE(SUM(p.earned_rupees - p.paid_rupees),0)::numeric / SUM(p.earned_rupees)::numeric) * 100, 2)
                ELSE 0::numeric END AS leakage_pct
      FROM public.engineer_incentive_payouts_r2422 p
     GROUP BY date_trunc('month', p.pay_cycle_end)::date
     ORDER BY month_start DESC
     LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_leakage_trend_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_leakage_trend_r2422() TO authenticated;

-- ============================================================================
-- RPC: action_items_r2422
-- ============================================================================
CREATE OR REPLACE FUNCTION public.action_items_r2422()
RETURNS TABLE (
  id uuid,
  audit_period_start date,
  audit_period_end date,
  total_leakage_rupees bigint,
  leakage_pct numeric,
  top_leakage_kind text,
  top_leakage_reason text,
  action_taken text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.audit_period_start, a.audit_period_end,
           a.total_leakage_rupees, a.leakage_pct,
           a.top_leakage_kind, a.top_leakage_reason,
           a.action_taken, a.status, a.notes
      FROM public.incentive_leakage_audit_r2422 a
     WHERE a.status IN ('open','in_progress')
     ORDER BY a.total_leakage_rupees DESC, a.audit_period_end DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_items_r2422() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_items_r2422() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.engineer_incentive_payouts_r2422 (pay_cycle_start, pay_cycle_end, incentive_kind, earned_rupees, paid_rupees, delta_rupees, leakage_reason, reason_notes, paid_at, paid_by_email, notes)
VALUES
  ('2026-05-01','2026-05-31','amc_signup', 18000, 15000, 3000, 'calc_error','Slab 3 misapplied; recompute', now() - interval '20 days', 'finance@equipseva.in','Engineer A May cycle'),
  ('2026-05-01','2026-05-31','cross_sell', 12000, 12000, 0, 'none', null, now() - interval '20 days', 'finance@equipseva.in','Engineer B May cycle clean'),
  ('2026-05-01','2026-05-31','csat_bonus', 8000, 0, 8000, 'missing_signoff','Hospital signoff pending', null, null,'Engineer C May cycle held'),
  ('2026-04-01','2026-04-30','referral', 5000, 2500, 2500, 'duplicate','Same lead claimed twice', now() - interval '50 days', 'finance@equipseva.in','Engineer A Apr cycle'),
  ('2026-04-01','2026-04-30','code_red', 20000, 18000, 2000, 'manual_override','Founder override -10pct', now() - interval '50 days', 'finance@equipseva.in','Engineer D Apr cycle');

INSERT INTO public.incentive_leakage_audit_r2422 (audit_period_start, audit_period_end, total_earned_rupees, total_paid_rupees, total_leakage_rupees, leakage_pct, top_leakage_kind, top_leakage_reason, action_taken, status, closed_at, closed_by_email, notes)
VALUES
  ('2026-05-01','2026-05-31', 38000, 27000, 11000, 28.95, 'csat_bonus','missing_signoff','Chase 3 hospital signoffs by Fri','open', null, null,'May audit open'),
  ('2026-04-01','2026-04-30', 25000, 20500, 4500, 18.00, 'referral','duplicate','Dedup script deployed', 'resolved', now() - interval '40 days','founder@equipseva.in','Apr audit closed'),
  ('2026-03-01','2026-03-31', 42000, 39000, 3000, 7.14, 'amc_signup','calc_error','Slab table corrected', 'resolved', now() - interval '70 days','founder@equipseva.in','Mar audit closed');

