BEGIN;

-- ============================================================
-- Round 2738 — Engineer Monthly App Feature Adoption
-- Spec: engineer × feature × use count × time saved × feedback × adoption verdict
-- ============================================================

CREATE TABLE IF NOT EXISTS engineer_feature_usage_r2738 (
  id bigserial PRIMARY KEY,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  feature_key text NOT NULL,
  feature_label text NOT NULL,
  month_label text NOT NULL,
  use_count int NOT NULL CHECK (use_count >= 0),
  minutes_saved int NOT NULL CHECK (minutes_saved >= 0),
  feedback_score numeric(3,1) NOT NULL CHECK (feedback_score >= 0 AND feedback_score <= 5),
  last_used_at timestamptz NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_feature_usage_r2738 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_feature_usage_r2738;
CREATE POLICY founder_all ON engineer_feature_usage_r2738 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS feature_adoption_verdict_r2738 (
  id bigserial PRIMARY KEY,
  feature_key text NOT NULL UNIQUE,
  feature_label text NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('keep','double_down','iterate','sunset')),
  adoption_pct numeric(5,2) NOT NULL CHECK (adoption_pct >= 0 AND adoption_pct <= 100),
  power_user_count int NOT NULL CHECK (power_user_count >= 0),
  rationale text NOT NULL,
  decided_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE feature_adoption_verdict_r2738 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON feature_adoption_verdict_r2738;
CREATE POLICY founder_all ON feature_adoption_verdict_r2738 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO engineer_feature_usage_r2738 (engineer_name, engineer_tier, feature_key, feature_label, month_label, use_count, minutes_saved, feedback_score, last_used_at, notes) VALUES
  ('Ramesh Kulkarni','gold','qr_scan','QR Asset Scan','2026-06',42,168,4.6,'2026-06-24 11:00:00+05:30','Replaces manual asset ID typing'),
  ('Anjali Pradhan','platinum','voice_notes','Voice Notes','2026-06',31,93,4.8,'2026-06-24 12:30:00+05:30','Used during hospital rounds'),
  ('Suresh Iyer','silver','offline_mode','Offline Sync','2026-06',18,72,3.9,'2026-06-23 17:15:00+05:30','Reliable in basement OT'),
  ('Pavithra Menon','gold','parts_lookup','Parts Lookup','2026-06',56,140,4.4,'2026-06-24 09:45:00+05:30','Catalog speed wins'),
  ('Karthik Rao','bronze','training_clip','Training Clips','2026-06',9,27,3.2,'2026-06-22 19:30:00+05:30','Wants Hindi subs'),
  ('Ramesh Kulkarni','gold','signature_capture','Signature Capture','2026-06',28,56,4.5,'2026-06-23 15:00:00+05:30','Hospital admin loved'),
  ('Anjali Pradhan','platinum','escalate_supervisor','Escalate to Supervisor','2026-06',7,35,4.7,'2026-06-22 14:20:00+05:30','One-tap unblock');

INSERT INTO feature_adoption_verdict_r2738 (feature_key, feature_label, verdict, adoption_pct, power_user_count, rationale, decided_on) VALUES
  ('qr_scan','QR Asset Scan','double_down',82.50,18,'Highest time-saved per use; expand to spare parts','2026-06-25'),
  ('voice_notes','Voice Notes','keep',64.20,11,'Strong feedback, low cost to maintain','2026-06-25'),
  ('offline_mode','Offline Sync','iterate',41.00,6,'Bug reports on conflict resolution','2026-06-25'),
  ('parts_lookup','Parts Lookup','double_down',73.80,14,'Drives faster repair close-out','2026-06-25'),
  ('training_clip','Training Clips','iterate',22.40,3,'Need vernacular dubs and shorter clips','2026-06-25'),
  ('signature_capture','Signature Capture','keep',58.10,9,'Compliance must-have','2026-06-25'),
  ('escalate_supervisor','Escalate to Supervisor','keep',49.30,7,'Used at right moments; no churn risk','2026-06-25');

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2738_kpis();
CREATE OR REPLACE FUNCTION founder_r2738_kpis()
RETURNS TABLE (
  total_uses bigint,
  total_minutes_saved bigint,
  active_features bigint,
  active_engineers bigint,
  avg_feedback numeric,
  double_down_count bigint,
  sunset_candidate_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(SUM(u.use_count),0)::bigint,
    COALESCE(SUM(u.minutes_saved),0)::bigint,
    COUNT(DISTINCT u.feature_key)::bigint,
    COUNT(DISTINCT u.engineer_name)::bigint,
    COALESCE(ROUND(AVG(u.feedback_score)::numeric, 2), 0),
    (SELECT COUNT(*) FROM feature_adoption_verdict_r2738 WHERE verdict = 'double_down')::bigint,
    (SELECT COUNT(*) FROM feature_adoption_verdict_r2738 WHERE verdict IN ('iterate','sunset'))::bigint
  FROM engineer_feature_usage_r2738 u;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_feature_rollup();
CREATE OR REPLACE FUNCTION founder_r2738_feature_rollup()
RETURNS TABLE (
  feature_key text,
  feature_label text,
  total_uses bigint,
  total_minutes_saved bigint,
  avg_feedback numeric,
  user_count bigint,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.feature_key,
    u.feature_label,
    SUM(u.use_count)::bigint,
    SUM(u.minutes_saved)::bigint,
    ROUND(AVG(u.feedback_score)::numeric, 2),
    COUNT(DISTINCT u.engineer_name)::bigint,
    COALESCE(v.verdict, 'keep')
  FROM engineer_feature_usage_r2738 u
  LEFT JOIN feature_adoption_verdict_r2738 v ON v.feature_key = u.feature_key
  GROUP BY u.feature_key, u.feature_label, v.verdict
  ORDER BY SUM(u.minutes_saved) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_feature_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_feature_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_engineer_rollup();
CREATE OR REPLACE FUNCTION founder_r2738_engineer_rollup()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  features_used bigint,
  total_uses bigint,
  total_minutes_saved bigint,
  avg_feedback numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.engineer_name,
    MAX(u.engineer_tier),
    COUNT(DISTINCT u.feature_key)::bigint,
    SUM(u.use_count)::bigint,
    SUM(u.minutes_saved)::bigint,
    ROUND(AVG(u.feedback_score)::numeric, 2)
  FROM engineer_feature_usage_r2738 u
  GROUP BY u.engineer_name
  ORDER BY SUM(u.minutes_saved) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_engineer_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_engineer_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_recent_usage(int);
CREATE OR REPLACE FUNCTION founder_r2738_recent_usage(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_name text,
  feature_label text,
  use_count int,
  minutes_saved int,
  feedback_score numeric,
  last_used_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.engineer_name, u.feature_label, u.use_count, u.minutes_saved,
    u.feedback_score, u.last_used_at, u.notes
  FROM engineer_feature_usage_r2738 u
  ORDER BY u.last_used_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_recent_usage(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_recent_usage(int) TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_verdict_breakdown();
CREATE OR REPLACE FUNCTION founder_r2738_verdict_breakdown()
RETURNS TABLE (
  verdict text,
  feature_count bigint,
  avg_adoption_pct numeric,
  total_power_users bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.verdict,
    COUNT(*)::bigint,
    ROUND(AVG(v.adoption_pct)::numeric, 2),
    SUM(v.power_user_count)::bigint
  FROM feature_adoption_verdict_r2738 v
  GROUP BY v.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_verdict_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_top_savers(int);
CREATE OR REPLACE FUNCTION founder_r2738_top_savers(p_limit int DEFAULT 5)
RETURNS TABLE (
  engineer_name text,
  feature_label text,
  minutes_saved int,
  feedback_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    u.engineer_name, u.feature_label, u.minutes_saved, u.feedback_score
  FROM engineer_feature_usage_r2738 u
  ORDER BY u.minutes_saved DESC, u.feedback_score DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_top_savers(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_top_savers(int) TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_low_adoption();
CREATE OR REPLACE FUNCTION founder_r2738_low_adoption()
RETURNS TABLE (
  feature_label text,
  adoption_pct numeric,
  power_user_count int,
  verdict text,
  rationale text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.feature_label, v.adoption_pct, v.power_user_count, v.verdict, v.rationale
  FROM feature_adoption_verdict_r2738 v
  WHERE v.adoption_pct < 50
  ORDER BY v.adoption_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_low_adoption() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_low_adoption() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2738_record_usage(text, text, text, text, text, int, int, numeric, text);
CREATE OR REPLACE FUNCTION founder_r2738_record_usage(
  p_engineer_name text,
  p_engineer_tier text,
  p_feature_key text,
  p_feature_label text,
  p_month_label text,
  p_use_count int,
  p_minutes_saved int,
  p_feedback_score numeric,
  p_notes text
)
RETURNS bigint
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_feature_usage_r2738 (
    engineer_name, engineer_tier, feature_key, feature_label,
    month_label, use_count, minutes_saved, feedback_score, last_used_at, notes
  )
  VALUES (
    p_engineer_name, p_engineer_tier, p_feature_key, p_feature_label,
    p_month_label, p_use_count, p_minutes_saved, p_feedback_score, now(), p_notes
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2738_record_usage(text, text, text, text, text, int, int, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2738_record_usage(text, text, text, text, text, int, int, numeric, text) TO authenticated;

COMMIT;
