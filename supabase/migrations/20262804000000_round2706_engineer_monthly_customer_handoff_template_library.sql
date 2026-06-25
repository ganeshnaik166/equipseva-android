BEGIN;

-- ============================================================================
-- Round 2706 — Engineer Monthly Customer Handoff Template Library
-- Spec: template kind × use count × avg score × refinement × winner × kill
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: handoff_templates_r2706
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS handoff_templates_r2706 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code text NOT NULL UNIQUE,
  template_kind text NOT NULL CHECK (template_kind IN ('repair_closeout','amc_renewal','warranty_handoff','parts_delivery','spot_audit_followup','escalation_resolution')),
  template_name text NOT NULL,
  use_count integer NOT NULL DEFAULT 0 CHECK (use_count >= 0),
  avg_score numeric(4,2) NOT NULL DEFAULT 0 CHECK (avg_score >= 0 AND avg_score <= 5),
  refinement_round integer NOT NULL DEFAULT 1 CHECK (refinement_round >= 1),
  winner_flag boolean NOT NULL DEFAULT false,
  kill_flag boolean NOT NULL DEFAULT false,
  created_month date NOT NULL,
  last_used_at timestamptz,
  body_preview text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE handoff_templates_r2706 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON handoff_templates_r2706;
CREATE POLICY founder_all ON handoff_templates_r2706 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO handoff_templates_r2706 (template_code, template_kind, template_name, use_count, avg_score, refinement_round, winner_flag, kill_flag, created_month, last_used_at, body_preview) VALUES
('TPL-CLOSE-V4','repair_closeout','Repair Closeout v4 (winner)',312,4.71,4,true,false,'2026-06-01'::date, now() - interval '2 hour','Dear {hospital}, your {device} has been restored to full operational status...'),
('TPL-AMC-V3','amc_renewal','AMC Renewal Soft Pitch v3',187,4.42,3,false,false,'2026-06-01'::date, now() - interval '6 hour','Your annual maintenance contract renews on {renewal_date}. Tier benefits include...'),
('TPL-WARR-V2','warranty_handoff','Warranty Handoff Standard v2',96,3.88,2,false,false,'2026-05-01'::date, now() - interval '1 day','This handoff confirms warranty terms for {device} effective {start_date}...'),
('TPL-PARTS-V1','parts_delivery','Parts Delivery Confirmation v1',64,3.21,1,false,true,'2026-05-01'::date, now() - interval '4 day','Parts order {order_id} has been delivered to your facility...'),
('TPL-SPOT-V3','spot_audit_followup','Spot Audit Followup v3',43,4.55,3,true,false,'2026-06-01'::date, now() - interval '12 hour','Following the spot audit on {audit_date}, all flagged items have been remediated...'),
('TPL-ESCAL-V2','escalation_resolution','Escalation Resolution v2',28,4.18,2,false,false,'2026-06-01'::date, now() - interval '2 day','We acknowledge the escalation raised on {date} and confirm full resolution...'),
('TPL-CLOSE-V1','repair_closeout','Repair Closeout v1 (deprecated)',412,2.94,1,false,true,'2026-04-01'::date, now() - interval '30 day','Job done. Please rate.');

-- ----------------------------------------------------------------------------
-- Table 2: handoff_template_usage_r2706
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS handoff_template_usage_r2706 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code text NOT NULL,
  engineer_handle text NOT NULL,
  hospital_name text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  customer_score integer CHECK (customer_score >= 1 AND customer_score <= 5),
  response_received boolean NOT NULL DEFAULT false,
  outcome text NOT NULL CHECK (outcome IN ('approved','revision_requested','no_response','escalated','closed_won')),
  notes text
);

ALTER TABLE handoff_template_usage_r2706 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON handoff_template_usage_r2706;
CREATE POLICY founder_all ON handoff_template_usage_r2706 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO handoff_template_usage_r2706 (template_code, engineer_handle, hospital_name, sent_at, customer_score, response_received, outcome, notes) VALUES
('TPL-CLOSE-V4','eng-ravi','Apollo Hyderabad', now() - interval '2 hour', 5, true, 'approved','Customer praised clarity'),
('TPL-AMC-V3','eng-priya','KIMS Secunderabad', now() - interval '6 hour', 4, true, 'closed_won','Renewed Tier-3 AMC'),
('TPL-WARR-V2','eng-suresh','Yashoda Somajiguda', now() - interval '1 day', 4, true, 'approved','Signed handoff'),
('TPL-PARTS-V1','eng-meera','Continental Gachibowli', now() - interval '4 day', 2, false, 'no_response','No reply, template unclear'),
('TPL-SPOT-V3','eng-ravi','Care Banjara', now() - interval '12 hour', 5, true, 'approved','Audit closed'),
('TPL-ESCAL-V2','eng-arjun','AIG Gachibowli', now() - interval '2 day', 4, true, 'closed_won','Escalation resolved'),
('TPL-CLOSE-V1','eng-vikram','Sunshine Paradise', now() - interval '5 day', 2, true, 'revision_requested','Customer wanted detail');

