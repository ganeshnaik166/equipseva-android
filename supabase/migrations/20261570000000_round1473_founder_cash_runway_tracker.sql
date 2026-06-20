BEGIN;

-- ============================================================
-- r1473 — Founder Cash-Runway Tracker
-- Monthly burn snapshots, cash on hand, weighted pipeline,
-- revenue trajectory, runway projection, redline <6mo.
-- ============================================================

-- ---------- Table 1: monthly cash snapshots ----------
CREATE TABLE IF NOT EXISTS founder_cash_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_month date NOT NULL UNIQUE, -- first day of month
  cash_on_hand_rupees bigint NOT NULL CHECK (cash_on_hand_rupees >= 0),
  bank_balance_rupees bigint NOT NULL DEFAULT 0,
  receivables_rupees bigint NOT NULL DEFAULT 0,
  payables_rupees bigint NOT NULL DEFAULT 0,
  monthly_burn_rupees bigint NOT NULL CHECK (monthly_burn_rupees >= 0),
  monthly_revenue_rupees bigint NOT NULL DEFAULT 0,
  monthly_gross_margin_rupees bigint NOT NULL DEFAULT 0,
  headcount int NOT NULL DEFAULT 0,
  note text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid REFERENCES profiles(id)
);

ALTER TABLE founder_cash_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cash_snapshots ON founder_cash_snapshots;
CREATE POLICY founder_only_cash_snapshots ON founder_cash_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_cash_snap_month ON founder_cash_snapshots (snapshot_month DESC);

-- ---------- Table 2: weighted pipeline entries ----------
CREATE TABLE IF NOT EXISTS founder_pipeline_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_name text NOT NULL,
  segment text NOT NULL CHECK (segment IN ('chain','hospital','vertical','franchise','other')),
  stage text NOT NULL CHECK (stage IN ('lead','qualified','demo','pilot','closing','closed_won','closed_lost')),
  arr_rupees bigint NOT NULL CHECK (arr_rupees >= 0),
  probability_pct int NOT NULL CHECK (probability_pct BETWEEN 0 AND 100),
  expected_close_month date,
  owner_user_id uuid REFERENCES profiles(id),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_pipeline_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_pipeline ON founder_pipeline_entries;
