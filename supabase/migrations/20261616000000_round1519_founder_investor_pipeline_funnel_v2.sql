BEGIN;

-- ============================================================
-- r1519 — Founder Investor Pipeline Funnel v2
-- Extended funnel: target_list -> contacted -> met -> DD ->
--   term_sheet -> signed -> wired
-- Per-stage conversion + per-cohort cycle time
-- ============================================================

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS investor_pipeline_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm text,
  contact_email text,
  cohort_label text NOT NULL DEFAULT 'default',
  check_size_inr_lakhs numeric(14,2),
  current_stage text NOT NULL DEFAULT 'target_list'
    CHECK (current_stage IN ('target_list','contacted','met','dd','term_sheet','signed','wired','passed')),
  source text,
  notes text,
  passed_reason text,
  target_list_at timestamptz DEFAULT now(),
  contacted_at timestamptz,
  met_at timestamptz,
  dd_at timestamptz,
  term_sheet_at timestamptz,
  signed_at timestamptz,
  wired_at timestamptz,
  passed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_pipeline_v2_stage
  ON investor_pipeline_v2(current_stage);
CREATE INDEX IF NOT EXISTS idx_investor_pipeline_v2_cohort
  ON investor_pipeline_v2(cohort_label);

CREATE TABLE IF NOT EXISTS investor_pipeline_v2_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES investor_pipeline_v2(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  note text,
  actor_user_id uuid,
  actor_email text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_pipeline_v2_events_inv
  ON investor_pipeline_v2_events(investor_id, occurred_at DESC);

ALTER TABLE investor_pipeline_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE investor_pipeline_v2_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_inv_pipeline_v2 ON investor_pipeline_v2;
CREATE POLICY founder_only_inv_pipeline_v2 ON investor_pipeline_v2
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_inv_pipeline_v2_events ON investor_pipeline_v2_events;
CREATE POLICY founder_only_inv_pipeline_v2_events ON investor_pipeline_v2_events
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- log helpers ----------
CREATE OR REPLACE FUNCTION log_founder_inv_v2_added(p_inv uuid, p_name text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_pipeline_v2.added',
          jsonb_build_object('investor_id', p_inv, 'investor_name', p_name));
END $$;

CREATE OR REPLACE FUNCTION log_founder_inv_v2_advanced(p_inv uuid, p_from text, p_to text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_pipeline_v2.advanced',
          jsonb_build_object('investor_id', p_inv, 'from_stage', p_from, 'to_stage', p_to));
END $$;

CREATE OR REPLACE FUNCTION log_founder_inv_v2_passed(p_inv uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_pipeline_v2.passed',
          jsonb_build_object('investor_id', p_inv, 'reason', p_reason));
END $$;

CREATE OR REPLACE FUNCTION log_founder_inv_v2_viewed(p_scope text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_pipeline_v2.viewed',
          jsonb_build_object('scope', p_scope));
END $$;

-- ---------- Read RPCs (STABLE) ----------
CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_funnel_counts()
RETURNS TABLE(stage text, n bigint, conversion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_top bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_top FROM investor_pipeline_v2 WHERE current_stage <> 'passed';
  IF v_top IS NULL OR v_top = 0 THEN v_top := 1; END IF;
  RETURN QUERY
  WITH stages(s, ord) AS (
    VALUES ('target_list',1),('contacted',2),('met',3),('dd',4),
           ('term_sheet',5),('signed',6),('wired',7)
  ),
  reach AS (
    SELECT s.s AS stage, s.ord,
      (SELECT count(*) FROM investor_pipeline_v2 p
        WHERE p.current_stage <> 'passed' AND (
          (s.s = 'target_list' AND p.target_list_at IS NOT NULL) OR
          (s.s = 'contacted'   AND p.contacted_at  IS NOT NULL) OR
          (s.s = 'met'         AND p.met_at        IS NOT NULL) OR
          (s.s = 'dd'          AND p.dd_at         IS NOT NULL) OR
          (s.s = 'term_sheet'  AND p.term_sheet_at IS NOT NULL) OR
          (s.s = 'signed'      AND p.signed_at     IS NOT NULL) OR
          (s.s = 'wired'       AND p.wired_at      IS NOT NULL)
        )
      )::bigint AS n
    FROM stages s
  )
  SELECT r.stage, r.n,
         round((r.n::numeric / v_top::numeric) * 100, 1) AS conversion_pct
  FROM reach r ORDER BY r.ord;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_stage_conversion()
RETURNS TABLE(from_stage text, to_stage text, conv_pct numeric, n_from bigint, n_to bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH s AS (
    SELECT
      count(*) FILTER (WHERE target_list_at IS NOT NULL) AS n_tl,
      count(*) FILTER (WHERE contacted_at  IS NOT NULL) AS n_c,
      count(*) FILTER (WHERE met_at        IS NOT NULL) AS n_m,
      count(*) FILTER (WHERE dd_at         IS NOT NULL) AS n_d,
      count(*) FILTER (WHERE term_sheet_at IS NOT NULL) AS n_t,
      count(*) FILTER (WHERE signed_at     IS NOT NULL) AS n_s,
      count(*) FILTER (WHERE wired_at      IS NOT NULL) AS n_w
    FROM investor_pipeline_v2 WHERE current_stage <> 'passed'
  )
  SELECT 'target_list','contacted', CASE WHEN s.n_tl>0 THEN round(s.n_c::numeric*100/s.n_tl,1) ELSE 0 END, s.n_tl, s.n_c FROM s
  UNION ALL SELECT 'contacted','met',         CASE WHEN s.n_c>0  THEN round(s.n_m::numeric*100/s.n_c,1)  ELSE 0 END, s.n_c, s.n_m FROM s
  UNION ALL SELECT 'met','dd',                CASE WHEN s.n_m>0  THEN round(s.n_d::numeric*100/s.n_m,1)  ELSE 0 END, s.n_m, s.n_d FROM s
  UNION ALL SELECT 'dd','term_sheet',         CASE WHEN s.n_d>0  THEN round(s.n_t::numeric*100/s.n_d,1)  ELSE 0 END, s.n_d, s.n_t FROM s
  UNION ALL SELECT 'term_sheet','signed',     CASE WHEN s.n_t>0  THEN round(s.n_s::numeric*100/s.n_t,1)  ELSE 0 END, s.n_t, s.n_s FROM s
  UNION ALL SELECT 'signed','wired',          CASE WHEN s.n_s>0  THEN round(s.n_w::numeric*100/s.n_s,1)  ELSE 0 END, s.n_s, s.n_w FROM s;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_cohort_cycle_time()
RETURNS TABLE(cohort_label text, n bigint,
              avg_days_tl_to_signed numeric,
              avg_days_signed_to_wired numeric,
              avg_days_tl_to_wired numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.cohort_label, count(*)::bigint,
    round(avg(EXTRACT(EPOCH FROM (p.signed_at - p.target_list_at))/86400.0)::numeric, 1),
    round(avg(EXTRACT(EPOCH FROM (p.wired_at  - p.signed_at))     /86400.0)::numeric, 1),
    round(avg(EXTRACT(EPOCH FROM (p.wired_at  - p.target_list_at))/86400.0)::numeric, 1)
  FROM investor_pipeline_v2 p
  WHERE p.current_stage <> 'passed'
  GROUP BY p.cohort_label
  ORDER BY count(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_active_investors()
RETURNS TABLE(id uuid, investor_name text, firm text, current_stage text,
              cohort_label text, check_size_inr_lakhs numeric, days_in_stage numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.firm, p.current_stage, p.cohort_label,
         p.check_size_inr_lakhs,
         round(EXTRACT(EPOCH FROM (now() - p.updated_at))/86400.0, 1) AS days_in_stage
  FROM investor_pipeline_v2 p
  WHERE p.current_stage <> 'passed'
  ORDER BY p.updated_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_recent_events(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, investor_id uuid, investor_name text,
              from_stage text, to_stage text, note text, occurred_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.investor_id, p.investor_name,
         e.from_stage, e.to_stage, e.note, e.occurred_at
  FROM investor_pipeline_v2_events e
  JOIN investor_pipeline_v2 p ON p.id = e.investor_id
  ORDER BY e.occurred_at DESC
  LIMIT p_limit;
END $$;

-- ---------- Write RPCs (VOLATILE) ----------
CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_add(
  p_name text, p_firm text, p_email text, p_cohort text,
  p_check_lakhs numeric, p_source text, p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_pipeline_v2(investor_name, firm, contact_email, cohort_label,
                                   check_size_inr_lakhs, source, notes)
  VALUES (p_name, p_firm, p_email, COALESCE(NULLIF(p_cohort,''),'default'),
          p_check_lakhs, p_source, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO investor_pipeline_v2_events(investor_id, from_stage, to_stage, note,
                                          actor_user_id, actor_email)
  VALUES (v_id, NULL, 'target_list', 'added',
          auth.uid(), (auth.jwt()->>'email'));
  PERFORM log_founder_inv_v2_added(v_id, p_name);
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION rpc_founder_inv_v2_advance(
  p_investor uuid, p_to_stage text, p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_to_stage NOT IN ('contacted','met','dd','term_sheet','signed','wired','passed') THEN
    RAISE EXCEPTION 'bad_stage';
  END IF;
  SELECT current_stage INTO v_from FROM investor_pipeline_v2 WHERE id = p_investor;
  IF v_from IS NULL THEN RAISE EXCEPTION 'not_found'; END IF;

  UPDATE investor_pipeline_v2 SET
    current_stage = p_to_stage,
    contacted_at  = CASE WHEN p_to_stage='contacted'  AND contacted_at  IS NULL THEN now() ELSE contacted_at  END,
    met_at        = CASE WHEN p_to_stage='met'        AND met_at        IS NULL THEN now() ELSE met_at        END,
    dd_at         = CASE WHEN p_to_stage='dd'         AND dd_at         IS NULL THEN now() ELSE dd_at         END,
    term_sheet_at = CASE WHEN p_to_stage='term_sheet' AND term_sheet_at IS NULL THEN now() ELSE term_sheet_at END,
    signed_at     = CASE WHEN p_to_stage='signed'     AND signed_at     IS NULL THEN now() ELSE signed_at     END,
    wired_at      = CASE WHEN p_to_stage='wired'      AND wired_at      IS NULL THEN now() ELSE wired_at      END,
    passed_at     = CASE WHEN p_to_stage='passed'     AND passed_at     IS NULL THEN now() ELSE passed_at     END,
    passed_reason = CASE WHEN p_to_stage='passed' THEN COALESCE(p_note, passed_reason) ELSE passed_reason END,
    updated_at    = now()
  WHERE id = p_investor;

  INSERT INTO investor_pipeline_v2_events(investor_id, from_stage, to_stage, note,
                                          actor_user_id, actor_email)
  VALUES (p_investor, v_from, p_to_stage, p_note,
          auth.uid(), (auth.jwt()->>'email'));

  IF p_to_stage = 'passed' THEN
    PERFORM log_founder_inv_v2_passed(p_investor, p_note);
  ELSE
    PERFORM log_founder_inv_v2_advanced(p_investor, v_from, p_to_stage);
  END IF;
END $$;

-- ---------- Grants ----------
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_funnel_counts()         FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_stage_conversion()      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_cohort_cycle_time()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_active_investors()      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_recent_events(int)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_add(text,text,text,text,numeric,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_inv_v2_advance(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_inv_v2_added(uuid,text)        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_inv_v2_advanced(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_inv_v2_passed(uuid,text)       FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_inv_v2_viewed(text)            FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_funnel_counts()         TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_stage_conversion()      TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_cohort_cycle_time()     TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_active_investors()      TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_recent_events(int)      TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_add(text,text,text,text,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_inv_v2_advance(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_inv_v2_added(uuid,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_inv_v2_advanced(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_inv_v2_passed(uuid,text)       TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_inv_v2_viewed(text)            TO authenticated;

COMMIT;