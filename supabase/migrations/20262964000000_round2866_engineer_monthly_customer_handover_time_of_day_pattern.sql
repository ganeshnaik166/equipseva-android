BEGIN;

-- ============================================================================
-- Round 2866 — Engineer monthly customer handover time-of-day pattern
-- HEAVY: engineer x handover x time-of-day x customer impression x engagement x outcome
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: engineer monthly handover time-of-day slots
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_handover_time_of_day_slots_r2866 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  time_of_day_slot text NOT NULL CHECK (time_of_day_slot IN ('early_morning','morning','midday','afternoon','evening','night')),
  slot_window_label text NOT NULL,
  handovers_count int NOT NULL DEFAULT 0,
  avg_handover_minutes numeric(6,2) NOT NULL DEFAULT 0,
  avg_customer_impression numeric(4,2) NOT NULL DEFAULT 0,
  engagement_minutes_avg numeric(6,2) NOT NULL DEFAULT 0,
  outcome_label text NOT NULL CHECK (outcome_label IN ('excellent','good','adequate','poor','escalated')),
  amc_attach_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_handover_time_of_day_slots_r2866 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_handover_time_of_day_slots_r2866;
CREATE POLICY founder_all ON engineer_monthly_handover_time_of_day_slots_r2866
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_handover_time_of_day_slots_r2866
  (month_label, engineer_name, engineer_tier, time_of_day_slot, slot_window_label, handovers_count, avg_handover_minutes, avg_customer_impression, engagement_minutes_avg, outcome_label, amc_attach_rate_pct, notes)
VALUES
  ('2026-06','Ravi Kumar','platinum','morning','08:00-11:00',14,32.50,4.70,18.40,'excellent',71.20,'morning peak best impressions'),
  ('2026-06','Ravi Kumar','platinum','afternoon','13:00-16:00',9,38.20,4.30,15.10,'good',58.40,'post-lunch dip mild'),
  ('2026-06','Sunita Reddy','gold','early_morning','06:00-08:00',6,29.80,4.85,21.30,'excellent',82.50,'early calls love attention'),
  ('2026-06','Sunita Reddy','gold','evening','17:00-20:00',11,41.60,3.90,12.80,'adequate',44.10,'evening rushed handovers'),
  ('2026-06','Arjun Pillai','silver','midday','11:00-13:00',8,35.70,4.20,16.50,'good',51.30,'midday solid steady'),
  ('2026-06','Arjun Pillai','silver','night','20:00-23:00',3,48.10,3.40,9.20,'poor',22.40,'night fatigue evident'),
  ('2026-06','Meera Joshi','bronze','morning','08:00-11:00',7,44.30,3.70,11.10,'adequate',31.80,'new hire learning curve'),
  ('2026-06','Meera Joshi','bronze','afternoon','13:00-16:00',5,52.40,3.20,8.40,'escalated',18.20,'afternoon escalations spike');

-- ---------------------------------------------------------------------------
-- Table 2: monthly time-of-day customer pattern signals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monthly_handover_time_of_day_pattern_signals_r2866 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  time_of_day_slot text NOT NULL CHECK (time_of_day_slot IN ('early_morning','morning','midday','afternoon','evening','night')),
  pattern_signal text NOT NULL CHECK (pattern_signal IN ('peak_excellence','steady_quality','transition_dip','energy_drain','recovery_surge','quiet_focus')),
  customer_mood text NOT NULL CHECK (customer_mood IN ('delighted','satisfied','neutral','impatient','frustrated')),
  engagement_band text NOT NULL CHECK (engagement_band IN ('deep','active','passive','distracted','disengaged')),
  outcome_trend text NOT NULL CHECK (outcome_trend IN ('rising','stable','wobbling','declining','recovering')),
  total_handovers int NOT NULL DEFAULT 0,
  median_impression numeric(4,2) NOT NULL DEFAULT 0,
  recommended_action text NOT NULL DEFAULT '',
  observed_on date NOT NULL DEFAULT now()::date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE monthly_handover_time_of_day_pattern_signals_r2866 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON monthly_handover_time_of_day_pattern_signals_r2866;
CREATE POLICY founder_all ON monthly_handover_time_of_day_pattern_signals_r2866
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO monthly_handover_time_of_day_pattern_signals_r2866
  (month_label, time_of_day_slot, pattern_signal, customer_mood, engagement_band, outcome_trend, total_handovers, median_impression, recommended_action, observed_on)