CREATE POLICY founder_only_pipeline ON founder_pipeline_entries
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_pipeline_stage ON founder_pipeline_entries (stage);
CREATE INDEX IF NOT EXISTS idx_pipeline_close ON founder_pipeline_entries (expected_close_month);

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- 1) Latest cash snapshot + runway calc
CREATE OR REPLACE FUNCTION founder_cash_current_runway()
RETURNS TABLE(
  snapshot_month date,
  cash_on_hand_rupees bigint,
  monthly_burn_rupees bigint,
  monthly_revenue_rupees bigint,
  net_burn_rupees bigint,
  runway_months numeric,
  redline boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.snapshot_month,
    s.cash_on_hand_rupees,
    s.monthly_burn_rupees,
    s.monthly_revenue_rupees,
    GREATEST(s.monthly_burn_rupees - s.monthly_revenue_rupees, 0)::bigint AS net_burn_rupees,
    CASE WHEN (s.monthly_burn_rupees - s.monthly_revenue_rupees) <= 0 THEN 999::numeric
         ELSE ROUND(s.cash_on_hand_rupees::numeric / NULLIF(s.monthly_burn_rupees - s.monthly_revenue_rupees, 0), 1)
    END AS runway_months,
    CASE WHEN (s.monthly_burn_rupees - s.monthly_revenue_rupees) > 0
         AND s.cash_on_hand_rupees::numeric / NULLIF(s.monthly_burn_rupees - s.monthly_revenue_rupees, 0) < 6
         THEN true ELSE false END AS redline
  FROM founder_cash_snapshots s
  ORDER BY s.snapshot_month DESC
  LIMIT 1;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_current_runway() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_current_runway() TO authenticated;

-- 2) Monthly burn trajectory (last 18 months)
CREATE OR REPLACE FUNCTION founder_cash_burn_trajectory()
RETURNS TABLE(
  snapshot_month date,
  monthly_burn_rupees bigint,
  monthly_revenue_rupees bigint,
  net_burn_rupees bigint,
  cash_on_hand_rupees bigint,
  headcount int,
  mom_burn_change_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH src AS (
    SELECT s.snapshot_month, s.monthly_burn_rupees, s.monthly_revenue_rupees,
           s.cash_on_hand_rupees, s.headcount,
           LAG(s.monthly_burn_rupees) OVER (ORDER BY s.snapshot_month) AS prev_burn
    FROM founder_cash_snapshots s
    ORDER BY s.snapshot_month DESC
    LIMIT 18
  )
  SELECT src.snapshot_month, src.monthly_burn_rupees, src.monthly_revenue_rupees,
         (src.monthly_burn_rupees - src.monthly_revenue_rupees)::bigint,
         src.cash_on_hand_rupees, src.headcount,
         CASE WHEN src.prev_burn IS NULL OR src.prev_burn = 0 THEN NULL
              ELSE ROUND(((src.monthly_burn_rupees - src.prev_burn)::numeric / src.prev_burn) * 100, 1)
         END AS mom_burn_change_pct
  FROM src
  ORDER BY src.snapshot_month DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_burn_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_burn_trajectory() TO authenticated;

-- 3) Weighted pipeline by stage
CREATE OR REPLACE FUNCTION founder_cash_pipeline_by_stage()
RETURNS TABLE(
  stage text,
  entries int,
  total_arr_rupees bigint,
  weighted_arr_rupees bigint,
  avg_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.stage,
         COUNT(*)::int,
         COALESCE(SUM(p.arr_rupees),0)::bigint,
         COALESCE(SUM(p.arr_rupees * p.probability_pct / 100.0),0)::bigint,
         ROUND(AVG(p.probability_pct)::numeric, 1)
  FROM founder_pipeline_entries p
  WHERE p.stage NOT IN ('closed_won','closed_lost')
  GROUP BY p.stage
  ORDER BY weighted_arr_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_pipeline_by_stage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_pipeline_by_stage() TO authenticated;

-- 4) Top pipeline accounts (weighted)
CREATE OR REPLACE FUNCTION founder_cash_top_pipeline()
RETURNS TABLE(
  id uuid,
  account_name text,
  segment text,
  stage text,
  arr_rupees bigint,
  probability_pct int,
  weighted_rupees bigint,
  expected_close_month date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.account_name, p.segment, p.stage, p.arr_rupees, p.probability_pct,
         (p.arr_rupees * p.probability_pct / 100)::bigint,
         p.expected_close_month
  FROM founder_pipeline_entries p
  WHERE p.stage NOT IN ('closed_won','closed_lost')
  ORDER BY (p.arr_rupees * p.probability_pct / 100) DESC
  LIMIT 25;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_top_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_top_pipeline() TO authenticated;

-- 5) Revenue trajectory from real repair_jobs + AMC
CREATE OR REPLACE FUNCTION founder_cash_revenue_trajectory()
RETURNS TABLE(
  ym date,
  repair_revenue_rupees bigint,
  amc_revenue_rupees bigint,
  total_revenue_rupees bigint,
  active_jobs int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', generate_series(now() - interval '11 months', now(), interval '1 month'))::date AS ym
  ),
  rj AS (
    SELECT date_trunc('month', completed_at)::date AS ym,
           COALESCE(SUM(contracted_amount_rupees),0)::bigint AS rev,
           COUNT(*)::int AS jobs
    FROM repair_jobs
    WHERE completed_at IS NOT NULL
    GROUP BY 1
  ),
  amc AS (
    SELECT date_trunc('month', created_at)::date AS ym,
           COALESCE(SUM(monthly_fee_rupees),0)::bigint AS rev
    FROM amc_contracts
    GROUP BY 1
  )
  SELECT m.ym,
         COALESCE(rj.rev,0),
         COALESCE(amc.rev,0),
         (COALESCE(rj.rev,0) + COALESCE(amc.rev,0))::bigint,
         COALESCE(rj.jobs,0)
  FROM months m
  LEFT JOIN rj  ON rj.ym  = m.ym
  LEFT JOIN amc ON amc.ym = m.ym
  ORDER BY m.ym DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_revenue_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_revenue_trajectory() TO authenticated;

