BEGIN;

-- r1644: Hospital ticket-to-AMC funnel — founder console
-- Surfaces hospitals running heavy on one-off repair tickets that would be
-- cheaper served by AMC, scored by conversion likelihood, with founder action.

CREATE TABLE IF NOT EXISTS founder_hospital_amc_conversion_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  repair_ticket_count int NOT NULL DEFAULT 0,
  repair_spend_rupees bigint NOT NULL DEFAULT 0,
  distinct_equipment_categories int NOT NULL DEFAULT 0,
  avg_hospital_rating numeric(3,2),
  likelihood_score int NOT NULL DEFAULT 0,
  proposed_amc_tier text,
  proposed_monthly_fee_rupees bigint,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','contacted','quoted','won','lost','snoozed')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhact_hospital ON founder_hospital_amc_conversion_targets(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhact_status ON founder_hospital_amc_conversion_targets(status, likelihood_score DESC);
CREATE INDEX IF NOT EXISTS idx_fhact_created ON founder_hospital_amc_conversion_targets(created_at DESC);

ALTER TABLE founder_hospital_amc_conversion_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhact_founder_only ON founder_hospital_amc_conversion_targets;
CREATE POLICY fhact_founder_only ON founder_hospital_amc_conversion_targets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_hospital_amc_conversion_outreach (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES founder_hospital_amc_conversion_targets(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('call','email','whatsapp','meeting','other')),
  outcome text NOT NULL CHECK (outcome IN ('no_answer','interested','objection','not_now','converted','declined')),
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhaco_target ON founder_hospital_amc_conversion_outreach(target_id, created_at DESC);

ALTER TABLE founder_hospital_amc_conversion_outreach ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhaco_founder_only ON founder_hospital_amc_conversion_outreach;
CREATE POLICY fhaco_founder_only ON founder_hospital_amc_conversion_outreach
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ===== logging helpers =====
CREATE OR REPLACE FUNCTION log_founder_hospital_t2a(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_hospital_t2a(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_hospital_t2a(text, jsonb) TO authenticated;

-- ===== RPC 1: KPI summary =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_kpis()
RETURNS TABLE (
  total_open_targets int,
  total_contacted int,
  total_won int,
  total_lost int,
  pipeline_monthly_fee_rupees bigint,
  median_likelihood int,
  high_likelihood_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'open'))::int,
    (COUNT(*) FILTER (WHERE status = 'contacted'))::int,
    (COUNT(*) FILTER (WHERE status = 'won'))::int,
    (COUNT(*) FILTER (WHERE status = 'lost'))::int,
    COALESCE(SUM(proposed_monthly_fee_rupees) FILTER (WHERE status IN ('open','contacted','quoted')), 0)::bigint,
    COALESCE((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY likelihood_score))::int, 0),
    (COUNT(*) FILTER (WHERE likelihood_score >= 70 AND status IN ('open','contacted','quoted')))::int
  FROM founder_hospital_amc_conversion_targets;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_kpis() TO authenticated;

-- ===== RPC 2: list targets with hospital meta =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_list_targets(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  hospital_state text,
  repair_ticket_count int,
  repair_spend_rupees bigint,
  distinct_equipment_categories int,
  avg_hospital_rating numeric,
  likelihood_score int,
  proposed_amc_tier text,
  proposed_monthly_fee_rupees bigint,
  status text,
  founder_note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    t.id,
    t.hospital_org_id,
    o.name,
    o.state,
    t.repair_ticket_count,
    t.repair_spend_rupees,
    t.distinct_equipment_categories,
    t.avg_hospital_rating,
    t.likelihood_score,
    t.proposed_amc_tier,
    t.proposed_monthly_fee_rupees,
    t.status,
    t.founder_note,
    t.created_at
  FROM founder_hospital_amc_conversion_targets t
  LEFT JOIN organizations o ON o.id = t.hospital_org_id
  ORDER BY
    CASE WHEN t.status = 'open' THEN 0
         WHEN t.status = 'contacted' THEN 1
         WHEN t.status = 'quoted' THEN 2
         ELSE 3 END,
    t.likelihood_score DESC,
    t.repair_spend_rupees DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_list_targets(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_list_targets(int) TO authenticated;

-- ===== RPC 3: rebuild target rows from repair_jobs in window =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_rebuild(p_window_days int DEFAULT 90)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_start timestamptz := now() - (p_window_days || ' days')::interval;
  v_end   timestamptz := now();
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  WITH agg AS (
    SELECT
      r.hospital_org_id,
      (COUNT(*))::int AS tickets,
      COALESCE(SUM(r.contracted_amount_rupees), 0)::bigint AS spend,
      (COUNT(DISTINCT r.kind))::int AS cats,
      AVG(r.hospital_rating)::numeric(3,2) AS rating
    FROM repair_jobs r
    WHERE r.created_at >= v_start
      AND r.hospital_org_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM amc_contracts a
        WHERE a.hospital_user_id = r.hospital_org_id
      )
    GROUP BY r.hospital_org_id
    HAVING (COUNT(*))::int >= 3
  ), scored AS (
    SELECT
      a.*,
      LEAST(100,
        (a.tickets * 6) +
        LEAST(40, (a.spend / 5000)::int) +
        (a.cats * 5) +
        COALESCE((a.rating * 4)::int, 0)
      ) AS score,
      CASE
        WHEN a.spend >= 1500000 THEN 'platinum'
        WHEN a.spend >= 600000  THEN 'gold'
        WHEN a.spend >= 200000  THEN 'silver'
        ELSE 'bronze'
      END AS tier,
      CASE
        WHEN a.spend >= 1500000 THEN 120000
        WHEN a.spend >= 600000  THEN 60000
        WHEN a.spend >= 200000  THEN 25000
        ELSE 12000
      END AS monthly_fee
    FROM agg a
  )
  INSERT INTO founder_hospital_amc_conversion_targets(
    hospital_org_id, window_start, window_end,
    repair_ticket_count, repair_spend_rupees, distinct_equipment_categories,
    avg_hospital_rating, likelihood_score, proposed_amc_tier, proposed_monthly_fee_rupees
  )
  SELECT hospital_org_id, v_start, v_end, tickets, spend, cats, rating, score, tier, monthly_fee
  FROM scored
  WHERE NOT EXISTS (
    SELECT 1 FROM founder_hospital_amc_conversion_targets t
    WHERE t.hospital_org_id = scored.hospital_org_id
      AND t.status IN ('open','contacted','quoted')
  );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM log_founder_hospital_t2a('t2a_rebuild', jsonb_build_object('inserted', v_count, 'window_days', p_window_days));
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_rebuild(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_rebuild(int) TO authenticated;

-- ===== RPC 4: set status =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_set_status(p_id uuid, p_status text, p_note text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('open','contacted','quoted','won','lost','snoozed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE founder_hospital_amc_conversion_targets
  SET status = p_status,
      founder_note = COALESCE(p_note, founder_note),
      updated_at = now()
  WHERE id = p_id;
  PERFORM log_founder_hospital_t2a('t2a_set_status', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_set_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_set_status(uuid, text, text) TO authenticated;

-- ===== RPC 5: log outreach =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_log_outreach(
  p_target_id uuid, p_channel text, p_outcome text, p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_hospital_amc_conversion_outreach(target_id, channel, outcome, notes, created_by)
  VALUES (p_target_id, p_channel, p_outcome, p_notes, auth.uid())
  RETURNING id INTO v_id;

  IF p_outcome = 'converted' THEN
    UPDATE founder_hospital_amc_conversion_targets
    SET status = 'won', updated_at = now()
    WHERE id = p_target_id;
  ELSIF p_outcome = 'declined' THEN
    UPDATE founder_hospital_amc_conversion_targets
    SET status = 'lost', updated_at = now()
    WHERE id = p_target_id;
  ELSIF p_outcome IN ('interested','objection','not_now','no_answer') THEN
    UPDATE founder_hospital_amc_conversion_targets
    SET status = 'contacted', updated_at = now()
    WHERE id = p_target_id AND status = 'open';
  END IF;

  PERFORM log_founder_hospital_t2a('t2a_log_outreach', jsonb_build_object('target_id', p_target_id, 'outcome', p_outcome));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_log_outreach(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_log_outreach(uuid, text, text, text) TO authenticated;

-- ===== RPC 6: per-target outreach history =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_outreach_history(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  target_id uuid,
  hospital_name text,
  channel text,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    h.id, h.target_id, o.name, h.channel, h.outcome, h.notes, h.created_at
  FROM founder_hospital_amc_conversion_outreach h
  JOIN founder_hospital_amc_conversion_targets t ON t.id = h.target_id
  LEFT JOIN organizations o ON o.id = t.hospital_org_id
  ORDER BY h.created_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_outreach_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_outreach_history(int) TO authenticated;

-- ===== RPC 7: tier distribution of current pipeline =====
CREATE OR REPLACE FUNCTION founder_hospital_t2a_tier_breakdown()
RETURNS TABLE (
  proposed_amc_tier text,
  target_count int,
  open_count int,
  contacted_count int,
  won_count int,
  monthly_fee_pipeline_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COALESCE(proposed_amc_tier, 'unspecified') AS tier,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'open'))::int,
    (COUNT(*) FILTER (WHERE status = 'contacted'))::int,
    (COUNT(*) FILTER (WHERE status = 'won'))::int,
    COALESCE(SUM(proposed_monthly_fee_rupees) FILTER (WHERE status IN ('open','contacted','quoted')), 0)::bigint
  FROM founder_hospital_amc_conversion_targets
  GROUP BY COALESCE(proposed_amc_tier, 'unspecified')
  ORDER BY 6 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_hospital_t2a_tier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_hospital_t2a_tier_breakdown() TO authenticated;

COMMIT;