BEGIN;

-- ============================================================
-- r1616 — Founder Hospital Franchise Tracker
-- Extends r1354 v0.6 franchise phase with concrete prospect ledger
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_franchise_prospects_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_name text NOT NULL,
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  city text,
  state_code text,
  contact_name text,
  contact_email text,
  contact_phone text,
  agreement_stage text NOT NULL DEFAULT 'lead' CHECK (agreement_stage IN ('lead','qualified','term_sheet','due_diligence','contract_sent','signed','live','rejected','stalled')),
  monthly_revenue_projection_rupees numeric(12,2) DEFAULT 0,
  one_time_setup_rupees numeric(12,2) DEFAULT 0,
  expected_amc_count integer DEFAULT 0,
  expected_repair_jobs_monthly integer DEFAULT 0,
  founder_decision text NOT NULL DEFAULT 'pending' CHECK (founder_decision IN ('pending','go','no_go','hold')),
  founder_notes text,
  risk_score integer DEFAULT 50 CHECK (risk_score BETWEEN 0 AND 100),
  next_step text,
  next_step_due_date date,
  source_channel text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_franchise_prospects_v2_stage ON founder_franchise_prospects_v2(agreement_stage);
CREATE INDEX IF NOT EXISTS idx_franchise_prospects_v2_decision ON founder_franchise_prospects_v2(founder_decision);
CREATE INDEX IF NOT EXISTS idx_franchise_prospects_v2_next_due ON founder_franchise_prospects_v2(next_step_due_date);