-- 6) Headline KPIs
CREATE OR REPLACE FUNCTION founder_cash_headline_kpis()
RETURNS TABLE(
  cash_on_hand_rupees bigint,
  monthly_burn_rupees bigint,
  monthly_revenue_rupees bigint,
  net_burn_rupees bigint,
  runway_months numeric,
  redline boolean,
  weighted_pipeline_rupees bigint,
  total_pipeline_rupees bigint,
  open_pipeline_count int,
  receivables_rupees bigint,
  payables_rupees bigint,
  headcount int,
  trailing_3mo_avg_burn bigint,
  trailing_3mo_avg_revenue bigint,
  burn_multiple numeric,
  months_to_default_risk int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_latest founder_cash_snapshots%ROWTYPE;
  v_avg_burn bigint;
  v_avg_rev bigint;
  v_weighted bigint;
  v_total_pipe bigint;
  v_open_count int;
  v_net bigint;
  v_runway numeric;
  v_burn_multiple numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT * INTO v_latest FROM founder_cash_snapshots ORDER BY snapshot_month DESC LIMIT 1;

  SELECT COALESCE(AVG(monthly_burn_rupees),0)::bigint,
         COALESCE(AVG(monthly_revenue_rupees),0)::bigint
    INTO v_avg_burn, v_avg_rev
  FROM (SELECT monthly_burn_rupees, monthly_revenue_rupees
        FROM founder_cash_snapshots
        ORDER BY snapshot_month DESC LIMIT 3) t;

  SELECT COALESCE(SUM(arr_rupees * probability_pct / 100),0)::bigint,
         COALESCE(SUM(arr_rupees),0)::bigint,
         COUNT(*)::int
    INTO v_weighted, v_total_pipe, v_open_count
  FROM founder_pipeline_entries
  WHERE stage NOT IN ('closed_won','closed_lost');

  v_net := GREATEST(COALESCE(v_latest.monthly_burn_rupees,0) - COALESCE(v_latest.monthly_revenue_rupees,0), 0);
  v_runway := CASE WHEN v_net <= 0 THEN 999::numeric
                   ELSE ROUND(COALESCE(v_latest.cash_on_hand_rupees,0)::numeric / NULLIF(v_net,0), 1) END;
  v_burn_multiple := CASE WHEN COALESCE(v_latest.monthly_revenue_rupees,0) = 0 THEN NULL
                          ELSE ROUND(v_net::numeric / v_latest.monthly_revenue_rupees, 2) END;

  RETURN QUERY SELECT
    COALESCE(v_latest.cash_on_hand_rupees,0)::bigint,
    COALESCE(v_latest.monthly_burn_rupees,0)::bigint,
    COALESCE(v_latest.monthly_revenue_rupees,0)::bigint,
    v_net,
    v_runway,
    (v_net > 0 AND COALESCE(v_latest.cash_on_hand_rupees,0)::numeric / NULLIF(v_net,0) < 6),
    v_weighted, v_total_pipe, v_open_count,
    COALESCE(v_latest.receivables_rupees,0)::bigint,
    COALESCE(v_latest.payables_rupees,0)::bigint,
    COALESCE(v_latest.headcount,0),
    v_avg_burn, v_avg_rev, v_burn_multiple,
    CASE WHEN v_net <= 0 THEN 999 ELSE FLOOR(COALESCE(v_latest.cash_on_hand_rupees,0) / NULLIF(v_net,0))::int END;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_headline_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_headline_kpis() TO authenticated;

-- 7) Pipeline by segment
CREATE OR REPLACE FUNCTION founder_cash_pipeline_by_segment()
RETURNS TABLE(
  segment text,
  entries int,
  total_arr_rupees bigint,
  weighted_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.segment, COUNT(*)::int,
         COALESCE(SUM(p.arr_rupees),0)::bigint,
         COALESCE(SUM(p.arr_rupees * p.probability_pct / 100),0)::bigint
  FROM founder_pipeline_entries p
  WHERE p.stage NOT IN ('closed_won','closed_lost')
  GROUP BY p.segment
  ORDER BY weighted_arr_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_cash_pipeline_by_segment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cash_pipeline_by_segment() TO authenticated;

-- ============================================================
-- WRITE helpers (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_cash_snapshot(
  p_month date,
  p_cash bigint,
  p_bank bigint,
  p_receivables bigint,
  p_payables bigint,
  p_burn bigint,
  p_revenue bigint,
  p_gross_margin bigint,
  p_headcount int,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_cash_snapshots(
    snapshot_month, cash_on_hand_rupees, bank_balance_rupees,
    receivables_rupees, payables_rupees, monthly_burn_rupees,
    monthly_revenue_rupees, monthly_gross_margin_rupees,
    headcount, note, recorded_by
  ) VALUES (
    date_trunc('month', p_month)::date, p_cash, p_bank,
    p_receivables, p_payables, p_burn, p_revenue, p_gross_margin,
    p_headcount, p_note, auth.uid()
  )
  ON CONFLICT (snapshot_month) DO UPDATE SET
    cash_on_hand_rupees = EXCLUDED.cash_on_hand_rupees,
    bank_balance_rupees = EXCLUDED.bank_balance_rupees,
    receivables_rupees = EXCLUDED.receivables_rupees,
    payables_rupees = EXCLUDED.payables_rupees,
    monthly_burn_rupees = EXCLUDED.monthly_burn_rupees,
    monthly_revenue_rupees = EXCLUDED.monthly_revenue_rupees,
    monthly_gross_margin_rupees = EXCLUDED.monthly_gross_margin_rupees,
    headcount = EXCLUDED.headcount,
    note = EXCLUDED.note,
    recorded_at = now(),
    recorded_by = auth.uid()
  RETURNING id INTO v_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_cash_snapshot',
          jsonb_build_object('id', v_id, 'month', p_month, 'cash', p_cash, 'burn', p_burn));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_cash_snapshot(date,bigint,bigint,bigint,bigint,bigint,bigint,bigint,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cash_snapshot(date,bigint,bigint,bigint,bigint,bigint,bigint,bigint,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pipeline_upsert(
  p_id uuid,
  p_account text,
  p_segment text,
  p_stage text,
  p_arr bigint,
  p_probability int,
  p_close_month date,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO founder_pipeline_entries(account_name, segment, stage, arr_rupees, probability_pct, expected_close_month, owner_user_id, note)
    VALUES (p_account, p_segment, p_stage, p_arr, p_probability, p_close_month, auth.uid(), p_note)
    RETURNING id INTO v_id;
  ELSE
    UPDATE founder_pipeline_entries SET
      account_name = p_account,
      segment = p_segment,
      stage = p_stage,
      arr_rupees = p_arr,
      probability_pct = p_probability,
      expected_close_month = p_close_month,
      note = p_note,
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_pipeline_upsert',
          jsonb_build_object('id', v_id, 'account', p_account, 'stage', p_stage, 'arr', p_arr, 'prob', p_probability));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pipeline_upsert(uuid,text,text,text,bigint,int,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pipeline_upsert(uuid,text,text,text,bigint,int,date,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pipeline_close(
  p_id uuid,
  p_won boolean,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_pipeline_entries
     SET stage = CASE WHEN p_won THEN 'closed_won' ELSE 'closed_lost' END,
         note = COALESCE(p_note, note),
         updated_at = now()
   WHERE id = p_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_pipeline_close',
          jsonb_build_object('id', p_id, 'won', p_won));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pipeline_close(uuid,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pipeline_close(uuid,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_runway_alert(
  p_runway_months numeric,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_founder_runway_alert',
          jsonb_build_object('runway_months', p_runway_months, 'note', p_note));
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_runway_alert(numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_runway_alert(numeric,text) TO authenticated;

COMMIT;