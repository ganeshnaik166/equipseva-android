BEGIN;

-- =========================================================================
-- r1469 — Engineer Side-Projects Intel
-- Capture intel on engineers running side businesses / consulting,
-- flag conflict-of-interest risk, document conversations,
-- founder action ladder.
-- =========================================================================

-- ---------- TABLE 1: engineer_side_projects_intel_v2 ----------
CREATE TABLE IF NOT EXISTS engineer_side_projects_intel_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id     uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  intel_source    text NOT NULL CHECK (intel_source IN ('self_disclosed','peer_report','customer_report','social_media','founder_observed','whatsapp_leak','linkedin','other')),
  side_business_type text NOT NULL CHECK (side_business_type IN ('independent_repair','consulting','spare_parts_resale','training','equipment_broker','competing_amc','medical_device_sales','unrelated_business','unknown')),
  business_name   text,
  estimated_monthly_revenue_rupees integer DEFAULT 0,
  estimated_hours_per_week integer DEFAULT 0,
  conflict_risk   text NOT NULL DEFAULT 'medium' CHECK (conflict_risk IN ('low','medium','high','critical')),
  customer_overlap_pct integer DEFAULT 0 CHECK (customer_overlap_pct BETWEEN 0 AND 100),
  uses_equipseva_brand boolean NOT NULL DEFAULT false,
  uses_equipseva_parts  boolean NOT NULL DEFAULT false,
  on_equipseva_time     boolean NOT NULL DEFAULT false,
  poaching_customers    boolean NOT NULL DEFAULT false,
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','documented','warned','resolved','terminated','tolerated')),
  founder_action_level int NOT NULL DEFAULT 1 CHECK (founder_action_level BETWEEN 1 AND 5),
  evidence_url    text,
  notes           text,
  first_observed_at timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at  timestamptz,
  resolved_at       timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS espi_v2_engineer_idx ON engineer_side_projects_intel_v2(engineer_id);
CREATE INDEX IF NOT EXISTS espi_v2_status_idx ON engineer_side_projects_intel_v2(status);
CREATE INDEX IF NOT EXISTS espi_v2_risk_idx ON engineer_side_projects_intel_v2(conflict_risk);

ALTER TABLE engineer_side_projects_intel_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS espi_v2_founder_all ON engineer_side_projects_intel_v2;
CREATE POLICY espi_v2_founder_all ON engineer_side_projects_intel_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- TABLE 2: engineer_side_projects_conversations_v2 ----------
CREATE TABLE IF NOT EXISTS engineer_side_projects_conversations_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intel_id        uuid NOT NULL REFERENCES engineer_side_projects_intel_v2(id) ON DELETE CASCADE,
  conversation_at timestamptz NOT NULL DEFAULT now(),
  channel         text NOT NULL CHECK (channel IN ('in_person','call','whatsapp','email','video','sms','other')),
  tone            text NOT NULL DEFAULT 'neutral' CHECK (tone IN ('warm','neutral','firm','warning','final_warning','termination')),
  action_level    int NOT NULL DEFAULT 1 CHECK (action_level BETWEEN 1 AND 5),
  summary         text NOT NULL,
  engineer_response text,
  outcome         text,
  follow_up_due_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS espc_v2_intel_idx ON engineer_side_projects_conversations_v2(intel_id);
CREATE INDEX IF NOT EXISTS espc_v2_when_idx ON engineer_side_projects_conversations_v2(conversation_at DESC);

