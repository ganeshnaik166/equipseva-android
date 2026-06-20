BEGIN;

-- =====================================================================
-- r1503: Founder Investor Mega-List + Full Lifecycle Console
-- =====================================================================
-- Consolidates every investor touched across r1390/r1419/r1435/r1474/
-- r1486/r1495/r1499 into one master list with lifecycle state,
-- funnel metrics, and a founder-action ladder.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLE 1: master investor registry
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_investor_mega_registry (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name   text NOT NULL,
  firm_name       text,
  primary_email   text,
  partner_lead    text,
  fund_stage      text CHECK (fund_stage IN ('angel','pre_seed','seed','series_a','series_b','growth','strategic')),
  cheque_min_lakh numeric(12,2),
  cheque_max_lakh numeric(12,2),
  geo_region      text,
  thesis_fit_0_100 int CHECK (thesis_fit_0_100 BETWEEN 0 AND 100),
  lifecycle_state text NOT NULL DEFAULT 'cold' CHECK (lifecycle_state IN ('cold','warm','met','dd','term_sheet','passed','closed','ghosted')),
  first_touch_at  timestamptz NOT NULL DEFAULT now(),
  last_touch_at   timestamptz NOT NULL DEFAULT now(),
  closed_amount_lakh numeric(14,2),
  source_round    text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_mega_state    ON founder_investor_mega_registry(lifecycle_state);
CREATE INDEX IF NOT EXISTS idx_inv_mega_lasttouch ON founder_investor_mega_registry(last_touch_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_mega_stage    ON founder_investor_mega_registry(fund_stage);

ALTER TABLE founder_investor_mega_registry ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_mega_reg ON founder_investor_mega_registry;
CREATE POLICY founder_only_mega_reg ON founder_investor_mega_registry
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ---------------------------------------------------------------------
-- TABLE 2: action ladder (founder next-action queue)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_investor_action_ladder (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id     uuid NOT NULL REFERENCES founder_investor_mega_registry(id) ON DELETE CASCADE,
  rung_order      int  NOT NULL CHECK (rung_order BETWEEN 1 AND 10),
  action_text     text NOT NULL,
  due_at          timestamptz,
  completed_at    timestamptz,
  blocker_note    text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_ladder_inv ON founder_investor_action_ladder(investor_id, rung_order);
CREATE INDEX IF NOT EXISTS idx_inv_ladder_due ON founder_investor_action_ladder(due_at) WHERE completed_at IS NULL;

ALTER TABLE founder_investor_action_ladder ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_ladder ON founder_investor_action_ladder;
CREATE POLICY founder_only_ladder ON founder_investor_action_ladder
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

-- 1) full mega list with derived metrics
CREATE OR REPLACE FUNCTION rpc_founder_investor_mega_list()
RETURNS TABLE (
  id uuid, investor_name text, firm_name text, fund_stage text,
  lifecycle_state text, cheque_max_lakh numeric, thesis_fit_0_100 int,
  partner_lead text, days_since_touch numeric, source_round text,
  open_actions int, last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.firm_name, r.fund_stage,
         r.lifecycle_state, r.cheque_max_lakh, r.thesis_fit_0_100,
         r.partner_lead,
         EXTRACT(EPOCH FROM (now() - r.last_touch_at))/86400.0 AS days_since_touch,
         r.source_round,
         (SELECT count(*)::int FROM founder_investor_action_ladder l
            WHERE l.investor_id = r.id AND l.completed_at IS NULL) AS open_actions,
         r.last_touch_at
  FROM founder_investor_mega_registry r
  ORDER BY r.last_touch_at DESC;
END;$$;

-- 2) funnel counts
CREATE OR REPLACE FUNCTION rpc_founder_investor_funnel()
RETURNS TABLE (lifecycle_state text, n int, total_cheque_max_lakh numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.lifecycle_state, count(*)::int, COALESCE(sum(r.cheque_max_lakh),0)::numeric
  FROM founder_investor_mega_registry r
  GROUP BY r.lifecycle_state
  ORDER BY 1;
END;$$;

-- 3) KPI rollup
CREATE OR REPLACE FUNCTION rpc_founder_investor_kpis()
RETURNS TABLE (
  total_investors int, cold_n int, warm_n int, met_n int, dd_n int,
  term_sheet_n int, passed_n int, closed_n int, ghosted_n int,
  total_pipeline_lakh numeric, closed_amount_lakh numeric,
  avg_thesis_fit numeric, stale_30d int, open_actions int, due_this_week int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM founder_investor_mega_registry),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='cold'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='warm'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='met'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='dd'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='term_sheet'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='passed'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='closed'),
    (SELECT count(*)::int FROM founder_investor_mega_registry WHERE lifecycle_state='ghosted'),
    (SELECT COALESCE(sum(cheque_max_lakh),0)::numeric FROM founder_investor_mega_registry
        WHERE lifecycle_state IN ('warm','met','dd','term_sheet')),
    (SELECT COALESCE(sum(closed_amount_lakh),0)::numeric FROM founder_investor_mega_registry
        WHERE lifecycle_state='closed'),
    (SELECT COALESCE(avg(thesis_fit_0_100),0)::numeric FROM founder_investor_mega_registry),
    (SELECT count(*)::int FROM founder_investor_mega_registry
        WHERE EXTRACT(EPOCH FROM (now()-last_touch_at))/86400.0 > 30
          AND lifecycle_state NOT IN ('passed','closed','ghosted')),
    (SELECT count(*)::int FROM founder_investor_action_ladder WHERE completed_at IS NULL),
    (SELECT count(*)::int FROM founder_investor_action_ladder
        WHERE completed_at IS NULL AND due_at IS NOT NULL
          AND due_at < now() + interval '7 days');
END;$$;

-- 4) action ladder pending
CREATE OR REPLACE FUNCTION rpc_founder_investor_action_ladder()
RETURNS TABLE (
  id uuid, investor_id uuid, investor_name text, rung_order int,
  action_text text, due_at timestamptz, blocker_note text,
  days_until_due numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_id, r.investor_name, l.rung_order,
         l.action_text, l.due_at, l.blocker_note,
         CASE WHEN l.due_at IS NULL THEN NULL
              ELSE EXTRACT(EPOCH FROM (l.due_at - now()))/86400.0 END
  FROM founder_investor_action_ladder l
  JOIN founder_investor_mega_registry r ON r.id = l.investor_id
  WHERE l.completed_at IS NULL
  ORDER BY COALESCE(l.due_at, now() + interval '999 days') ASC, l.rung_order ASC;
END;$$;

-- 5) stale investors (no touch >30d, still open)
CREATE OR REPLACE FUNCTION rpc_founder_investor_stale()
RETURNS TABLE (
  id uuid, investor_name text, firm_name text, lifecycle_state text,
  days_since_touch numeric, partner_lead text, cheque_max_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.firm_name, r.lifecycle_state,
         EXTRACT(EPOCH FROM (now()-r.last_touch_at))/86400.0,
         r.partner_lead, r.cheque_max_lakh
  FROM founder_investor_mega_registry r
  WHERE EXTRACT(EPOCH FROM (now()-r.last_touch_at))/86400.0 > 30
    AND r.lifecycle_state NOT IN ('passed','closed','ghosted')
  ORDER BY r.last_touch_at ASC
  LIMIT 100;
END;$$;

-- 6) by-stage breakdown
CREATE OR REPLACE FUNCTION rpc_founder_investor_by_stage()
RETURNS TABLE (fund_stage text, n int, total_max_lakh numeric, avg_fit numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.fund_stage,'unknown'), count(*)::int,
         COALESCE(sum(r.cheque_max_lakh),0)::numeric,
         COALESCE(avg(r.thesis_fit_0_100),0)::numeric
  FROM founder_investor_mega_registry r
  GROUP BY r.fund_stage
  ORDER BY 2 DESC;
