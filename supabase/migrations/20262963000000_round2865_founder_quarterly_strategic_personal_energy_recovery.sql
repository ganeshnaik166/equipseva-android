BEGIN;

-- Round 2865: Founder Quarterly Strategic Personal Energy Recovery
-- Tracks recovery activities, their hours, energy delta, correlations, commits, verdicts

CREATE TABLE IF NOT EXISTS founder_energy_recovery_activities_r2865 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  activity_name text NOT NULL,
  category text NOT NULL CHECK (category IN ('physical','mental','social','creative','rest','nature')),
  hours_invested numeric(6,2) NOT NULL CHECK (hours_invested >= 0),
  energy_before_score int NOT NULL CHECK (energy_before_score BETWEEN 1 AND 10),
  energy_after_score int NOT NULL CHECK (energy_after_score BETWEEN 1 AND 10),
  energy_delta int GENERATED ALWAYS AS (energy_after_score - energy_before_score) STORED,
  correlation_with_output numeric(4,3) NOT NULL CHECK (correlation_with_output BETWEEN -1 AND 1),
  commit_next_quarter boolean NOT NULL DEFAULT false,
  verdict text NOT NULL CHECK (verdict IN ('double_down','keep','reduce','drop','experiment')),
  notes text,
  logged_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_energy_recovery_activities_r2865 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_energy_recovery_activities_r2865;