ALTER TABLE engineer_side_projects_conversations_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS espc_v2_founder_all ON engineer_side_projects_conversations_v2;
CREATE POLICY espc_v2_founder_all ON engineer_side_projects_conversations_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- RPCs — 7 STABLE SECDEF (founder-gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_kpis_r1469()
RETURNS TABLE (
  total_intel_records int,
  open_cases int,
  investigating_cases int,
  documented_cases int,
  resolved_cases int,
  terminated_cases int,
  critical_risk int,
  high_risk int,
  medium_risk int,
  low_risk int,
  engineers_with_intel int,
  using_equipseva_brand int,
  using_equipseva_parts int,
  poaching_customers int,
  on_equipseva_time int,
  competing_amc_count int,
  est_revenue_leak_rupees bigint,
  conversations_30d int,
  follow_ups_overdue int,
  avg_action_level numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE status='open'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE status='investigating'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE status='documented'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE status='resolved'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE status='terminated'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE conflict_risk='critical'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE conflict_risk='high'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE conflict_risk='medium'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE conflict_risk='low'),
    (SELECT COUNT(DISTINCT engineer_id)::int FROM engineer_side_projects_intel_v2),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE uses_equipseva_brand),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE uses_equipseva_parts),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE poaching_customers),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE on_equipseva_time),
    (SELECT COUNT(*)::int FROM engineer_side_projects_intel_v2 WHERE side_business_type='competing_amc'),
    (SELECT COALESCE(SUM(estimated_monthly_revenue_rupees),0)::bigint FROM engineer_side_projects_intel_v2 WHERE status NOT IN ('resolved','tolerated')),
    (SELECT COUNT(*)::int FROM engineer_side_projects_conversations_v2 WHERE conversation_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM engineer_side_projects_conversations_v2 WHERE follow_up_due_at IS NOT NULL AND follow_up_due_at < now()),
    (SELECT COALESCE(AVG(founder_action_level),0)::numeric FROM engineer_side_projects_intel_v2 WHERE status NOT IN ('resolved','tolerated'));
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_kpis_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_active_list_r1469()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  side_business_type text,
  business_name text,
  conflict_risk text,
  status text,
  founder_action_level int,
  est_monthly_revenue_rupees integer,
  uses_brand boolean,
  uses_parts boolean,
  poaching boolean,
  first_observed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    i.engineer_id,
    COALESCE(p.full_name, 'engineer-' || substr(i.engineer_id::text,1,8)),
    i.side_business_type,
    i.business_name,
    i.conflict_risk,
    i.status,
    i.founder_action_level,
    i.estimated_monthly_revenue_rupees,
    i.uses_equipseva_brand,
    i.uses_equipseva_parts,
    i.poaching_customers,
    i.first_observed_at
  FROM engineer_side_projects_intel_v2 i
  LEFT JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE i.status NOT IN ('resolved','tolerated','terminated')
  ORDER BY
    CASE i.conflict_risk WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    i.founder_action_level DESC,
    i.first_observed_at DESC
  LIMIT 200;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_active_list_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_by_risk_r1469()
