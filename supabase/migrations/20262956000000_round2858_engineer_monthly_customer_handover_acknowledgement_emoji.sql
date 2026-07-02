BEGIN;

-- =====================================================================
-- Round 2858 — Engineer Monthly Customer Handover Acknowledgement Emoji
-- engineer x handover x emoji response x sentiment x engagement x outcome
-- =====================================================================

-- --------------------------------------------------------------
-- Table 1: monthly handover acknowledgement events
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_handover_ack_emoji_events_r2858 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code            text NOT NULL,
  engineer_name            text NOT NULL,
  hospital_code            text NOT NULL,
  hospital_name            text NOT NULL,
  handover_month           date NOT NULL,
  emoji                    text NOT NULL,
  emoji_label              text NOT NULL,
  sentiment_score          numeric(4,2) NOT NULL,
  sentiment_bucket         text NOT NULL,
  engagement_seconds       int NOT NULL,
  outcome                  text NOT NULL,
  followup_required        boolean NOT NULL DEFAULT false,
  remarks                  text,
  acknowledged_at          timestamptz NOT NULL DEFAULT now(),
  created_at               timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_ack_emoji_events_r2858 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_ack_emoji_events_r2858;
CREATE POLICY founder_all ON engineer_handover_ack_emoji_events_r2858
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- --------------------------------------------------------------
-- Table 2: monthly engineer rollups
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_handover_ack_emoji_rollups_r2858 (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code            text NOT NULL,
  engineer_name            text NOT NULL,
  rollup_month             date NOT NULL,
  total_handovers          int NOT NULL,
  ack_count                int NOT NULL,
  ack_rate_pct             numeric(5,2) NOT NULL,
  avg_sentiment            numeric(4,2) NOT NULL,
  avg_engagement_seconds   numeric(7,2) NOT NULL,
  positive_count           int NOT NULL,
  neutral_count            int NOT NULL,
  negative_count           int NOT NULL,
  top_emoji                text NOT NULL,
  rollup_grade             text NOT NULL,
  computed_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_ack_emoji_rollups_r2858 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handover_ack_emoji_rollups_r2858;
CREATE POLICY founder_all ON engineer_handover_ack_emoji_rollups_r2858
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- --------------------------------------------------------------
-- Seed events (8 rows)
-- --------------------------------------------------------------
INSERT INTO engineer_handover_ack_emoji_events_r2858
  (engineer_code, engineer_name, hospital_code, hospital_name, handover_month,
   emoji, emoji_label, sentiment_score, sentiment_bucket,
   engagement_seconds, outcome, followup_required, remarks, acknowledged_at)
VALUES
  ('ENG-001','Ravi Kumar','HSP-101','Apollo Madhapur','2026-05-01'::date,
   '😀','Delighted',0.92,'positive',48,'renewed_amc',false,'Loves monthly cadence','2026-06-02 09:14:00+05:30'),
  ('ENG-002','Sneha Iyer','HSP-102','KIMS Secunderabad','2026-05-01'::date,
   '🙂','Satisfied',0.71,'positive',32,'no_action',false,'Smooth handover','2026-06-03 10:02:00+05:30'),
  ('ENG-003','Arjun Mehta','HSP-103','Yashoda Somajiguda','2026-05-01'::date,
   '😐','Neutral',0.05,'neutral',18,'feedback_logged',true,'Wants faster spares','2026-06-03 11:30:00+05:30'),
  ('ENG-004','Pooja Reddy','HSP-104','Continental Gachibowli','2026-05-01'::date,
   '😟','Concerned',-0.42,'negative',64,'escalation_opened',true,'Defibrillator flagged','2026-06-04 16:45:00+05:30'),
  ('ENG-001','Ravi Kumar','HSP-105','Care Banjara','2026-05-01'::date,
   '🥳','Thrilled',0.97,'positive',55,'upsold_amc_pro',false,'Upgraded tier','2026-06-04 18:11:00+05:30'),
  ('ENG-005','Vikram Singh','HSP-106','Rainbow Hyderguda','2026-05-01'::date,
   '😤','Frustrated',-0.71,'negative',82,'incident_opened',true,'Repeat ventilator issue','2026-06-05 09:55:00+05:30'),
  ('ENG-002','Sneha Iyer','HSP-107','Sunshine Begumpet','2026-05-01'::date,
   '🙂','Satisfied',0.68,'positive',29,'no_action',false,'Consistent uptime','2026-06-05 12:20:00+05:30'),
  ('ENG-003','Arjun Mehta','HSP-108','Olive Hospital','2026-05-01'::date,
   '😐','Neutral',0.10,'neutral',22,'feedback_logged',true,'Asked for training','2026-06-06 10:10:00+05:30');

-- --------------------------------------------------------------
-- Seed rollups (5 rows)
-- --------------------------------------------------------------
INSERT INTO engineer_handover_ack_emoji_rollups_r2858
  (engineer_code, engineer_name, rollup_month, total_handovers, ack_count,
   ack_rate_pct, avg_sentiment, avg_engagement_seconds,
   positive_count, neutral_count, negative_count, top_emoji, rollup_grade)
VALUES
  ('ENG-001','Ravi Kumar','2026-05-01'::date,2,2,100.00,0.94,51.50,2,0,0,'🥳','A+'),
  ('ENG-002','Sneha Iyer','2026-05-01'::date,2,2,100.00,0.70,30.50,2,0,0,'🙂','A'),
  ('ENG-003','Arjun Mehta','2026-05-01'::date,2,2,100.00,0.08,20.00,0,2,0,'😐','C'),
  ('ENG-004','Pooja Reddy','2026-05-01'::date,1,1,100.00,-0.42,64.00,0,0,1,'😟','D'),
  ('ENG-005','Vikram Singh','2026-05-01'::date,1,1,100.00,-0.71,82.00,0,0,1,'😤','F');

-- =====================================================================
-- RPCs (7+ founder-gated)
-- =====================================================================

-- 1) KPI summary
DROP FUNCTION IF EXISTS founder_r2858_kpi_summary();
CREATE FUNCTION founder_r2858_kpi_summary()
RETURNS TABLE(
  total_events        int,
  total_engineers     int,
  positive_pct        numeric,
  neutral_pct         numeric,
  negative_pct        numeric,
  avg_sentiment       numeric,
  avg_engagement_sec  numeric,
  followups_open      int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(DISTINCT engineer_code)::int,
    ROUND(100.0 * SUM(CASE WHEN sentiment_bucket='positive' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * SUM(CASE WHEN sentiment_bucket='neutral'  THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * SUM(CASE WHEN sentiment_bucket='negative' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
    ROUND(AVG(sentiment_score)::numeric, 2),
    ROUND(AVG(engagement_seconds)::numeric, 2),
    SUM(CASE WHEN followup_required THEN 1 ELSE 0 END)::int
  FROM engineer_handover_ack_emoji_events_r2858;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_kpi_summary() TO authenticated;

-- 2) Engineer leaderboard
DROP FUNCTION IF EXISTS founder_r2858_engineer_leaderboard();
CREATE FUNCTION founder_r2858_engineer_leaderboard()
RETURNS TABLE(
  engineer_code   text,
  engineer_name   text,
  total_handovers int,
  avg_sentiment   numeric,
  ack_rate_pct    numeric,
  top_emoji       text,
  rollup_grade    text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_code, r.engineer_name, r.total_handovers,
         r.avg_sentiment, r.ack_rate_pct, r.top_emoji, r.rollup_grade
  FROM engineer_handover_ack_emoji_rollups_r2858 r
  ORDER BY r.avg_sentiment DESC, r.ack_rate_pct DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_engineer_leaderboard() TO authenticated;

-- 3) Emoji distribution
DROP FUNCTION IF EXISTS founder_r2858_emoji_distribution();
CREATE FUNCTION founder_r2858_emoji_distribution()
RETURNS TABLE(emoji text, emoji_label text, count int, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_handover_ack_emoji_events_r2858;
  RETURN QUERY
  SELECT e.emoji, MIN(e.emoji_label),
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*)::numeric / NULLIF(total,0), 2)
  FROM engineer_handover_ack_emoji_events_r2858 e
  GROUP BY e.emoji
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_emoji_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_emoji_distribution() TO authenticated;

-- 4) Sentiment buckets
DROP FUNCTION IF EXISTS founder_r2858_sentiment_buckets();
CREATE FUNCTION founder_r2858_sentiment_buckets()
RETURNS TABLE(sentiment_bucket text, count int, avg_engagement_seconds numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.sentiment_bucket,
         COUNT(*)::int,
         ROUND(AVG(e.engagement_seconds)::numeric, 2)
  FROM engineer_handover_ack_emoji_events_r2858 e
  GROUP BY e.sentiment_bucket
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_sentiment_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_sentiment_buckets() TO authenticated;

-- 5) Outcome breakdown
DROP FUNCTION IF EXISTS founder_r2858_outcome_breakdown();
CREATE FUNCTION founder_r2858_outcome_breakdown()
RETURNS TABLE(outcome text, count int, followups int, avg_sentiment numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.outcome,
         COUNT(*)::int,
         SUM(CASE WHEN e.followup_required THEN 1 ELSE 0 END)::int,
         ROUND(AVG(e.sentiment_score)::numeric, 2)
  FROM engineer_handover_ack_emoji_events_r2858 e
  GROUP BY e.outcome
  ORDER BY COUNT(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_outcome_breakdown() TO authenticated;

-- 6) Recent events
DROP FUNCTION IF EXISTS founder_r2858_recent_events();
CREATE FUNCTION founder_r2858_recent_events()
RETURNS TABLE(
  engineer_name    text,
  hospital_name    text,
  emoji            text,
  emoji_label      text,
  sentiment_score  numeric,
  outcome          text,
  acknowledged_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.hospital_name, e.emoji, e.emoji_label,
         e.sentiment_score, e.outcome, e.acknowledged_at
  FROM engineer_handover_ack_emoji_events_r2858 e
  ORDER BY e.acknowledged_at DESC
  LIMIT 25;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_recent_events() TO authenticated;

-- 7) Followup queue
DROP FUNCTION IF EXISTS founder_r2858_followup_queue();
CREATE FUNCTION founder_r2858_followup_queue()
RETURNS TABLE(
  engineer_name   text,
  hospital_name   text,
  emoji           text,
  outcome         text,
  remarks         text,
  acknowledged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.hospital_name, e.emoji,
         e.outcome, e.remarks, e.acknowledged_at
  FROM engineer_handover_ack_emoji_events_r2858 e
  WHERE e.followup_required = true
  ORDER BY e.acknowledged_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_followup_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_followup_queue() TO authenticated;

-- 8) Engagement bands
DROP FUNCTION IF EXISTS founder_r2858_engagement_bands();
CREATE FUNCTION founder_r2858_engagement_bands()
RETURNS TABLE(band text, count int, avg_sentiment numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN e.engagement_seconds < 20 THEN 'low (<20s)'
      WHEN e.engagement_seconds < 45 THEN 'mid (20-44s)'
      ELSE 'high (>=45s)'
    END AS band,
    COUNT(*)::int,
    ROUND(AVG(e.sentiment_score)::numeric, 2)
  FROM engineer_handover_ack_emoji_events_r2858 e
  GROUP BY band
  ORDER BY band;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_r2858_engagement_bands() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2858_engagement_bands() TO authenticated;

COMMIT;