CREATE POLICY founder_all ON founder_energy_recovery_activities_r2865
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_energy_recovery_weekly_log_r2865 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_starting date NOT NULL,
  activity_id uuid NOT NULL REFERENCES founder_energy_recovery_activities_r2865(id) ON DELETE CASCADE,
  hours_this_week numeric(5,2) NOT NULL CHECK (hours_this_week >= 0),
  energy_rating_end_of_week int NOT NULL CHECK (energy_rating_end_of_week BETWEEN 1 AND 10),
  output_units_shipped int NOT NULL DEFAULT 0 CHECK (output_units_shipped >= 0),
  reflection_note text,
  consistency_flag text NOT NULL CHECK (consistency_flag IN ('on_track','behind','ahead','skipped')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_energy_recovery_weekly_log_r2865 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_energy_recovery_weekly_log_r2865;
CREATE POLICY founder_all ON founder_energy_recovery_weekly_log_r2865
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed activities (5+ rows)
INSERT INTO founder_energy_recovery_activities_r2865
  (quarter, activity_name, category, hours_invested, energy_before_score, energy_after_score, correlation_with_output, commit_next_quarter, verdict, notes)
VALUES
  ('Q2-2026','Morning run 5km','physical',32.0,4,8,0.720,true,'double_down','Highest correlation with ship velocity'),
  ('Q2-2026','Deep meditation 20m','mental',18.5,5,8,0.610,true,'double_down','Cuts decision fatigue'),
  ('Q2-2026','Family dinner phone-off','social',24.0,5,9,0.540,true,'keep','Refills emotional reserve'),
  ('Q2-2026','Sketching infra diagrams','creative',12.0,6,7,0.220,false,'experiment','Unclear if it really helps'),
  ('Q2-2026','Full Sunday off-grid','rest',40.0,3,9,0.810,true,'double_down','Strongest single lever'),
  ('Q2-2026','Hyderabad lake walk','nature',16.0,5,8,0.470,true,'keep','Good but weather-bound'),
  ('Q2-2026','Late-night doomscroll','rest',9.5,5,3,-0.620,false,'drop','Net-negative, drops next-day output');

INSERT INTO founder_energy_recovery_weekly_log_r2865
  (week_starting, activity_id, hours_this_week, energy_rating_end_of_week, output_units_shipped, reflection_note, consistency_flag)
SELECT '2026-06-01'::date, id, 2.5, 8, 28, 'Strong week', 'on_track' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Morning run 5km'
UNION ALL
SELECT '2026-06-08'::date, id, 3.0, 9, 32, 'Best week of quarter', 'ahead' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Morning run 5km'
UNION ALL
SELECT '2026-06-01'::date, id, 1.5, 7, 24, 'Steady meditation', 'on_track' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Deep meditation 20m'
UNION ALL
SELECT '2026-06-08'::date, id, 2.0, 8, 30, 'Helped on Tuesday spike', 'on_track' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Deep meditation 20m'
UNION ALL
SELECT '2026-06-15'::date, id, 8.0, 9, 0, 'Full off-grid Sunday', 'on_track' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Full Sunday off-grid'
UNION ALL
SELECT '2026-06-01'::date, id, 1.0, 4, 18, 'Slipped mid-week', 'behind' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Late-night doomscroll'
UNION ALL
SELECT '2026-06-15'::date, id, 0.0, 7, 26, 'Skipped, output up', 'skipped' FROM founder_energy_recovery_activities_r2865 WHERE activity_name = 'Late-night doomscroll';

-- RPCs (7+)

DROP FUNCTION IF EXISTS f_r2865_energy_activities();
CREATE OR REPLACE FUNCTION f_r2865_energy_activities()
RETURNS TABLE (
  id uuid,
  activity_name text,
  category text,
  hours_invested numeric,
  energy_before_score int,
  energy_after_score int,
  energy_delta int,
  correlation_with_output numeric,
  commit_next_quarter boolean,
  verdict text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.activity_name, a.category, a.hours_invested,
         a.energy_before_score, a.energy_after_score, a.energy_delta,
         a.correlation_with_output, a.commit_next_quarter, a.verdict, a.notes
  FROM founder_energy_recovery_activities_r2865 a
  ORDER BY a.correlation_with_output DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_activities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_activities() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_kpis();
CREATE OR REPLACE FUNCTION f_r2865_energy_kpis()
RETURNS TABLE (
  total_activities bigint,
  total_hours numeric,
  avg_energy_delta numeric,
  avg_correlation numeric,
  commit_count bigint,
  drop_count bigint,
  double_down_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(hours_invested),0)::numeric,
    coalesce(avg(energy_delta),0)::numeric,
    coalesce(avg(correlation_with_output),0)::numeric,
    count(*) FILTER (WHERE commit_next_quarter)::bigint,
    count(*) FILTER (WHERE verdict = 'drop')::bigint,
    count(*) FILTER (WHERE verdict = 'double_down')::bigint
  FROM founder_energy_recovery_activities_r2865;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_kpis() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_by_category();
CREATE OR REPLACE FUNCTION f_r2865_energy_by_category()
RETURNS TABLE (
  category text,
  activities bigint,
  hours numeric,
  avg_delta numeric,
  avg_correlation numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.category,
         count(*)::bigint,
         sum(a.hours_invested)::numeric,
         avg(a.energy_delta)::numeric,
         avg(a.correlation_with_output)::numeric
  FROM founder_energy_recovery_activities_r2865 a
  GROUP BY a.category
  ORDER BY avg(a.correlation_with_output) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_by_category() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_top_double_down();
CREATE OR REPLACE FUNCTION f_r2865_energy_top_double_down()
RETURNS TABLE (
  activity_name text,
  category text,
  correlation_with_output numeric,
  energy_delta int,
  hours_invested numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.activity_name, a.category, a.correlation_with_output, a.energy_delta, a.hours_invested
  FROM founder_energy_recovery_activities_r2865 a
  WHERE a.verdict = 'double_down'
  ORDER BY a.correlation_with_output DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_top_double_down() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_top_double_down() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_drops();
CREATE OR REPLACE FUNCTION f_r2865_energy_drops()
RETURNS TABLE (
  activity_name text,
  category text,
  correlation_with_output numeric,
  energy_delta int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.activity_name, a.category, a.correlation_with_output, a.energy_delta, a.notes
  FROM founder_energy_recovery_activities_r2865 a
  WHERE a.verdict IN ('drop','reduce')
  ORDER BY a.correlation_with_output ASC;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_drops() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_drops() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_weekly_log();
CREATE OR REPLACE FUNCTION f_r2865_energy_weekly_log()
RETURNS TABLE (
  week_starting date,
  activity_name text,
  hours_this_week numeric,
  energy_rating_end_of_week int,
  output_units_shipped int,
  consistency_flag text,
  reflection_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.week_starting, a.activity_name, w.hours_this_week,
         w.energy_rating_end_of_week, w.output_units_shipped,
         w.consistency_flag, w.reflection_note
  FROM founder_energy_recovery_weekly_log_r2865 w
  JOIN founder_energy_recovery_activities_r2865 a ON a.id = w.activity_id
  ORDER BY w.week_starting DESC, a.activity_name;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_weekly_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_weekly_log() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_consistency_summary();
CREATE OR REPLACE FUNCTION f_r2865_energy_consistency_summary()
RETURNS TABLE (
  consistency_flag text,
  weeks bigint,
  total_hours numeric,
  total_output int,
  avg_energy numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.consistency_flag,
         count(*)::bigint,
         sum(w.hours_this_week)::numeric,
         sum(w.output_units_shipped)::int,
         avg(w.energy_rating_end_of_week)::numeric
  FROM founder_energy_recovery_weekly_log_r2865 w
  GROUP BY w.consistency_flag
  ORDER BY sum(w.output_units_shipped) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_consistency_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_consistency_summary() TO authenticated;

DROP FUNCTION IF EXISTS f_r2865_energy_quarter_verdict();
CREATE OR REPLACE FUNCTION f_r2865_energy_quarter_verdict()
RETURNS TABLE (
  verdict text,
  activities bigint,
  hours numeric,
  avg_correlation numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.verdict,
         count(*)::bigint,
         sum(a.hours_invested)::numeric,
         avg(a.correlation_with_output)::numeric
  FROM founder_energy_recovery_activities_r2865 a
  GROUP BY a.verdict
  ORDER BY avg(a.correlation_with_output) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION f_r2865_energy_quarter_verdict() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION f_r2865_energy_quarter_verdict() TO authenticated;

COMMIT;
