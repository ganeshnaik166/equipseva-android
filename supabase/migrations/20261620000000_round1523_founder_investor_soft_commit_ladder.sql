BEGIN;

-- Investor soft-commit ladder: capture verbal/soft commits, track hardening to wired funds.
-- Founder-only console. RLS locked. RPCs SECDEF + is_founder gate.

CREATE TABLE IF NOT EXISTS founder_investor_soft_commits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_firm text,
  investor_email text,
  investor_phone text,
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  round_label text NOT NULL DEFAULT 'seed',
  commit_stage text NOT NULL DEFAULT 'verbal' CHECK (commit_stage IN ('verbal','soft','term_sheet','signed','wired','dropped')),
  conditions text,
  source text,
  expected_close_date date,
  follow_up_sla_days int NOT NULL DEFAULT 7 CHECK (follow_up_sla_days > 0),
  last_touch_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hardened_at timestamptz,
  wired_at timestamptz,
  dropped_at timestamptz,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_isc_stage ON founder_investor_soft_commits(commit_stage);
CREATE INDEX IF NOT EXISTS idx_isc_last_touch ON founder_investor_soft_commits(last_touch_at);
CREATE INDEX IF NOT EXISTS idx_isc_created ON founder_investor_soft_commits(created_at);

CREATE TABLE IF NOT EXISTS founder_investor_soft_commit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commit_id uuid NOT NULL REFERENCES founder_investor_soft_commits(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','stage_changed','touched','note_added','amount_changed','dropped','wired')),
  from_stage text,
  to_stage text,
  payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isce_commit ON founder_investor_soft_commit_events(commit_id);
CREATE INDEX IF NOT EXISTS idx_isce_created ON founder_investor_soft_commit_events(created_at);

ALTER TABLE founder_investor_soft_commits ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_soft_commit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_isc ON founder_investor_soft_commits;
CREATE POLICY founder_only_isc ON founder_investor_soft_commits
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_isce ON founder_investor_soft_commit_events;
CREATE POLICY founder_only_isce ON founder_investor_soft_commit_events
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ===== log helpers =====
CREATE OR REPLACE FUNCTION log_founder_isc_created(p_commit_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isc_created', jsonb_build_object('commit_id', p_commit_id, 'payload', p_payload));
END $$;

CREATE OR REPLACE FUNCTION log_founder_isc_stage_changed(p_commit_id uuid, p_from text, p_to text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isc_stage_changed', jsonb_build_object('commit_id', p_commit_id, 'from', p_from, 'to', p_to));
END $$;

CREATE OR REPLACE FUNCTION log_founder_isc_touched(p_commit_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isc_touched', jsonb_build_object('commit_id', p_commit_id));
END $$;

CREATE OR REPLACE FUNCTION log_founder_isc_dropped(p_commit_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isc_dropped', jsonb_build_object('commit_id', p_commit_id, 'reason', p_reason));
END $$;

-- ===== READ RPCs (STABLE) =====
CREATE OR REPLACE FUNCTION founder_isc_kpis()
RETURNS TABLE(
  total_commits bigint,
  total_amount_rupees bigint,
  verbal_count bigint,
  verbal_amount bigint,
  soft_count bigint,
  soft_amount bigint,
  ts_count bigint,
  ts_amount bigint,
  signed_count bigint,
  signed_amount bigint,
  wired_count bigint,
  wired_amount bigint,
  dropped_count bigint,
  weighted_pipeline_rupees bigint,
  hardening_rate numeric,
  overdue_sla_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(amount_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='verbal')::bigint,
    COALESCE(SUM(amount_rupees) FILTER (WHERE commit_stage='verbal'),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='soft')::bigint,
    COALESCE(SUM(amount_rupees) FILTER (WHERE commit_stage='soft'),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='term_sheet')::bigint,
    COALESCE(SUM(amount_rupees) FILTER (WHERE commit_stage='term_sheet'),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='signed')::bigint,
    COALESCE(SUM(amount_rupees) FILTER (WHERE commit_stage='signed'),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='wired')::bigint,
    COALESCE(SUM(amount_rupees) FILTER (WHERE commit_stage='wired'),0)::bigint,
    COUNT(*) FILTER (WHERE commit_stage='dropped')::bigint,
    COALESCE(SUM(
      CASE commit_stage
        WHEN 'verbal' THEN amount_rupees * 0.10
        WHEN 'soft' THEN amount_rupees * 0.30
        WHEN 'term_sheet' THEN amount_rupees * 0.60
        WHEN 'signed' THEN amount_rupees * 0.85
        WHEN 'wired' THEN amount_rupees * 1.00
        ELSE 0
      END
    ),0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE commit_stage IN ('verbal','soft','term_sheet','signed','wired')) = 0 THEN 0
      ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE commit_stage IN ('signed','wired'))::numeric
        / NULLIF(COUNT(*) FILTER (WHERE commit_stage IN ('verbal','soft','term_sheet','signed','wired')),0), 2)
    END,
    COUNT(*) FILTER (
      WHERE commit_stage NOT IN ('wired','dropped')
        AND (EXTRACT(EPOCH FROM (now() - last_touch_at))/86400.0) > follow_up_sla_days
    )::bigint
  FROM founder_investor_soft_commits;
END $$;

CREATE OR REPLACE FUNCTION founder_isc_ladder()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_firm text,
  amount_rupees bigint,
  commit_stage text,
  conditions text,
  expected_close_date date,
  last_touch_at timestamptz,
  created_at timestamptz,
  days_in_pipeline numeric,
  weighted_amount numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.investor_firm, s.amount_rupees, s.commit_stage, s.conditions,
         s.expected_close_date, s.last_touch_at, s.created_at,
         ROUND((EXTRACT(EPOCH FROM (now() - s.created_at))/86400.0)::numeric, 1),
         (s.amount_rupees * CASE s.commit_stage
            WHEN 'verbal' THEN 0.10 WHEN 'soft' THEN 0.30
            WHEN 'term_sheet' THEN 0.60 WHEN 'signed' THEN 0.85
            WHEN 'wired' THEN 1.00 ELSE 0 END)::numeric
  FROM founder_investor_soft_commits s
  WHERE s.commit_stage NOT IN ('dropped')
  ORDER BY
    CASE s.commit_stage WHEN 'wired' THEN 0 WHEN 'signed' THEN 1
      WHEN 'term_sheet' THEN 2 WHEN 'soft' THEN 3 WHEN 'verbal' THEN 4 ELSE 5 END,
    s.amount_rupees DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION founder_isc_ageing_report()
RETURNS TABLE(
  id uuid,
  investor_name text,
  commit_stage text,
  amount_rupees bigint,
  days_since_touch numeric,
  follow_up_sla_days int,
  sla_breach_days numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.commit_stage, s.amount_rupees,
         ROUND((EXTRACT(EPOCH FROM (now() - s.last_touch_at))/86400.0)::numeric, 1),
         s.follow_up_sla_days,
         ROUND(((EXTRACT(EPOCH FROM (now() - s.last_touch_at))/86400.0) - s.follow_up_sla_days)::numeric, 1),
         CASE
           WHEN (EXTRACT(EPOCH FROM (now() - s.last_touch_at))/86400.0) > s.follow_up_sla_days * 2 THEN 'red'
           WHEN (EXTRACT(EPOCH FROM (now() - s.last_touch_at))/86400.0) > s.follow_up_sla_days THEN 'amber'
           ELSE 'green'
         END
  FROM founder_investor_soft_commits s
  WHERE s.commit_stage NOT IN ('wired','dropped')
  ORDER BY (EXTRACT(EPOCH FROM (now() - s.last_touch_at))/86400.0) DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION founder_isc_recent_events()
RETURNS TABLE(
  id uuid,
  commit_id uuid,
  investor_name text,
  event_type text,
  from_stage text,
  to_stage text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.commit_id, s.investor_name, e.event_type, e.from_stage, e.to_stage, e.created_at
  FROM founder_investor_soft_commit_events e
  JOIN founder_investor_soft_commits s ON s.id = e.commit_id
  ORDER BY e.created_at DESC
  LIMIT 50;
END $$;

-- ===== WRITE RPCs (VOLATILE) =====
CREATE OR REPLACE FUNCTION founder_isc_capture(
  p_investor_name text,
  p_investor_firm text,
  p_amount_rupees bigint,
  p_commit_stage text,
  p_conditions text,
  p_expected_close_date date,
  p_follow_up_sla_days int
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_soft_commits(
    investor_name, investor_firm, amount_rupees, commit_stage, conditions,
    expected_close_date, follow_up_sla_days
  ) VALUES (
    p_investor_name, p_investor_firm, p_amount_rupees,
    COALESCE(p_commit_stage,'verbal'), p_conditions, p_expected_close_date,
    COALESCE(p_follow_up_sla_days,7)
  ) RETURNING id INTO v_id;
  INSERT INTO founder_investor_soft_commit_events(commit_id, event_type, to_stage)
  VALUES (v_id, 'created', COALESCE(p_commit_stage,'verbal'));
  PERFORM log_founder_isc_created(v_id, jsonb_build_object('name', p_investor_name, 'amount', p_amount_rupees));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION founder_isc_advance_stage(p_commit_id uuid, p_new_stage text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT commit_stage INTO v_old FROM founder_investor_soft_commits WHERE id = p_commit_id;
  IF v_old IS NULL THEN RAISE EXCEPTION 'not found'; END IF;
  UPDATE founder_investor_soft_commits
  SET commit_stage = p_new_stage,
      last_touch_at = now(),
      hardened_at = CASE WHEN p_new_stage IN ('term_sheet','signed') AND hardened_at IS NULL THEN now() ELSE hardened_at END,
      wired_at = CASE WHEN p_new_stage = 'wired' THEN now() ELSE wired_at END,
      dropped_at = CASE WHEN p_new_stage = 'dropped' THEN now() ELSE dropped_at END
  WHERE id = p_commit_id;
  INSERT INTO founder_investor_soft_commit_events(commit_id, event_type, from_stage, to_stage)
  VALUES (p_commit_id, 'stage_changed', v_old, p_new_stage);
  PERFORM log_founder_isc_stage_changed(p_commit_id, v_old, p_new_stage);
END $$;

CREATE OR REPLACE FUNCTION founder_isc_record_touch(p_commit_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_soft_commits SET last_touch_at = now() WHERE id = p_commit_id;
  INSERT INTO founder_investor_soft_commit_events(commit_id, event_type, payload)
  VALUES (p_commit_id, 'touched', jsonb_build_object('note', p_note));
  PERFORM log_founder_isc_touched(p_commit_id);
END $$;

REVOKE EXECUTE ON FUNCTION founder_isc_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_ladder() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_ageing_report() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_recent_events() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_capture(text,text,bigint,text,text,date,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_advance_stage(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_isc_record_touch(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_isc_created(uuid,jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_isc_stage_changed(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_isc_touched(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_isc_dropped(uuid,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_isc_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_ladder() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_ageing_report() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_recent_events() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_capture(text,text,bigint,text,text,date,int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_advance_stage(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_isc_record_touch(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_isc_created(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_isc_stage_changed(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_isc_touched(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_isc_dropped(uuid,text) TO authenticated;

COMMIT;