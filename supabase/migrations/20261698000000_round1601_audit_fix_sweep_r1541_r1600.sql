-- r1601: audit-fix-sweep 4 over r1541-r1600 (9 raw → 7 confirmed, 3 CRITICAL + 2 HIGH + 2 LOW)
-- Audit workflow whx1m2ibx.
-- Cumulative across 4 audit-fix sweeps: 30 + 7 + 16 + 7 = 60 prod bugs caught pre-deploy.
BEGIN;

-- ============================================================
-- r1550 CRITICAL — amc_contracts.user_id doesn't exist (real col: hospital_user_id)
-- STUB the broken function
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='founder_transfer_capture_coverage'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_transfer_capture_coverage(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT from_city INTO v_from FROM public.engineer_transfer_requests WHERE id = p_request_id;
  IF v_from IS NULL THEN RETURN; END IF;
  INSERT INTO public.engineer_transfer_coverage_snapshots (request_id, captured_at, city, active_amc_in_city)
  SELECT p_request_id, now(), v_from,
    (SELECT count(*) FROM public.amc_contracts ac
     JOIN public.profiles p ON p.id = ac.hospital_user_id
     JOIN public.organizations o ON o.id = p.organization_id
     WHERE o.city = v_from AND ac.status = 'active');
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_transfer_capture_coverage(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_transfer_capture_coverage(uuid) TO authenticated;

-- ============================================================
-- r1572 HIGH — rpc_founder_cap_v3_current_table self-join inflates totals
-- STUB to return empty for now (proper fix needs full rewrite)
-- ============================================================
DROP FUNCTION IF EXISTS public.rpc_founder_cap_v3_current_table();
CREATE OR REPLACE FUNCTION public.rpc_founder_cap_v3_current_table()
RETURNS TABLE (shareholder_name text, shares_after bigint, pct_after numeric, total_cash_in_rupees bigint, total_cash_out_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_latest uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_latest FROM public.cap_table_v3_events ORDER BY event_at DESC LIMIT 1;
  IF v_latest IS NULL THEN RETURN; END IF;
  RETURN QUERY
  SELECT h.shareholder_name,
         h.shares_after,
         h.pct_after,
         COALESCE((SELECT SUM(c.cash_in_rupees) FROM public.cap_table_v3_holdings c WHERE c.shareholder_name = h.shareholder_name), 0)::bigint,
         COALESCE((SELECT SUM(c.cash_out_rupees) FROM public.cap_table_v3_holdings c WHERE c.shareholder_name = h.shareholder_name), 0)::bigint
  FROM public.cap_table_v3_holdings h
  WHERE h.event_id = v_latest
  ORDER BY h.shares_after DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_cap_v3_current_table() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_founder_cap_v3_current_table() TO authenticated;

-- ============================================================
-- r1584 CRITICAL — founder_action_log column refs wrong (l.ts → l.created_at, id bigint → id uuid)
-- ============================================================
DROP FUNCTION IF EXISTS public.rpc_founder_investor_action_log_recent();
CREATE OR REPLACE FUNCTION public.rpc_founder_investor_action_log_recent()
RETURNS TABLE (id uuid, ts timestamptz, actor_email text, op_name text, after_value jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.created_at, l.actor_email, l.op_name, l.after_value
  FROM public.founder_action_log l
  WHERE l.op_name LIKE 'investor%' OR l.op_name LIKE 'pipeline%' OR l.op_name LIKE 'triage%'
  ORDER BY l.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_investor_action_log_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_founder_investor_action_log_recent() TO authenticated;

-- ============================================================
-- r1594 HIGH — founder_promotion_review_scorecard cartesian product inflates payouts
-- STUB with proper CTE structure
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='founder_promotion_review_scorecard'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_promotion_review_scorecard()
RETURNS TABLE (engineer_id uuid, full_name text, jobs_last_90d bigint, avg_rating_last_90d numeric, disputes_last_90d bigint, payout_last_90d_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH job_agg AS (
    SELECT rj.engineer_id,
           count(*) FILTER (WHERE rj.completed_at >= now() - interval '90 days')::bigint AS jobs_count,
           avg(rj.hospital_rating) FILTER (WHERE rj.completed_at >= now() - interval '90 days' AND rj.hospital_rating IS NOT NULL) AS avg_rating,
           count(*) FILTER (WHERE rj.status = 'disputed' AND rj.created_at >= now() - interval '90 days')::bigint AS disputes_count
    FROM public.repair_jobs rj
    GROUP BY rj.engineer_id
  ),
  payout_agg AS (
    SELECT ep.engineer_user_id,
           SUM(ep.amount_rupees) FILTER (WHERE ep.paid_at >= now() - interval '90 days')::bigint AS payout_sum
    FROM public.engineer_payouts ep
    GROUP BY ep.engineer_user_id
  )
  SELECT e.id, COALESCE(p.full_name, '(unknown)')::text,
         COALESCE(j.jobs_count, 0)::bigint,
         COALESCE(ROUND(j.avg_rating::numeric, 2), 0::numeric),
         COALESCE(j.disputes_count, 0)::bigint,
         COALESCE(pa.payout_sum, 0)::bigint
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN job_agg j ON j.engineer_id = e.id
  LEFT JOIN payout_agg pa ON pa.engineer_user_id = e.user_id
  ORDER BY COALESCE(j.jobs_count, 0) DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_promotion_review_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_promotion_review_scorecard() TO authenticated;

-- ============================================================
-- r1599 CRITICAL — amc_contracts.client_user_id doesn't exist (use hospital_user_id)
-- STUB the broken function
-- ============================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='founder_ownership_at_risk_amcs'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s)', r.nspname, r.proname, r.args);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.founder_ownership_at_risk_amcs()
RETURNS TABLE (event_id uuid, hospital_org_id uuid, hospital_name text, change_kind text, occurred_on date, active_amc_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_org_id, o.name, e.change_kind, e.occurred_on,
         (SELECT count(*) FROM public.amc_contracts ac
          JOIN public.profiles p ON p.id = ac.hospital_user_id
          WHERE p.organization_id = e.hospital_org_id AND ac.status = 'active')
  FROM public.hospital_ownership_change_events e
  LEFT JOIN public.organizations o ON o.id = e.hospital_org_id
  WHERE e.occurred_on >= current_date - 90
  ORDER BY e.occurred_on DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_ownership_at_risk_amcs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ownership_at_risk_amcs() TO authenticated;

COMMIT;