-- ============================================================================
-- RPCs
-- ============================================================================

-- RPC 1: KPI snapshot
DROP FUNCTION IF EXISTS rpc_handoff_template_kpi_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_kpi_r2706()
RETURNS TABLE (
  total_templates integer,
  active_templates integer,
  winners integer,
  killed integer,
  total_uses integer,
  global_avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE NOT kill_flag)::int,
    COUNT(*) FILTER (WHERE winner_flag)::int,
    COUNT(*) FILTER (WHERE kill_flag)::int,
    COALESCE(SUM(use_count),0)::int,
    ROUND(AVG(avg_score)::numeric, 2)
  FROM handoff_templates_r2706;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_kpi_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_kpi_r2706() TO authenticated;

-- RPC 2: templates by kind
DROP FUNCTION IF EXISTS rpc_handoff_template_by_kind_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_by_kind_r2706()
RETURNS TABLE (
  template_kind text,
  count_total integer,
  count_winner integer,
  count_killed integer,
  avg_score_kind numeric,
  total_uses integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.template_kind,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE t.winner_flag)::int,
         COUNT(*) FILTER (WHERE t.kill_flag)::int,
         ROUND(AVG(t.avg_score)::numeric, 2),
         COALESCE(SUM(t.use_count),0)::int
  FROM handoff_templates_r2706 t
  GROUP BY t.template_kind
  ORDER BY t.template_kind;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_by_kind_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_by_kind_r2706() TO authenticated;

-- RPC 3: winners
DROP FUNCTION IF EXISTS rpc_handoff_template_winners_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_winners_r2706()
RETURNS TABLE (
  template_code text,
  template_name text,
  template_kind text,
  use_count integer,
  avg_score numeric,
  refinement_round integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.template_code, t.template_name, t.template_kind, t.use_count, t.avg_score, t.refinement_round
  FROM handoff_templates_r2706 t
  WHERE t.winner_flag = true
  ORDER BY t.avg_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_winners_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_winners_r2706() TO authenticated;

-- RPC 4: kill list
DROP FUNCTION IF EXISTS rpc_handoff_template_kill_list_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_kill_list_r2706()
RETURNS TABLE (
  template_code text,
  template_name text,
  template_kind text,
  avg_score numeric,
  use_count integer,
  reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.template_code, t.template_name, t.template_kind, t.avg_score, t.use_count,
         CASE WHEN t.avg_score < 3.0 THEN 'low score' ELSE 'deprecated' END
  FROM handoff_templates_r2706 t
  WHERE t.kill_flag = true
  ORDER BY t.avg_score ASC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_kill_list_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_kill_list_r2706() TO authenticated;

-- RPC 5: refinement ladder
DROP FUNCTION IF EXISTS rpc_handoff_template_refinement_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_refinement_r2706()
RETURNS TABLE (
  refinement_round integer,
  template_count integer,
  avg_score_round numeric,
  total_uses_round integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.refinement_round, COUNT(*)::int,
         ROUND(AVG(t.avg_score)::numeric, 2),
         COALESCE(SUM(t.use_count),0)::int
  FROM handoff_templates_r2706 t
  GROUP BY t.refinement_round
  ORDER BY t.refinement_round;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_refinement_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_refinement_r2706() TO authenticated;

-- RPC 6: recent usage
DROP FUNCTION IF EXISTS rpc_handoff_template_recent_usage_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_recent_usage_r2706()
RETURNS TABLE (
  template_code text,
  engineer_handle text,
  hospital_name text,
  sent_at timestamptz,
  customer_score integer,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.template_code, u.engineer_handle, u.hospital_name, u.sent_at, u.customer_score, u.outcome
  FROM handoff_template_usage_r2706 u
  ORDER BY u.sent_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_recent_usage_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_recent_usage_r2706() TO authenticated;

-- RPC 7: outcome distribution
DROP FUNCTION IF EXISTS rpc_handoff_template_outcomes_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_outcomes_r2706()
RETURNS TABLE (
  outcome text,
  count_outcome integer,
  pct_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM handoff_template_usage_r2706;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT u.outcome, COUNT(*)::int,
         ROUND((COUNT(*)::numeric * 100.0 / total)::numeric, 2)
  FROM handoff_template_usage_r2706 u
  GROUP BY u.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_outcomes_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_outcomes_r2706() TO authenticated;

-- RPC 8: top engineers by template use
DROP FUNCTION IF EXISTS rpc_handoff_template_top_engineers_r2706();
CREATE OR REPLACE FUNCTION rpc_handoff_template_top_engineers_r2706()
RETURNS TABLE (
  engineer_handle text,
  templates_sent integer,
  avg_score_eng numeric,
  closed_won_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.engineer_handle, COUNT(*)::int,
         ROUND(AVG(u.customer_score)::numeric, 2),
         COUNT(*) FILTER (WHERE u.outcome = 'closed_won')::int
  FROM handoff_template_usage_r2706 u
  GROUP BY u.engineer_handle
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_handoff_template_top_engineers_r2706() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_handoff_template_top_engineers_r2706() TO authenticated;

COMMIT;