RETURNS TABLE (
  conflict_risk text,
  case_count int,
  est_revenue_leak_rupees bigint,
  avg_action_level numeric,
  newest_case_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.conflict_risk,
    COUNT(*)::int,
    COALESCE(SUM(i.estimated_monthly_revenue_rupees),0)::bigint,
    COALESCE(AVG(i.founder_action_level),0)::numeric,
    MAX(i.first_observed_at)
  FROM engineer_side_projects_intel_v2 i
  GROUP BY i.conflict_risk
  ORDER BY CASE i.conflict_risk WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_by_risk_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_by_type_r1469()
RETURNS TABLE (
  side_business_type text,
  case_count int,
  critical_or_high int,
  est_revenue_leak_rupees bigint,
  poaching_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.side_business_type,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE i.conflict_risk IN ('critical','high'))::int,
    COALESCE(SUM(i.estimated_monthly_revenue_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE i.poaching_customers)::int
  FROM engineer_side_projects_intel_v2 i
  GROUP BY i.side_business_type
  ORDER BY COUNT(*) DESC;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_by_type_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_recent_convos_r1469()
RETURNS TABLE (
  id uuid,
  intel_id uuid,
  engineer_name text,
  conversation_at timestamptz,
  channel text,
  tone text,
  action_level int,
  summary text,
  follow_up_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.intel_id,
    COALESCE(p.full_name, 'engineer-' || substr(i.engineer_id::text,1,8)),
    c.conversation_at,
    c.channel,
    c.tone,
    c.action_level,
    c.summary,
    c.follow_up_due_at
  FROM engineer_side_projects_conversations_v2 c
  JOIN engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  ORDER BY c.conversation_at DESC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_recent_convos_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_action_ladder_r1469()
RETURNS TABLE (
  action_level int,
  level_label text,
  case_count int,
  est_revenue_leak_rupees bigint,
  last_convo_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.founder_action_level,
    CASE i.founder_action_level
      WHEN 1 THEN 'L1 observe'
      WHEN 2 THEN 'L2 informal chat'
      WHEN 3 THEN 'L3 formal warning'
      WHEN 4 THEN 'L4 final warning'
      WHEN 5 THEN 'L5 terminate'
      ELSE 'unknown'
    END,
    COUNT(*)::int,
    COALESCE(SUM(i.estimated_monthly_revenue_rupees),0)::bigint,
    MAX((SELECT MAX(c.conversation_at) FROM engineer_side_projects_conversations_v2 c WHERE c.intel_id = i.id))
  FROM engineer_side_projects_intel_v2 i
  WHERE i.status NOT IN ('resolved','tolerated','terminated')
  GROUP BY i.founder_action_level
  ORDER BY i.founder_action_level;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_action_ladder_r1469() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_side_projects_overdue_followups_r1469()
RETURNS TABLE (
  id uuid,
  intel_id uuid,
  engineer_name text,
  conflict_risk text,
  follow_up_due_at timestamptz,
  days_overdue int,
  last_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.intel_id,
    COALESCE(p.full_name, 'engineer-' || substr(i.engineer_id::text,1,8)),
    i.conflict_risk,
    c.follow_up_due_at,
    GREATEST(0, EXTRACT(DAY FROM (now() - c.follow_up_due_at))::int),
    c.summary
  FROM engineer_side_projects_conversations_v2 c
  JOIN engineer_side_projects_intel_v2 i ON i.id = c.intel_id
  LEFT JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.profile_id
  WHERE c.follow_up_due_at IS NOT NULL
    AND c.follow_up_due_at < now()
    AND i.status NOT IN ('resolved','tolerated','terminated')
  ORDER BY c.follow_up_due_at ASC
  LIMIT 100;
END $$;
GRANT EXECUTE ON FUNCTION founder_engineer_side_projects_overdue_followups_r1469() TO authenticated;

-- =========================================================================
-- log_founder_* helpers (VOLATILE SECDEF, is_founder gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_engineer_side_project_intel_r1469(
  p_engineer_id uuid,
  p_intel_source text,
  p_business_type text,
  p_business_name text,
  p_conflict_risk text,
  p_est_revenue integer,
  p_uses_brand boolean,
  p_uses_parts boolean,
  p_poaching boolean,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_side_projects_intel_v2 (
    engineer_id, intel_source, side_business_type, business_name,
    conflict_risk, estimated_monthly_revenue_rupees,
    uses_equipseva_brand, uses_equipseva_parts, poaching_customers, notes
  ) VALUES (
    p_engineer_id, p_intel_source, p_business_type, p_business_name,
    p_conflict_risk, COALESCE(p_est_revenue,0),
    COALESCE(p_uses_brand,false), COALESCE(p_uses_parts,false), COALESCE(p_poaching,false), p_notes
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_engineer_side_project_intel_r1469(uuid,text,text,text,text,integer,boolean,boolean,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_side_project_conversation_r1469(
  p_intel_id uuid,
  p_channel text,
  p_tone text,
  p_action_level int,
  p_summary text,
  p_engineer_response text,
  p_outcome text,
  p_follow_up_due_at timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_side_projects_conversations_v2 (
    intel_id, channel, tone, action_level, summary, engineer_response, outcome, follow_up_due_at
  ) VALUES (
    p_intel_id, p_channel, p_tone, COALESCE(p_action_level,1), p_summary, p_engineer_response, p_outcome, p_follow_up_due_at
  ) RETURNING id INTO v_id;
  UPDATE engineer_side_projects_intel_v2
     SET founder_action_level = GREATEST(founder_action_level, COALESCE(p_action_level,1)),
         last_reviewed_at = now(),
         updated_at = now()
   WHERE id = p_intel_id;
  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_engineer_side_project_conversation_r1469(uuid,text,text,int,text,text,text,timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_side_project_status_r1469(
  p_intel_id uuid,
  p_status text,
  p_action_level int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_side_projects_intel_v2
     SET status = p_status,
         founder_action_level = COALESCE(p_action_level, founder_action_level),
         last_reviewed_at = now(),
         resolved_at = CASE WHEN p_status IN ('resolved','terminated','tolerated') THEN now() ELSE resolved_at END,
         updated_at = now()
   WHERE id = p_intel_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_engineer_side_project_status_r1469(uuid,text,int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_side_project_risk_bump_r1469(
  p_intel_id uuid,
  p_new_risk text,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_side_projects_intel_v2
     SET conflict_risk = p_new_risk,
         notes = COALESCE(notes,'') || E'\n[risk-bump] ' || COALESCE(p_reason,''),
         last_reviewed_at = now(),
         updated_at = now()
   WHERE id = p_intel_id;
END $$;
GRANT EXECUTE ON FUNCTION log_founder_engineer_side_project_risk_bump_r1469(uuid,text,text) TO authenticated;

COMMIT;