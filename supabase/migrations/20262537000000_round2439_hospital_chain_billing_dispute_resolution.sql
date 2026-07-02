-- Round 2439: hospital-chain-billing-dispute-resolution
-- Two tables + 7 RPCs for tracking billing disputes from hospital chains
-- and the root-cause kill program that prevents recurrence.

BEGIN;

-- ============================================================================
-- TABLE 1: chain_billing_disputes_r2439
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chain_billing_disputes_r2439 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  dispute_external_ref text,
  raised_at timestamptz NOT NULL DEFAULT now(),
  dispute_kind text NOT NULL CHECK (dispute_kind IN ('invoice_amount','scope_dispute','calibration_dispute','extra_charge','sla_breach_credit','duplicate_charge')),
  disputed_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (disputed_amount_rupees >= 0),
  refund_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (refund_amount_rupees >= 0),
  root_cause_kind text CHECK (root_cause_kind IN ('process','billing_system','communication','scope_change','policy','people')),
  resolution_status text NOT NULL DEFAULT 'open' CHECK (resolution_status IN ('open','investigating','agreed','refunded','escalated','dropped')),
  resolved_at timestamptz,
  days_to_resolve int CHECK (days_to_resolve IS NULL OR days_to_resolve >= 0),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_billing_disputes_r2439_chain ON public.chain_billing_disputes_r2439(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_billing_disputes_r2439_status ON public.chain_billing_disputes_r2439(resolution_status);
CREATE INDEX IF NOT EXISTS idx_chain_billing_disputes_r2439_raised ON public.chain_billing_disputes_r2439(raised_at DESC);
CREATE INDEX IF NOT EXISTS idx_chain_billing_disputes_r2439_root ON public.chain_billing_disputes_r2439(root_cause_kind);

ALTER TABLE public.chain_billing_disputes_r2439 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_billing_disputes_r2439;
CREATE POLICY founder_all ON public.chain_billing_disputes_r2439
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: billing_dispute_root_cause_kills_r2439
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.billing_dispute_root_cause_kills_r2439 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start date NOT NULL,
  period_end date NOT NULL,
  root_cause_kind text NOT NULL CHECK (root_cause_kind IN ('process','billing_system','communication','scope_change','policy','people')),
  dispute_count int NOT NULL DEFAULT 0 CHECK (dispute_count >= 0),
  total_refund_rupees bigint NOT NULL DEFAULT 0 CHECK (total_refund_rupees >= 0),
  kill_status text NOT NULL DEFAULT 'planned' CHECK (kill_status IN ('planned','in_progress','done','dropped')),
  kill_action_md text,
  kill_owner_email text,
  kill_due_at timestamptz,
  kill_closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (period_end >= period_start)
);

CREATE INDEX IF NOT EXISTS idx_billing_dispute_root_cause_kills_r2439_status ON public.billing_dispute_root_cause_kills_r2439(kill_status);
CREATE INDEX IF NOT EXISTS idx_billing_dispute_root_cause_kills_r2439_root ON public.billing_dispute_root_cause_kills_r2439(root_cause_kind);
CREATE INDEX IF NOT EXISTS idx_billing_dispute_root_cause_kills_r2439_period ON public.billing_dispute_root_cause_kills_r2439(period_start DESC);

ALTER TABLE public.billing_dispute_root_cause_kills_r2439 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.billing_dispute_root_cause_kills_r2439;
CREATE POLICY founder_all ON public.billing_dispute_root_cause_kills_r2439
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_disputes_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_disputes_r2439();
CREATE OR REPLACE FUNCTION public.list_disputes_r2439()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  dispute_external_ref text,
  raised_at timestamptz,
  dispute_kind text,
  disputed_amount_rupees bigint,
  refund_amount_rupees bigint,
  root_cause_kind text,
  resolution_status text,
  resolved_at timestamptz,
  days_to_resolve int,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.chain_name, d.hospital_user_id, d.dispute_external_ref, d.raised_at,
           d.dispute_kind, d.disputed_amount_rupees, d.refund_amount_rupees,
           d.root_cause_kind, d.resolution_status, d.resolved_at, d.days_to_resolve,
           d.owner_email, d.notes, d.created_at
      FROM public.chain_billing_disputes_r2439 d
     ORDER BY d.raised_at DESC NULLS LAST, d.created_at DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_disputes_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_disputes_r2439() TO authenticated;

