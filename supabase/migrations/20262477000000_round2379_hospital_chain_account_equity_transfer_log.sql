BEGIN;

-- ============================================================================
-- Round 2379: Hospital chain account-equity transfer log
-- Track ownership transfers between team members + KT checklist + completion %
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.account_equity_transfers_r2379 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  from_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  to_owner_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  from_owner_email text,
  to_owner_email text,
  transfer_reason text NOT NULL CHECK (transfer_reason IN ('promotion','attrition','reorg','geo_realignment','escalation','workload_balance','other')),
  account_arr_rupees bigint NOT NULL DEFAULT 0,
  account_tier text CHECK (account_tier IN ('strategic','enterprise','mid_market','smb')),
  hospitals_in_chain integer DEFAULT 0,
  amc_contracts_count integer DEFAULT 0,
  transfer_initiated_at timestamptz NOT NULL DEFAULT now(),
  transfer_completed_at timestamptz,
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed','aborted','at_risk')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aet_r2379_status ON public.account_equity_transfers_r2379(status);
CREATE INDEX IF NOT EXISTS idx_aet_r2379_initiated ON public.account_equity_transfers_r2379(transfer_initiated_at DESC);
CREATE INDEX IF NOT EXISTS idx_aet_r2379_chain ON public.account_equity_transfers_r2379(chain_name);

ALTER TABLE public.account_equity_transfers_r2379 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.account_equity_transfers_r2379;
CREATE POLICY founder_all ON public.account_equity_transfers_r2379
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
-- KT checklist items (per transfer)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.account_equity_kt_items_r2379 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL REFERENCES public.account_equity_transfers_r2379(id) ON DELETE CASCADE,
  item_category text NOT NULL CHECK (item_category IN ('relationship','commercial','operational','technical','contractual','political')),
  item_label text NOT NULL,
  is_critical boolean NOT NULL DEFAULT false,
  is_completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  completed_by_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  evidence_url text,
  sequence_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aet_kt_r2379_transfer ON public.account_equity_kt_items_r2379(transfer_id);
CREATE INDEX IF NOT EXISTS idx_aet_kt_r2379_done ON public.account_equity_kt_items_r2379(is_completed);

ALTER TABLE public.account_equity_kt_items_r2379 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.account_equity_kt_items_r2379;
CREATE POLICY founder_all ON public.account_equity_kt_items_r2379
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs (7) — all founder-gated
-- ============================================================================

-- 1. List transfers with completion %
CREATE OR REPLACE FUNCTION public.list_equity_transfers_r2379()
RETURNS TABLE (
  id uuid,
  chain_name text,
  from_owner_email text,
  to_owner_email text,
  transfer_reason text,
  account_arr_rupees bigint,
  account_tier text,
  hospitals_in_chain integer,
  amc_contracts_count integer,
  transfer_initiated_at timestamptz,
  transfer_completed_at timestamptz,
  status text,
  total_items integer,
  completed_items integer,
  completion_pct numeric,
  critical_open integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.chain_name,
    t.from_owner_email,
    t.to_owner_email,
    t.transfer_reason,
    t.account_arr_rupees,
    t.account_tier,
    t.hospitals_in_chain,
    t.amc_contracts_count,
    t.transfer_initiated_at,
    t.transfer_completed_at,
    t.status,
    COALESCE((SELECT COUNT(*)::int FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0) AS total_items,
    COALESCE((SELECT COUNT(*)::int FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_completed), 0) AS completed_items,
    CASE
      WHEN COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0) = 0 THEN 0
      ELSE ROUND(100.0 * (SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_completed)::numeric / NULLIF((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0), 1)
    END AS completion_pct,
    COALESCE((SELECT COUNT(*)::int FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_critical AND NOT k.is_completed), 0) AS critical_open
  FROM public.account_equity_transfers_r2379 t
  ORDER BY t.transfer_initiated_at DESC
  LIMIT 200;
END;
$$;

-- 2. KT checklist items for a transfer
CREATE OR REPLACE FUNCTION public.list_equity_kt_items_r2379(p_transfer uuid)
RETURNS TABLE (
  id uuid,
  item_category text,
  item_label text,
  is_critical boolean,
  is_completed boolean,
  completed_at timestamptz,
  sequence_order integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.item_category, k.item_label, k.is_critical, k.is_completed, k.completed_at, k.sequence_order
  FROM public.account_equity_kt_items_r2379 k
  WHERE k.transfer_id = p_transfer
  ORDER BY k.sequence_order ASC, k.is_critical DESC;
END;
$$;

-- 3. Summary metrics
CREATE OR REPLACE FUNCTION public.equity_transfer_summary_r2379()
RETURNS TABLE (
  in_progress_count integer,
  completed_count integer,
  at_risk_count integer,
  aborted_count integer,
  total_arr_under_transfer_rupees bigint,
  avg_completion_pct numeric,
  avg_days_to_complete numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT t.*,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0) AS tot,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_completed), 0) AS done
    FROM public.account_equity_transfers_r2379 t
  )
  SELECT
    COUNT(*) FILTER (WHERE status = 'in_progress')::int,
    COUNT(*) FILTER (WHERE status = 'completed')::int,
    COUNT(*) FILTER (WHERE status = 'at_risk')::int,
    COUNT(*) FILTER (WHERE status = 'aborted')::int,
    COALESCE(SUM(account_arr_rupees) FILTER (WHERE status IN ('in_progress','at_risk')), 0)::bigint,
    ROUND(AVG(CASE WHEN tot > 0 THEN 100.0 * done::numeric / tot ELSE 0 END), 1),
    ROUND(AVG(EXTRACT(EPOCH FROM (transfer_completed_at - transfer_initiated_at)) / 86400.0) FILTER (WHERE status = 'completed'), 1)
  FROM base;
