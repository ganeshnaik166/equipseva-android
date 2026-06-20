BEGIN;

-- ============================================================
-- r1549 — Founder BizDev Pipeline (individual clinic sales)
-- Separate from r1456 partnerships: smaller deals, faster cycle
-- 5-stage funnel | AE/CSM owner | revenue forecast
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_bizdev_pipeline_deals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_name text NOT NULL,
  clinic_city text,
  clinic_state text,
  contact_name text,
  contact_phone text,
  contact_email text,
  equipment_focus text,
  -- 5-stage funnel: lead -> qualified -> demo -> proposal -> closed_won/closed_lost
  stage text NOT NULL DEFAULT 'lead' CHECK (stage IN ('lead','qualified','demo','proposal','closed_won','closed_lost')),
  ae_owner_email text,
  csm_owner_email text,
  expected_amc_tier text CHECK (expected_amc_tier IN ('bronze','silver','gold','platinum') OR expected_amc_tier IS NULL),
  expected_monthly_revenue_rupees integer NOT NULL DEFAULT 0,
  win_probability_pct integer NOT NULL DEFAULT 10 CHECK (win_probability_pct BETWEEN 0 AND 100),
  expected_close_date date,
  source text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_bizdev_pipeline_stage ON founder_bizdev_pipeline_deals(stage);
CREATE INDEX IF NOT EXISTS idx_bizdev_pipeline_ae ON founder_bizdev_pipeline_deals(ae_owner_email);
CREATE INDEX IF NOT EXISTS idx_bizdev_pipeline_close ON founder_bizdev_pipeline_deals(expected_close_date);

ALTER TABLE founder_bizdev_pipeline_deals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bizdev_pipeline_founder_only ON founder_bizdev_pipeline_deals;
CREATE POLICY bizdev_pipeline_founder_only ON founder_bizdev_pipeline_deals
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_bizdev_pipeline_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES founder_bizdev_pipeline_deals(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('call','email','meeting','demo','note','stage_change','owner_change')),
  from_stage text,
  to_stage text,
  body text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_email text
);

CREATE INDEX IF NOT EXISTS idx_bizdev_activity_deal ON founder_bizdev_pipeline_activity(deal_id, occurred_at DESC);