END;$$;

-- 7) round-source provenance (which spawn-round first touched them)
CREATE OR REPLACE FUNCTION rpc_founder_investor_by_source_round()
RETURNS TABLE (source_round text, n int, closed_n int, total_closed_lakh numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.source_round,'unknown'),
         count(*)::int,
         count(*) FILTER (WHERE r.lifecycle_state='closed')::int,
         COALESCE(sum(r.closed_amount_lakh) FILTER (WHERE r.lifecycle_state='closed'),0)::numeric
  FROM founder_investor_mega_registry r
  GROUP BY r.source_round
  ORDER BY 2 DESC;
END;$$;

-- =====================================================================
-- WRITE-LAYER LOG HELPERS (VOLATILE)
-- =====================================================================

-- helper 1: upsert investor + log
CREATE OR REPLACE FUNCTION log_founder_investor_upsert(
  p_investor_name text, p_firm_name text, p_fund_stage text,
  p_lifecycle_state text, p_cheque_max_lakh numeric,
  p_thesis_fit_0_100 int, p_source_round text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_mega_registry
    (investor_name, firm_name, fund_stage, lifecycle_state,
     cheque_max_lakh, thesis_fit_0_100, source_round, last_touch_at)
  VALUES (p_investor_name, p_firm_name, p_fund_stage,
          COALESCE(p_lifecycle_state,'cold'),
          p_cheque_max_lakh, p_thesis_fit_0_100, p_source_round, now())
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'investor_upsert',
          jsonb_build_object('investor_id', v_id, 'name', p_investor_name,
                             'state', p_lifecycle_state, 'round', p_source_round));
  RETURN v_id;