VALUES
  ('2026-06','morning','peak_excellence','delighted','deep','rising',42,4.65,'staff senior engineers morning','2026-06-05'::date),
  ('2026-06','early_morning','quiet_focus','satisfied','active','stable',18,4.50,'reserve slots for high-AMC accounts','2026-06-07'::date),
  ('2026-06','midday','steady_quality','satisfied','active','stable',26,4.20,'maintain current rotation','2026-06-10'::date),
  ('2026-06','afternoon','transition_dip','neutral','passive','wobbling',31,3.85,'add 10-min break before slot','2026-06-12'::date),
  ('2026-06','evening','energy_drain','impatient','distracted','declining',38,3.60,'cap evening load at 3 per engineer','2026-06-15'::date),
  ('2026-06','night','energy_drain','frustrated','disengaged','declining',9,3.20,'avoid scheduling new customer handovers at night','2026-06-18'::date),
  ('2026-05','morning','peak_excellence','delighted','deep','rising',39,4.60,'continue morning concentration','2026-05-20'::date);

-- ---------------------------------------------------------------------------
-- RPC 1: list engineer slot rows
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_engineer_handover_time_slots_r2866(text);
CREATE OR REPLACE FUNCTION list_engineer_handover_time_slots_r2866(p_month text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  month_label text,
  engineer_name text,
  engineer_tier text,
  time_of_day_slot text,
  slot_window_label text,
  handovers_count int,
  avg_handover_minutes numeric,
  avg_customer_impression numeric,
  engagement_minutes_avg numeric,
  outcome_label text,
  amc_attach_rate_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.month_label, s.engineer_name, s.engineer_tier, s.time_of_day_slot,
           s.slot_window_label, s.handovers_count, s.avg_handover_minutes,
           s.avg_customer_impression, s.engagement_minutes_avg, s.outcome_label,
           s.amc_attach_rate_pct, s.notes
      FROM engineer_monthly_handover_time_of_day_slots_r2866 s
     WHERE p_month IS NULL OR s.month_label = p_month
     ORDER BY s.engineer_name, s.time_of_day_slot;
END $$;
REVOKE EXECUTE ON FUNCTION list_engineer_handover_time_slots_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_engineer_handover_time_slots_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: list pattern signals
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_handover_time_pattern_signals_r2866(text);
CREATE OR REPLACE FUNCTION list_handover_time_pattern_signals_r2866(p_month text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  month_label text,
  time_of_day_slot text,
  pattern_signal text,
  customer_mood text,
  engagement_band text,
  outcome_trend text,
  total_handovers int,
  median_impression numeric,
  recommended_action text,
  observed_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.month_label, p.time_of_day_slot, p.pattern_signal,
           p.customer_mood, p.engagement_band, p.outcome_trend,
           p.total_handovers, p.median_impression, p.recommended_action, p.observed_on
      FROM monthly_handover_time_of_day_pattern_signals_r2866 p
     WHERE p_month IS NULL OR p.month_label = p_month
     ORDER BY p.time_of_day_slot;
END $$;
REVOKE EXECUTE ON FUNCTION list_handover_time_pattern_signals_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_handover_time_pattern_signals_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: KPI summary
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS kpi_handover_time_pattern_r2866(text);
CREATE OR REPLACE FUNCTION kpi_handover_time_pattern_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  total_handovers int,
  avg_impression numeric,
  avg_engagement_minutes numeric,
  best_slot text,
  worst_slot text,
  excellent_slot_count int,
  escalated_slot_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_best text;
  v_worst text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT s.time_of_day_slot INTO v_best
    FROM engineer_monthly_handover_time_of_day_slots_r2866 s
   WHERE s.month_label = p_month
   GROUP BY s.time_of_day_slot
   ORDER BY AVG(s.avg_customer_impression) DESC NULLS LAST
   LIMIT 1;

  SELECT s.time_of_day_slot INTO v_worst
    FROM engineer_monthly_handover_time_of_day_slots_r2866 s
   WHERE s.month_label = p_month
   GROUP BY s.time_of_day_slot
   ORDER BY AVG(s.avg_customer_impression) ASC NULLS LAST
   LIMIT 1;

  RETURN QUERY
    SELECT COALESCE(SUM(s.handovers_count),0)::int,
           ROUND(AVG(s.avg_customer_impression)::numeric,2),
           ROUND(AVG(s.engagement_minutes_avg)::numeric,2),
           COALESCE(v_best,'n/a'),
           COALESCE(v_worst,'n/a'),
           COUNT(*) FILTER (WHERE s.outcome_label = 'excellent')::int,
           COUNT(*) FILTER (WHERE s.outcome_label = 'escalated')::int
      FROM engineer_monthly_handover_time_of_day_slots_r2866 s
     WHERE s.month_label = p_month;
END $$;
REVOKE EXECUTE ON FUNCTION kpi_handover_time_pattern_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION kpi_handover_time_pattern_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: time-of-day rollup
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS rollup_time_of_day_r2866(text);
CREATE OR REPLACE FUNCTION rollup_time_of_day_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  time_of_day_slot text,
  handovers int,
  avg_impression numeric,
  avg_engagement_minutes numeric,
  avg_attach_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.time_of_day_slot,
           COALESCE(SUM(s.handovers_count),0)::int,
           ROUND(AVG(s.avg_customer_impression)::numeric,2),
           ROUND(AVG(s.engagement_minutes_avg)::numeric,2),
           ROUND(AVG(s.amc_attach_rate_pct)::numeric,2)
      FROM engineer_monthly_handover_time_of_day_slots_r2866 s
     WHERE s.month_label = p_month
     GROUP BY s.time_of_day_slot
     ORDER BY s.time_of_day_slot;
END $$;
REVOKE EXECUTE ON FUNCTION rollup_time_of_day_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rollup_time_of_day_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: engineer leaderboard
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS engineer_leaderboard_handover_r2866(text);
CREATE OR REPLACE FUNCTION engineer_leaderboard_handover_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  total_handovers int,
  avg_impression numeric,
  best_slot text,
  amc_attach_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    WITH agg AS (
      SELECT s.engineer_name, s.engineer_tier,
             SUM(s.handovers_count) AS total_h,
             AVG(s.avg_customer_impression) AS avg_imp,
             AVG(s.amc_attach_rate_pct) AS avg_attach
        FROM engineer_monthly_handover_time_of_day_slots_r2866 s
       WHERE s.month_label = p_month
       GROUP BY s.engineer_name, s.engineer_tier
    ),
    best AS (
      SELECT DISTINCT ON (s.engineer_name) s.engineer_name, s.time_of_day_slot
        FROM engineer_monthly_handover_time_of_day_slots_r2866 s
       WHERE s.month_label = p_month
       ORDER BY s.engineer_name, s.avg_customer_impression DESC
    )
    SELECT a.engineer_name, a.engineer_tier,
           a.total_h::int,
           ROUND(a.avg_imp::numeric,2),
           COALESCE(b.time_of_day_slot,'n/a'),
           ROUND(a.avg_attach::numeric,2)
      FROM agg a
      LEFT JOIN best b ON b.engineer_name = a.engineer_name
     ORDER BY avg_imp DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION engineer_leaderboard_handover_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION engineer_leaderboard_handover_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: outcome distribution
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS outcome_distribution_handover_r2866(text);
CREATE OR REPLACE FUNCTION outcome_distribution_handover_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  outcome_label text,
  slot_count int,
  total_handovers int,
  avg_impression numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.outcome_label,
           COUNT(*)::int,
           COALESCE(SUM(s.handovers_count),0)::int,
           ROUND(AVG(s.avg_customer_impression)::numeric,2)
      FROM engineer_monthly_handover_time_of_day_slots_r2866 s
     WHERE s.month_label = p_month
     GROUP BY s.outcome_label
     ORDER BY avg_impression DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION outcome_distribution_handover_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION outcome_distribution_handover_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: pattern mood band
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS pattern_mood_band_r2866(text);
CREATE OR REPLACE FUNCTION pattern_mood_band_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  customer_mood text,
  engagement_band text,
  slot_count int,
  total_handovers int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.customer_mood, p.engagement_band,
           COUNT(*)::int,
           COALESCE(SUM(p.total_handovers),0)::int
      FROM monthly_handover_time_of_day_pattern_signals_r2866 p
     WHERE p.month_label = p_month
     GROUP BY p.customer_mood, p.engagement_band
     ORDER BY p.customer_mood;
END $$;
REVOKE EXECUTE ON FUNCTION pattern_mood_band_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION pattern_mood_band_r2866(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: recommended actions list
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS recommended_actions_handover_r2866(text);
CREATE OR REPLACE FUNCTION recommended_actions_handover_r2866(p_month text DEFAULT '2026-06')
RETURNS TABLE (
  time_of_day_slot text,
  pattern_signal text,
  outcome_trend text,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.time_of_day_slot, p.pattern_signal, p.outcome_trend, p.recommended_action
      FROM monthly_handover_time_of_day_pattern_signals_r2866 p
     WHERE p.month_label = p_month
     ORDER BY p.time_of_day_slot;
END $$;
REVOKE EXECUTE ON FUNCTION recommended_actions_handover_r2866(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION recommended_actions_handover_r2866(text) TO authenticated;

COMMIT;