ALTER TABLE founder_bizdev_pipeline_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bizdev_activity_founder_only ON founder_bizdev_pipeline_activity;
CREATE POLICY bizdev_activity_founder_only ON founder_bizdev_pipeline_activity
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_funnel_overview()
RETURNS TABLE (
  stage text,
  deal_count bigint,
  total_expected_monthly_revenue_rupees bigint,
  weighted_forecast_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.stage,
         COUNT(*)::bigint,
         COALESCE(SUM(d.expected_monthly_revenue_rupees),0)::bigint,
         COALESCE(SUM(d.expected_monthly_revenue_rupees * d.win_probability_pct / 100),0)::bigint
  FROM founder_bizdev_pipeline_deals d
  WHERE d.stage NOT IN ('closed_lost')
  GROUP BY d.stage
  ORDER BY CASE d.stage
    WHEN 'lead' THEN 1 WHEN 'qualified' THEN 2 WHEN 'demo' THEN 3
    WHEN 'proposal' THEN 4 WHEN 'closed_won' THEN 5 ELSE 6 END;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_funnel_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_funnel_overview() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_active_deals(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  clinic_name text,
  clinic_city text,
  stage text,
  ae_owner_email text,
  expected_monthly_revenue_rupees integer,
  win_probability_pct integer,
  expected_close_date date,
  days_in_stage numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.clinic_name, d.clinic_city, d.stage, d.ae_owner_email,
         d.expected_monthly_revenue_rupees, d.win_probability_pct, d.expected_close_date,
         ROUND(EXTRACT(EPOCH FROM (now() - d.updated_at))/86400.0, 1) AS days_in_stage
  FROM founder_bizdev_pipeline_deals d
  WHERE d.stage NOT IN ('closed_won','closed_lost')
  ORDER BY d.expected_monthly_revenue_rupees DESC NULLS LAST
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_active_deals(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_active_deals(int) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_owner_leaderboard()
RETURNS TABLE (
  ae_owner_email text,
  active_deals bigint,
  closed_won_30d bigint,
  closed_lost_30d bigint,
  weighted_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(d.ae_owner_email,'(unassigned)') AS ae_owner_email,
         COUNT(*) FILTER (WHERE d.stage NOT IN ('closed_won','closed_lost'))::bigint,
         COUNT(*) FILTER (WHERE d.stage='closed_won' AND d.closed_at > now() - interval '30 days')::bigint,
         COUNT(*) FILTER (WHERE d.stage='closed_lost' AND d.closed_at > now() - interval '30 days')::bigint,
         COALESCE(SUM(CASE WHEN d.stage NOT IN ('closed_won','closed_lost')
                           THEN d.expected_monthly_revenue_rupees * d.win_probability_pct / 100 ELSE 0 END),0)::bigint
  FROM founder_bizdev_pipeline_deals d
  GROUP BY COALESCE(d.ae_owner_email,'(unassigned)')
  ORDER BY 5 DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_owner_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_owner_leaderboard() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_forecast_summary()
RETURNS TABLE (
  total_deals bigint,
  active_deals bigint,
  closed_won_alltime bigint,
  closed_lost_alltime bigint,
  win_rate_pct numeric,
  weighted_monthly_forecast_rupees bigint,
  unweighted_monthly_pipeline_rupees bigint,
  avg_deal_size_rupees numeric,
  avg_win_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_won bigint; v_lost bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) FILTER (WHERE stage='closed_won'),
         COUNT(*) FILTER (WHERE stage='closed_lost')
    INTO v_won, v_lost FROM founder_bizdev_pipeline_deals;
  RETURN QUERY
  SELECT COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE stage NOT IN ('closed_won','closed_lost'))::bigint,
         v_won, v_lost,
         CASE WHEN (v_won+v_lost)=0 THEN 0 ELSE ROUND(v_won::numeric*100/(v_won+v_lost),1) END,
         COALESCE(SUM(CASE WHEN stage NOT IN ('closed_won','closed_lost')
                           THEN expected_monthly_revenue_rupees * win_probability_pct/100 ELSE 0 END),0)::bigint,
         COALESCE(SUM(CASE WHEN stage NOT IN ('closed_won','closed_lost')
                           THEN expected_monthly_revenue_rupees ELSE 0 END),0)::bigint,
         ROUND(COALESCE(AVG(expected_monthly_revenue_rupees),0),0),
         ROUND(COALESCE(AVG(win_probability_pct) FILTER (WHERE stage NOT IN ('closed_won','closed_lost')),0),1)
  FROM founder_bizdev_pipeline_deals;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_forecast_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_forecast_summary() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_recent_activity(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  deal_id uuid,
  clinic_name text,
  activity_type text,
  from_stage text,
  to_stage text,
  body text,
  occurred_at timestamptz,
  actor_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.deal_id, d.clinic_name, a.activity_type, a.from_stage, a.to_stage,
         a.body, a.occurred_at, a.actor_email
  FROM founder_bizdev_pipeline_activity a
  JOIN founder_bizdev_pipeline_deals d ON d.id=a.deal_id
  ORDER BY a.occurred_at DESC
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_recent_activity(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_recent_activity(int) TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_create_deal(
  p_clinic_name text,
  p_clinic_city text,
  p_ae_owner_email text,
  p_expected_monthly_revenue_rupees integer,
  p_win_probability_pct integer,
  p_expected_close_date date
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_bizdev_pipeline_deals
    (clinic_name, clinic_city, ae_owner_email, expected_monthly_revenue_rupees, win_probability_pct, expected_close_date)
  VALUES (p_clinic_name, p_clinic_city, p_ae_owner_email,
          COALESCE(p_expected_monthly_revenue_rupees,0),
          COALESCE(p_win_probability_pct,10),
          p_expected_close_date)
  RETURNING id INTO v_id;
  PERFORM log_founder_bizdev_deal_created(v_id, p_clinic_name);
  RETURN v_id;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_create_deal(text,text,text,integer,integer,date) FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION rpc_founder_bizdev_advance_stage(p_deal_id uuid, p_new_stage text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT stage INTO v_from FROM founder_bizdev_pipeline_deals WHERE id=p_deal_id;
  UPDATE founder_bizdev_pipeline_deals
     SET stage=p_new_stage,
         updated_at=now(),
         closed_at=CASE WHEN p_new_stage IN ('closed_won','closed_lost') THEN now() ELSE closed_at END
   WHERE id=p_deal_id;
  INSERT INTO founder_bizdev_pipeline_activity(deal_id, activity_type, from_stage, to_stage, actor_email)
  VALUES (p_deal_id,'stage_change', v_from, p_new_stage, (auth.jwt()->>'email'));
  PERFORM log_founder_bizdev_stage_changed(p_deal_id, v_from, p_new_stage);
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_bizdev_advance_stage(uuid,text) FROM PUBLIC, anon;

-- ============================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_bizdev_deal_created(p_deal_id uuid, p_clinic_name text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bizdev_deal_created',
          jsonb_build_object('deal_id', p_deal_id, 'clinic_name', p_clinic_name));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_bizdev_deal_created(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_bizdev_deal_created(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_bizdev_stage_changed(p_deal_id uuid, p_from text, p_to text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bizdev_stage_changed',
          jsonb_build_object('deal_id', p_deal_id, 'from', p_from, 'to', p_to));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_bizdev_stage_changed(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_bizdev_stage_changed(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_bizdev_owner_reassigned(p_deal_id uuid, p_new_owner text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bizdev_owner_reassigned',
          jsonb_build_object('deal_id', p_deal_id, 'new_owner', p_new_owner));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_bizdev_owner_reassigned(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_bizdev_owner_reassigned(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_bizdev_forecast_snapshot(p_weighted_rupees bigint)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'bizdev_forecast_snapshot',
          jsonb_build_object('weighted_monthly_rupees', p_weighted_rupees));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_bizdev_forecast_snapshot(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_bizdev_forecast_snapshot(bigint) TO authenticated;

-- Grant write RPCs after helpers exist
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_create_deal(text,text,text,integer,integer,date) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_bizdev_advance_stage(uuid,text) TO authenticated;

COMMIT;