END;
$$;

-- 4. Reason breakdown
CREATE OR REPLACE FUNCTION public.equity_transfer_by_reason_r2379()
RETURNS TABLE (
  transfer_reason text,
  transfer_count integer,
  total_arr_rupees bigint,
  avg_completion_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT t.transfer_reason, t.account_arr_rupees, t.id,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0) AS tot,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_completed), 0) AS done
    FROM public.account_equity_transfers_r2379 t
  )
  SELECT
    transfer_reason,
    COUNT(*)::int,
    COALESCE(SUM(account_arr_rupees), 0)::bigint,
    ROUND(AVG(CASE WHEN tot > 0 THEN 100.0 * done::numeric / tot ELSE 0 END), 1)
  FROM base
  GROUP BY transfer_reason
  ORDER BY COUNT(*) DESC;
END;
$$;

-- 5. At-risk transfers (low completion + aging)
CREATE OR REPLACE FUNCTION public.equity_transfer_at_risk_r2379()
RETURNS TABLE (
  id uuid,
  chain_name text,
  from_owner_email text,
  to_owner_email text,
  days_open integer,
  completion_pct numeric,
  critical_open integer,
  account_arr_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT t.*,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id), 0) AS tot,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_completed), 0) AS done,
      COALESCE((SELECT COUNT(*) FROM public.account_equity_kt_items_r2379 k WHERE k.transfer_id = t.id AND k.is_critical AND NOT k.is_completed), 0) AS crit_open
    FROM public.account_equity_transfers_r2379 t
    WHERE t.status IN ('in_progress','at_risk')
  )
  SELECT
    id,
    chain_name,
    from_owner_email,
    to_owner_email,
    EXTRACT(DAY FROM (now() - transfer_initiated_at))::int,
    CASE WHEN tot > 0 THEN ROUND(100.0 * done::numeric / tot, 1) ELSE 0 END,
    crit_open::int,
    account_arr_rupees
  FROM base
  WHERE (tot > 0 AND done::numeric / tot < 0.5 AND EXTRACT(DAY FROM (now() - transfer_initiated_at)) > 14)
     OR crit_open > 0
     OR status = 'at_risk'
  ORDER BY account_arr_rupees DESC
  LIMIT 50;
END;
$$;

-- 6. Owner load (transfers per owner)
CREATE OR REPLACE FUNCTION public.equity_transfer_owner_load_r2379()
RETURNS TABLE (
  owner_email text,
  incoming_count integer,
  outgoing_count integer,
  incoming_arr_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH unioned AS (
    SELECT to_owner_email AS owner_email, 'in' AS dir, account_arr_rupees FROM public.account_equity_transfers_r2379 WHERE to_owner_email IS NOT NULL
    UNION ALL
    SELECT from_owner_email AS owner_email, 'out' AS dir, account_arr_rupees FROM public.account_equity_transfers_r2379 WHERE from_owner_email IS NOT NULL
  )
  SELECT
    owner_email,
    COUNT(*) FILTER (WHERE dir = 'in')::int,
    COUNT(*) FILTER (WHERE dir = 'out')::int,
    COALESCE(SUM(account_arr_rupees) FILTER (WHERE dir = 'in'), 0)::bigint
  FROM unioned
  GROUP BY owner_email
  ORDER BY COUNT(*) FILTER (WHERE dir = 'in') DESC
  LIMIT 30;
END;
$$;

-- 7. Category completion across all transfers
CREATE OR REPLACE FUNCTION public.equity_kt_category_completion_r2379()
RETURNS TABLE (
  item_category text,
  total_items integer,
  completed_items integer,
  completion_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    item_category,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE is_completed)::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_completed)::numeric / NULLIF(COUNT(*), 0), 1)
  FROM public.account_equity_kt_items_r2379
  GROUP BY item_category
  ORDER BY item_category ASC;
END;
$$;

-- Grants
REVOKE ALL ON FUNCTION public.list_equity_transfers_r2379() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_equity_kt_items_r2379(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equity_transfer_summary_r2379() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equity_transfer_by_reason_r2379() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equity_transfer_at_risk_r2379() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equity_transfer_owner_load_r2379() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.equity_kt_category_completion_r2379() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_equity_transfers_r2379() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_equity_kt_items_r2379(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.equity_transfer_summary_r2379() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equity_transfer_by_reason_r2379() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equity_transfer_at_risk_r2379() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equity_transfer_owner_load_r2379() TO authenticated;
GRANT EXECUTE ON FUNCTION public.equity_kt_category_completion_r2379() TO authenticated;

COMMIT;