ALTER TABLE founder_franchise_prospects_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS franchise_prospects_v2_founder_all ON founder_franchise_prospects_v2;
CREATE POLICY franchise_prospects_v2_founder_all ON founder_franchise_prospects_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_franchise_stage_events_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_id uuid NOT NULL REFERENCES founder_franchise_prospects_v2(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  note text,
  actor_user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_franchise_stage_events_v2_prospect ON founder_franchise_stage_events_v2(prospect_id);
CREATE INDEX IF NOT EXISTS idx_franchise_stage_events_v2_created ON founder_franchise_stage_events_v2(created_at DESC);

ALTER TABLE founder_franchise_stage_events_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS franchise_stage_events_v2_founder_all ON founder_franchise_stage_events_v2;
CREATE POLICY franchise_stage_events_v2_founder_all ON founder_franchise_stage_events_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_franchise_tracker_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH stage_counts AS (
    SELECT
      COUNT(*) FILTER (WHERE agreement_stage='lead') AS leads,
      COUNT(*) FILTER (WHERE agreement_stage='qualified') AS qualified,
      COUNT(*) FILTER (WHERE agreement_stage='term_sheet') AS term_sheet,
      COUNT(*) FILTER (WHERE agreement_stage='due_diligence') AS due_dil,
      COUNT(*) FILTER (WHERE agreement_stage='contract_sent') AS contract_sent,
      COUNT(*) FILTER (WHERE agreement_stage='signed') AS signed,
      COUNT(*) FILTER (WHERE agreement_stage='live') AS live,
      COUNT(*) FILTER (WHERE agreement_stage='rejected') AS rejected,
      COUNT(*) FILTER (WHERE agreement_stage='stalled') AS stalled,
      COUNT(*) AS total
    FROM founder_franchise_prospects_v2
  ),
  decision_counts AS (
    SELECT
      COUNT(*) FILTER (WHERE founder_decision='go') AS go_count,
      COUNT(*) FILTER (WHERE founder_decision='no_go') AS no_go_count,
      COUNT(*) FILTER (WHERE founder_decision='hold') AS hold_count,
      COUNT(*) FILTER (WHERE founder_decision='pending') AS pending_count
    FROM founder_franchise_prospects_v2
  ),
  rev_proj AS (
    SELECT
      COALESCE(SUM(monthly_revenue_projection_rupees) FILTER (WHERE agreement_stage IN ('signed','live')), 0) AS booked_monthly,
      COALESCE(SUM(monthly_revenue_projection_rupees) FILTER (WHERE agreement_stage IN ('term_sheet','due_diligence','contract_sent')), 0) AS pipeline_monthly,
      COALESCE(SUM(monthly_revenue_projection_rupees) FILTER (WHERE founder_decision='go'), 0) AS go_monthly,
      COALESCE(SUM(one_time_setup_rupees), 0) AS total_setup,
      COALESCE(AVG(risk_score), 0) AS avg_risk
    FROM founder_franchise_prospects_v2
  ),
  due_soon AS (
    SELECT COUNT(*) AS overdue
    FROM founder_franchise_prospects_v2
    WHERE next_step_due_date IS NOT NULL AND next_step_due_date < CURRENT_DATE
  )
  SELECT jsonb_build_object(
    'total', sc.total,
    'leads', sc.leads,
    'qualified', sc.qualified,
    'term_sheet', sc.term_sheet,
    'due_diligence', sc.due_dil,
    'contract_sent', sc.contract_sent,
    'signed', sc.signed,
    'live', sc.live,
    'rejected', sc.rejected,
    'stalled', sc.stalled,
    'go_count', dc.go_count,
    'no_go_count', dc.no_go_count,
    'hold_count', dc.hold_count,
    'pending_count', dc.pending_count,
    'booked_monthly_rupees', rp.booked_monthly,
    'pipeline_monthly_rupees', rp.pipeline_monthly,
    'go_monthly_rupees', rp.go_monthly,
    'total_setup_rupees', rp.total_setup,
    'avg_risk_score', round(rp.avg_risk::numeric, 1),
    'overdue_next_steps', ds.overdue
  ) INTO r
  FROM stage_counts sc, decision_counts dc, rev_proj rp, due_soon ds;
  RETURN COALESCE(r, '{}'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_prospects_list()
RETURNS TABLE(
  id uuid,
  prospect_name text,
  city text,
  state_code text,
  agreement_stage text,
  founder_decision text,
  monthly_revenue_projection_rupees numeric,
  one_time_setup_rupees numeric,
  expected_amc_count integer,
  expected_repair_jobs_monthly integer,
  risk_score integer,
  next_step text,
  next_step_due_date date,
  contact_name text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.prospect_name, p.city, p.state_code, p.agreement_stage, p.founder_decision,
         p.monthly_revenue_projection_rupees, p.one_time_setup_rupees,
         p.expected_amc_count, p.expected_repair_jobs_monthly,
         p.risk_score, p.next_step, p.next_step_due_date,
         p.contact_name, p.created_at
  FROM founder_franchise_prospects_v2 p
  ORDER BY
    CASE p.agreement_stage
      WHEN 'signed' THEN 1 WHEN 'live' THEN 2 WHEN 'contract_sent' THEN 3
      WHEN 'due_diligence' THEN 4 WHEN 'term_sheet' THEN 5 WHEN 'qualified' THEN 6
      WHEN 'lead' THEN 7 WHEN 'stalled' THEN 8 WHEN 'rejected' THEN 9 ELSE 10
    END,
    p.monthly_revenue_projection_rupees DESC NULLS LAST
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_go_no_go_queue()
RETURNS TABLE(
  id uuid,
  prospect_name text,
  agreement_stage text,
  monthly_revenue_projection_rupees numeric,
  risk_score integer,
  founder_decision text,
  next_step text,
  next_step_due_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.prospect_name, p.agreement_stage,
         p.monthly_revenue_projection_rupees, p.risk_score,
         p.founder_decision, p.next_step, p.next_step_due_date
  FROM founder_franchise_prospects_v2 p
  WHERE p.founder_decision = 'pending'
    AND p.agreement_stage IN ('qualified','term_sheet','due_diligence')
  ORDER BY p.monthly_revenue_projection_rupees DESC NULLS LAST, p.risk_score ASC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_stage_funnel()
RETURNS TABLE(
  agreement_stage text,
  prospect_count bigint,
  projected_monthly_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.agreement_stage,
         COUNT(*)::bigint AS prospect_count,
         COALESCE(SUM(p.monthly_revenue_projection_rupees), 0) AS projected_monthly_rupees
  FROM founder_franchise_prospects_v2 p
  GROUP BY p.agreement_stage
  ORDER BY
    CASE p.agreement_stage
      WHEN 'lead' THEN 1 WHEN 'qualified' THEN 2 WHEN 'term_sheet' THEN 3
      WHEN 'due_diligence' THEN 4 WHEN 'contract_sent' THEN 5 WHEN 'signed' THEN 6
      WHEN 'live' THEN 7 WHEN 'stalled' THEN 8 WHEN 'rejected' THEN 9 ELSE 10
    END;
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_stage_events_recent()
RETURNS TABLE(
  id uuid,
  prospect_id uuid,
  prospect_name text,
  from_stage text,
  to_stage text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.prospect_id, p.prospect_name, e.from_stage, e.to_stage, e.note, e.created_at
  FROM founder_franchise_stage_events_v2 e
  LEFT JOIN founder_franchise_prospects_v2 p ON p.id = e.prospect_id
  ORDER BY e.created_at DESC
  LIMIT 50;
END $$;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_franchise_prospect_upsert(
  p_id uuid,
  p_name text,
  p_city text,
  p_state_code text,
  p_contact_name text,
  p_contact_email text,
  p_contact_phone text,
  p_monthly_rev numeric,
  p_one_time numeric,
  p_expected_amc integer,
  p_expected_jobs integer,
  p_risk integer,
  p_next_step text,
  p_next_due date,
  p_source text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO founder_franchise_prospects_v2(
      prospect_name, city, state_code, contact_name, contact_email, contact_phone,
      monthly_revenue_projection_rupees, one_time_setup_rupees,
      expected_amc_count, expected_repair_jobs_monthly, risk_score,
      next_step, next_step_due_date, source_channel
    ) VALUES (
      p_name, p_city, p_state_code, p_contact_name, p_contact_email, p_contact_phone,
      COALESCE(p_monthly_rev,0), COALESCE(p_one_time,0),
      COALESCE(p_expected_amc,0), COALESCE(p_expected_jobs,0), COALESCE(p_risk,50),
      p_next_step, p_next_due, p_source
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE founder_franchise_prospects_v2 SET
      prospect_name = p_name,
      city = p_city,
      state_code = p_state_code,
      contact_name = p_contact_name,
      contact_email = p_contact_email,
      contact_phone = p_contact_phone,
      monthly_revenue_projection_rupees = COALESCE(p_monthly_rev, monthly_revenue_projection_rupees),
      one_time_setup_rupees = COALESCE(p_one_time, one_time_setup_rupees),
      expected_amc_count = COALESCE(p_expected_amc, expected_amc_count),
      expected_repair_jobs_monthly = COALESCE(p_expected_jobs, expected_repair_jobs_monthly),
      risk_score = COALESCE(p_risk, risk_score),
      next_step = p_next_step,
      next_step_due_date = p_next_due,
      source_channel = p_source,
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;
  PERFORM log_founder_franchise_prospect_upsert(v_id, p_name);
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_advance_stage(
  p_id uuid,
  p_new_stage text,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT agreement_stage INTO v_from FROM founder_franchise_prospects_v2 WHERE id = p_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'prospect not found'; END IF;
  UPDATE founder_franchise_prospects_v2
    SET agreement_stage = p_new_stage, updated_at = now()
    WHERE id = p_id;
  INSERT INTO founder_franchise_stage_events_v2(prospect_id, from_stage, to_stage, note, actor_user_id)
    VALUES (p_id, v_from, p_new_stage, p_note, auth.uid());
  PERFORM log_founder_franchise_stage_advance(p_id, v_from, p_new_stage);
END $$;

CREATE OR REPLACE FUNCTION founder_franchise_set_decision(
  p_id uuid,
  p_decision text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_franchise_prospects_v2
    SET founder_decision = p_decision,
        founder_notes = COALESCE(p_notes, founder_notes),
        updated_at = now()
    WHERE id = p_id;
  PERFORM log_founder_franchise_set_decision(p_id, p_decision);
END $$;

-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_franchise_prospect_upsert(p_id uuid, p_name text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_franchise_prospect_upsert',
    jsonb_build_object('prospect_id', p_id, 'prospect_name', p_name),
    now()
  );
END $$;

CREATE OR REPLACE FUNCTION log_founder_franchise_stage_advance(p_id uuid, p_from text, p_to text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_franchise_stage_advance',
    jsonb_build_object('prospect_id', p_id, 'from_stage', p_from, 'to_stage', p_to),
    now()
  );
END $$;

CREATE OR REPLACE FUNCTION log_founder_franchise_set_decision(p_id uuid, p_decision text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_franchise_set_decision',
    jsonb_build_object('prospect_id', p_id, 'decision', p_decision),
    now()
  );
END $$;

CREATE OR REPLACE FUNCTION log_founder_franchise_view(p_op text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_franchise_view',
    jsonb_build_object('op', p_op),
    now()
  );
END $$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_franchise_tracker_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_tracker_kpis() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_prospects_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_prospects_list() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_go_no_go_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_go_no_go_queue() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_stage_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_stage_funnel() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_stage_events_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_stage_events_recent() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_prospect_upsert(uuid,text,text,text,text,text,text,numeric,numeric,integer,integer,integer,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_prospect_upsert(uuid,text,text,text,text,text,text,numeric,numeric,integer,integer,integer,text,date,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_advance_stage(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_advance_stage(uuid,text,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_franchise_set_decision(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_franchise_set_decision(uuid,text,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_franchise_prospect_upsert(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_franchise_prospect_upsert(uuid,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_franchise_stage_advance(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_franchise_stage_advance(uuid,text,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_franchise_set_decision(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_franchise_set_decision(uuid,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_franchise_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_franchise_view(text) TO authenticated;

COMMIT;