END;$$;

-- helper 2: transition lifecycle state
CREATE OR REPLACE FUNCTION log_founder_investor_state_change(
  p_investor_id uuid, p_new_state text, p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_mega_registry
     SET lifecycle_state = p_new_state,
         last_touch_at = now(),
         updated_at = now(),
         notes = COALESCE(notes,'') || E'\n[' || now()::text || '] ' || COALESCE(p_note,'')
   WHERE id = p_investor_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'investor_state_change',
          jsonb_build_object('investor_id', p_investor_id, 'new_state', p_new_state, 'note', p_note));
END;$$;

-- helper 3: enqueue action rung
CREATE OR REPLACE FUNCTION log_founder_investor_action_rung(
  p_investor_id uuid, p_rung_order int, p_action_text text, p_due_at timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_action_ladder
    (investor_id, rung_order, action_text, due_at)
  VALUES (p_investor_id, p_rung_order, p_action_text, p_due_at)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'investor_action_enqueue',
          jsonb_build_object('ladder_id', v_id, 'investor_id', p_investor_id,
                             'rung', p_rung_order, 'action', p_action_text));
  RETURN v_id;
END;$$;

-- helper 4: complete action rung
CREATE OR REPLACE FUNCTION log_founder_investor_action_complete(
  p_ladder_id uuid, p_outcome_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_action_ladder
     SET completed_at = now(),
         blocker_note = COALESCE(blocker_note,'') || ' | done: ' || COALESCE(p_outcome_note,'')
   WHERE id = p_ladder_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'investor_action_complete',
          jsonb_build_object('ladder_id', p_ladder_id, 'outcome', p_outcome_note));
END;$$;

-- =====================================================================
-- LOCK DOWN EXECUTE
-- =====================================================================
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_mega_list()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_funnel()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_kpis()                FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_action_ladder()       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_stale()               FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_by_stage()            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_by_source_round()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_upsert(text,text,text,text,numeric,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_state_change(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_action_rung(uuid,int,text,timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_action_complete(uuid,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_investor_mega_list()           TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_funnel()              TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_kpis()                TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_action_ladder()       TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_stale()               TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_by_stage()            TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_by_source_round()     TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_upsert(text,text,text,text,numeric,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_state_change(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_action_rung(uuid,int,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_action_complete(uuid,text) TO authenticated;

COMMIT;