-- ============================================================================
-- RPC 2: list_root_cause_kills_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_root_cause_kills_r2439();
CREATE OR REPLACE FUNCTION public.list_root_cause_kills_r2439()
RETURNS TABLE (
  id uuid,
  period_start date,
  period_end date,
  root_cause_kind text,
  dispute_count int,
  total_refund_rupees bigint,
  kill_status text,
  kill_action_md text,
  kill_owner_email text,
  kill_due_at timestamptz,
  kill_closed_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT k.id, k.period_start, k.period_end, k.root_cause_kind, k.dispute_count,
           k.total_refund_rupees, k.kill_status, k.kill_action_md, k.kill_owner_email,
           k.kill_due_at, k.kill_closed_at, k.notes, k.created_at
      FROM public.billing_dispute_root_cause_kills_r2439 k
     ORDER BY k.period_start DESC, k.root_cause_kind;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_root_cause_kills_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_root_cause_kills_r2439() TO authenticated;

-- ============================================================================
-- RPC 3: top_dispute_chains_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_dispute_chains_r2439();
CREATE OR REPLACE FUNCTION public.top_dispute_chains_r2439()
RETURNS TABLE (
  chain_name text,
  dispute_count bigint,
  total_disputed_rupees bigint,
  total_refunded_rupees bigint,
  open_count bigint,
  escalated_count bigint,
  avg_days_to_resolve numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.chain_name,
           count(*)::bigint AS dispute_count,
           coalesce(sum(d.disputed_amount_rupees),0)::bigint AS total_disputed_rupees,
           coalesce(sum(d.refund_amount_rupees),0)::bigint AS total_refunded_rupees,
           count(*) FILTER (WHERE d.resolution_status IN ('open','investigating'))::bigint AS open_count,
           count(*) FILTER (WHERE d.resolution_status = 'escalated')::bigint AS escalated_count,
           round(avg(d.days_to_resolve)::numeric, 1) AS avg_days_to_resolve
      FROM public.chain_billing_disputes_r2439 d
     GROUP BY d.chain_name
     ORDER BY total_disputed_rupees DESC NULLS LAST, dispute_count DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_dispute_chains_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_dispute_chains_r2439() TO authenticated;

-- ============================================================================
-- RPC 4: root_cause_breakdown_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.root_cause_breakdown_r2439();
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2439()
RETURNS TABLE (
  root_cause_kind text,
  dispute_count bigint,
  total_disputed_rupees bigint,
  total_refunded_rupees bigint,
  kill_planned bigint,
  kill_in_progress bigint,
  kill_done bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT coalesce(d.root_cause_kind, 'unclassified') AS root_cause_kind,
           count(d.*)::bigint AS dispute_count,
           coalesce(sum(d.disputed_amount_rupees),0)::bigint AS total_disputed_rupees,
           coalesce(sum(d.refund_amount_rupees),0)::bigint AS total_refunded_rupees,
           coalesce((SELECT count(*) FROM public.billing_dispute_root_cause_kills_r2439 k WHERE k.root_cause_kind = d.root_cause_kind AND k.kill_status='planned'),0)::bigint AS kill_planned,
           coalesce((SELECT count(*) FROM public.billing_dispute_root_cause_kills_r2439 k WHERE k.root_cause_kind = d.root_cause_kind AND k.kill_status='in_progress'),0)::bigint AS kill_in_progress,
           coalesce((SELECT count(*) FROM public.billing_dispute_root_cause_kills_r2439 k WHERE k.root_cause_kind = d.root_cause_kind AND k.kill_status='done'),0)::bigint AS kill_done
      FROM public.chain_billing_disputes_r2439 d
     GROUP BY d.root_cause_kind
     ORDER BY dispute_count DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.root_cause_breakdown_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_breakdown_r2439() TO authenticated;

-- ============================================================================
-- RPC 5: monthly_refund_trend_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.monthly_refund_trend_r2439();
CREATE OR REPLACE FUNCTION public.monthly_refund_trend_r2439()
RETURNS TABLE (
  month_start date,
  dispute_count bigint,
  total_disputed_rupees bigint,
  total_refunded_rupees bigint,
  refund_ratio numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', d.raised_at)::date AS month_start,
           count(*)::bigint AS dispute_count,
           coalesce(sum(d.disputed_amount_rupees),0)::bigint AS total_disputed_rupees,
           coalesce(sum(d.refund_amount_rupees),0)::bigint AS total_refunded_rupees,
           CASE WHEN coalesce(sum(d.disputed_amount_rupees),0) = 0 THEN 0::numeric
                ELSE round((sum(d.refund_amount_rupees)::numeric / sum(d.disputed_amount_rupees)::numeric) * 100, 1)
           END AS refund_ratio
      FROM public.chain_billing_disputes_r2439 d
     GROUP BY date_trunc('month', d.raised_at)
     ORDER BY month_start DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_refund_trend_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_refund_trend_r2439() TO authenticated;

-- ============================================================================
-- RPC 6: resolution_velocity_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.resolution_velocity_r2439();
CREATE OR REPLACE FUNCTION public.resolution_velocity_r2439()
RETURNS TABLE (
  resolution_status text,
  dispute_count bigint,
  avg_days_to_resolve numeric,
  median_days_to_resolve numeric,
  max_days_to_resolve int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.resolution_status,
           count(*)::bigint AS dispute_count,
           round(avg(d.days_to_resolve)::numeric, 1) AS avg_days_to_resolve,
           round((percentile_cont(0.5) WITHIN GROUP (ORDER BY d.days_to_resolve))::numeric, 1) AS median_days_to_resolve,
           max(d.days_to_resolve) AS max_days_to_resolve
      FROM public.chain_billing_disputes_r2439 d
     GROUP BY d.resolution_status
     ORDER BY dispute_count DESC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.resolution_velocity_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolution_velocity_r2439() TO authenticated;

-- ============================================================================
-- RPC 7: open_critical_focus_r2439
-- ============================================================================
DROP FUNCTION IF EXISTS public.open_critical_focus_r2439();
CREATE OR REPLACE FUNCTION public.open_critical_focus_r2439()
RETURNS TABLE (
  id uuid,
  chain_name text,
  dispute_kind text,
  disputed_amount_rupees bigint,
  raised_at timestamptz,
  days_open int,
  resolution_status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.chain_name, d.dispute_kind, d.disputed_amount_rupees, d.raised_at,
           greatest(0, extract(day FROM (now() - d.raised_at))::int) AS days_open,
           d.resolution_status, d.owner_email
      FROM public.chain_billing_disputes_r2439 d
     WHERE d.resolution_status IN ('open','investigating','escalated')
     ORDER BY d.disputed_amount_rupees DESC NULLS LAST, d.raised_at ASC;
END
$$;
REVOKE EXECUTE ON FUNCTION public.open_critical_focus_r2439() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_critical_focus_r2439() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.chain_billing_disputes_r2439
  (chain_name, dispute_external_ref, raised_at, dispute_kind, disputed_amount_rupees, refund_amount_rupees, root_cause_kind, resolution_status, resolved_at, days_to_resolve, owner_email, notes)
VALUES
  ('Apollo Hospitals', 'APL-DIS-2026-041', now() - interval '28 days', 'invoice_amount', 145000, 18000, 'billing_system', 'refunded', now() - interval '14 days', 14, 'finance-ops@equipseva.in', 'Tax rounding mismatch on consolidated invoice'),
  ('Manipal Hospitals', 'MNP-DIS-2026-019', now() - interval '12 days', 'scope_dispute', 87000, 0, 'scope_change', 'investigating', null, null, 'cs-lead@equipseva.in', 'Customer claims preventive maintenance not in scope'),
  ('Fortis Healthcare', 'FRT-DIS-2026-007', now() - interval '6 days', 'duplicate_charge', 32000, 32000, 'billing_system', 'refunded', now() - interval '2 days', 4, 'finance-ops@equipseva.in', 'Same RJ billed in two cycles, auto-credited'),
  ('Yashoda Hospitals', 'YSH-DIS-2026-003', now() - interval '3 days', 'sla_breach_credit', 22500, 0, 'process', 'open', null, null, 'founder@equipseva.in', '48h SLA missed on calibration; credit owed'),
  ('Care Hospitals', 'CRE-DIS-2026-011', now() - interval '45 days', 'extra_charge', 56000, 0, 'communication', 'dropped', now() - interval '20 days', 25, 'cs-lead@equipseva.in', 'Customer accepted explanation; no refund');

INSERT INTO public.billing_dispute_root_cause_kills_r2439
  (period_start, period_end, root_cause_kind, dispute_count, total_refund_rupees, kill_status, kill_action_md, kill_owner_email, kill_due_at, kill_closed_at, notes)
VALUES
  ((now() - interval '60 days')::date, now()::date, 'billing_system', 8, 120000, 'in_progress', '- Add invoice line-item dedupe check in nightly billing job\n- Tax rounding fix in invoice formatter', 'eng-lead@equipseva.in', now() + interval '14 days', null, 'Two refunds last month traced to same dedupe gap'),
  ((now() - interval '60 days')::date, now()::date, 'scope_change', 4, 0, 'planned', '- Publish AMC scope one-pager and embed in quote PDF\n- Require chain signoff on scope checklist before activation', 'founder@equipseva.in', now() + interval '21 days', null, 'Repeated scope disputes from Manipal + Fortis'),
  ((now() - interval '90 days')::date, (now() - interval '30 days')::date, 'process', 6, 45000, 'done', '- Automated SLA breach credit workflow\n- Engineer dispatch ETA shown to hospital admin', 'ops@equipseva.in', now() - interval '20 days', now() - interval '15 days', 'Closed; SLA-breach disputes now auto-credit'),
  ((now() - interval '30 days')::date, now()::date, 'communication', 3, 0, 'planned', '- Monthly statement clarity rewrite\n- Pre-billing courtesy call to top 10 chains', 'cs-lead@equipseva.in', now() + interval '30 days', null, 'Most disputes here closed without refund but burn cycle time');

