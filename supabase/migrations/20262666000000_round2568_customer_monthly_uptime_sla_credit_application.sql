-- Round 2568: Customer monthly uptime SLA credit application
-- Tables: customer_monthly_uptime_credits_r2568, uptime_credit_payment_log_r2568
-- 7 RPCs for credit listing, payment log, top hospitals, status funnel, monthly trend, action kind, total owed

BEGIN;

-- ============================================================
-- TABLE 1: customer_monthly_uptime_credits_r2568
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_monthly_uptime_credits_r2568 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  month_label text NOT NULL,
  actual_uptime_pct numeric NOT NULL CHECK (actual_uptime_pct >= 0 AND actual_uptime_pct <= 100),
  sla_target_pct numeric NOT NULL CHECK (sla_target_pct >= 0 AND sla_target_pct <= 100),
  breach_minutes int NOT NULL DEFAULT 0 CHECK (breach_minutes >= 0),
  credit_owed_rupees bigint NOT NULL DEFAULT 0 CHECK (credit_owed_rupees >= 0),
  credit_applied_rupees bigint NOT NULL DEFAULT 0 CHECK (credit_applied_rupees >= 0),
  credit_paid_rupees bigint NOT NULL DEFAULT 0 CHECK (credit_paid_rupees >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','applied','paid','disputed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_monthly_uptime_credits_r2568 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_monthly_uptime_credits_r2568;
CREATE POLICY founder_all ON public.customer_monthly_uptime_credits_r2568
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: uptime_credit_payment_log_r2568
-- ============================================================
CREATE TABLE IF NOT EXISTS public.uptime_credit_payment_log_r2568 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  credit_id uuid NOT NULL REFERENCES public.customer_monthly_uptime_credits_r2568(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('invoice_credit','cash_refund','next_month_offset','written_off')),
  action_summary text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.uptime_credit_payment_log_r2568 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.uptime_credit_payment_log_r2568;
CREATE POLICY founder_all ON public.uptime_credit_payment_log_r2568
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.customer_monthly_uptime_credits_r2568
  (month_label, actual_uptime_pct, sla_target_pct, breach_minutes, credit_owed_rupees, credit_applied_rupees, credit_paid_rupees, owner_email, status, notes)
VALUES
  ('2026-05', 98.20, 99.50, 580, 24000, 24000, 24000, 'ops@equipseva.in', 'paid', 'Apollo - CT scanner extended downtime'),
  ('2026-05', 99.10, 99.50, 175, 8500, 8500, 0, 'ops@equipseva.in', 'applied', 'Yashoda - applied as next-month credit'),
  ('2026-06', 97.40, 99.50, 920, 42000, 0, 0, 'ops@equipseva.in', 'pending', 'Kims - awaiting hospital sign-off'),
  ('2026-06', 99.65, 99.50, 0, 0, 0, 0, 'ops@equipseva.in', 'dropped', 'KIMS-2 - met SLA, no credit'),
  ('2026-04', 98.80, 99.50, 360, 16500, 16500, 16500, 'ops@equipseva.in', 'paid', 'Continental - resolved');

WITH c AS (
  SELECT id FROM public.customer_monthly_uptime_credits_r2568 WHERE month_label = '2026-05' AND credit_paid_rupees = 24000 LIMIT 1
)
INSERT INTO public.uptime_credit_payment_log_r2568 (credit_id, action_kind, action_summary, owner_email, status, notes)
SELECT c.id, 'cash_refund', 'Cashfree payout Rs 24,000 to Apollo', 'ops@equipseva.in', 'done', 'UTR confirmed' FROM c;

WITH c AS (
  SELECT id FROM public.customer_monthly_uptime_credits_r2568 WHERE month_label = '2026-05' AND credit_paid_rupees = 0 AND status = 'applied' LIMIT 1
)
INSERT INTO public.uptime_credit_payment_log_r2568 (credit_id, action_kind, action_summary, owner_email, status, notes)
SELECT c.id, 'next_month_offset', 'Offset against June AMC invoice', 'ops@equipseva.in', 'done', 'Hospital agreed' FROM c;

WITH c AS (
  SELECT id FROM public.customer_monthly_uptime_credits_r2568 WHERE month_label = '2026-06' AND status = 'pending' LIMIT 1
)
INSERT INTO public.uptime_credit_payment_log_r2568 (credit_id, action_kind, action_summary, owner_email, status, notes)
SELECT c.id, 'invoice_credit', 'Draft invoice credit memo prepared', 'ops@equipseva.in', 'open', 'Awaiting sign-off' FROM c;

WITH c AS (
  SELECT id FROM public.customer_monthly_uptime_credits_r2568 WHERE month_label = '2026-04' LIMIT 1
)
INSERT INTO public.uptime_credit_payment_log_r2568 (credit_id, action_kind, action_summary, owner_email, status, notes)
SELECT c.id, 'cash_refund', 'Continental refunded Rs 16,500', 'ops@equipseva.in', 'done', 'Closed cleanly' FROM c;

-- ============================================================
-- RPC 1: list_credits_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_credits_r2568()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  month_label text,
  actual_uptime_pct numeric,
  sla_target_pct numeric,
  breach_minutes int,
  credit_owed_rupees bigint,
  credit_applied_rupees bigint,
  credit_paid_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.hospital_user_id, p.email AS hospital_email,
           c.month_label, c.actual_uptime_pct, c.sla_target_pct,
           c.breach_minutes, c.credit_owed_rupees, c.credit_applied_rupees,
           c.credit_paid_rupees, c.owner_email, c.status, c.notes, c.created_at
    FROM public.customer_monthly_uptime_credits_r2568 c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    ORDER BY c.month_label DESC, c.credit_owed_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_credits_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_credits_r2568() TO authenticated;

-- ============================================================
-- RPC 2: list_payment_log_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_payment_log_r2568()
RETURNS TABLE (
  id uuid,
  credit_id uuid,
  month_label text,
  hospital_email text,
  action_at timestamptz,
  action_kind text,
  action_summary text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.credit_id, c.month_label, p.email AS hospital_email,
           l.action_at, l.action_kind, l.action_summary,
           l.owner_email, l.status, l.notes
    FROM public.uptime_credit_payment_log_r2568 l
    JOIN public.customer_monthly_uptime_credits_r2568 c ON c.id = l.credit_id
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    ORDER BY l.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_payment_log_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_payment_log_r2568() TO authenticated;

-- ============================================================
-- RPC 3: top_credit_hospitals_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_credit_hospitals_r2568()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  credit_count bigint,
  total_owed_rupees bigint,
  total_paid_rupees bigint,
  avg_uptime_pct numeric,
  total_breach_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.hospital_user_id,
           p.email AS hospital_email,
           COUNT(*)::bigint AS credit_count,
           SUM(c.credit_owed_rupees)::bigint AS total_owed_rupees,
           SUM(c.credit_paid_rupees)::bigint AS total_paid_rupees,
           ROUND(AVG(c.actual_uptime_pct)::numeric, 2) AS avg_uptime_pct,
           SUM(c.breach_minutes)::bigint AS total_breach_minutes
    FROM public.customer_monthly_uptime_credits_r2568 c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    GROUP BY c.hospital_user_id, p.email
    ORDER BY total_owed_rupees DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_credit_hospitals_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_credit_hospitals_r2568() TO authenticated;

-- ============================================================
-- RPC 4: status_funnel_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2568()
RETURNS TABLE (
  status text,
  cnt bigint,
  total_owed_rupees bigint,
  total_paid_rupees bigint,
  avg_breach_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.status,
           COUNT(*)::bigint AS cnt,
           SUM(c.credit_owed_rupees)::bigint AS total_owed_rupees,
           SUM(c.credit_paid_rupees)::bigint AS total_paid_rupees,
           ROUND(AVG(c.breach_minutes)::numeric, 1) AS avg_breach_minutes
    FROM public.customer_monthly_uptime_credits_r2568 c
    GROUP BY c.status
    ORDER BY cnt DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2568() TO authenticated;

-- ============================================================
-- RPC 5: monthly_credit_trend_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_credit_trend_r2568()
RETURNS TABLE (
  month_label text,
  credit_count bigint,
  total_owed_rupees bigint,
  total_applied_rupees bigint,
  total_paid_rupees bigint,
  avg_uptime_pct numeric,
  total_breach_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.month_label,
           COUNT(*)::bigint AS credit_count,
           SUM(c.credit_owed_rupees)::bigint AS total_owed_rupees,
           SUM(c.credit_applied_rupees)::bigint AS total_applied_rupees,
           SUM(c.credit_paid_rupees)::bigint AS total_paid_rupees,
           ROUND(AVG(c.actual_uptime_pct)::numeric, 2) AS avg_uptime_pct,
           SUM(c.breach_minutes)::bigint AS total_breach_minutes
    FROM public.customer_monthly_uptime_credits_r2568 c
    GROUP BY c.month_label
    ORDER BY c.month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_credit_trend_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_credit_trend_r2568() TO authenticated;

-- ============================================================
-- RPC 6: action_kind_summary_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.action_kind_summary_r2568()
RETURNS TABLE (
  action_kind text,
  cnt bigint,
  done_count bigint,
  open_count bigint,
  dropped_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.action_kind,
           COUNT(*)::bigint AS cnt,
           COUNT(*) FILTER (WHERE l.status = 'done')::bigint AS done_count,
           COUNT(*) FILTER (WHERE l.status = 'open')::bigint AS open_count,
           COUNT(*) FILTER (WHERE l.status = 'dropped')::bigint AS dropped_count
    FROM public.uptime_credit_payment_log_r2568 l
    GROUP BY l.action_kind
    ORDER BY cnt DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_summary_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_summary_r2568() TO authenticated;

-- ============================================================
-- RPC 7: total_owed_summary_r2568
-- ============================================================
CREATE OR REPLACE FUNCTION public.total_owed_summary_r2568()
RETURNS TABLE (
  total_credits bigint,
  total_owed_rupees bigint,
  total_applied_rupees bigint,
  total_paid_rupees bigint,
  outstanding_rupees bigint,
  pending_count bigint,
  paid_count bigint,
  disputed_count bigint,
  avg_uptime_pct numeric,
  total_breach_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COUNT(*)::bigint AS total_credits,
      SUM(c.credit_owed_rupees)::bigint AS total_owed_rupees,
      SUM(c.credit_applied_rupees)::bigint AS total_applied_rupees,
      SUM(c.credit_paid_rupees)::bigint AS total_paid_rupees,
      (COALESCE(SUM(c.credit_owed_rupees), 0) - COALESCE(SUM(c.credit_paid_rupees), 0))::bigint AS outstanding_rupees,
      COUNT(*) FILTER (WHERE c.status = 'pending')::bigint AS pending_count,
      COUNT(*) FILTER (WHERE c.status = 'paid')::bigint AS paid_count,
      COUNT(*) FILTER (WHERE c.status = 'disputed')::bigint AS disputed_count,
      ROUND(AVG(c.actual_uptime_pct)::numeric, 2) AS avg_uptime_pct,
      SUM(c.breach_minutes)::bigint AS total_breach_minutes
    FROM public.customer_monthly_uptime_credits_r2568 c;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_owed_summary_r2568() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_owed_summary_r2568() TO authenticated;

