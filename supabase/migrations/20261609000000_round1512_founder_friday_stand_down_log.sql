BEGIN;

-- ============================================================================
-- r1512 — Founder Friday Stand-Down Log
-- Opposite of standup: end-of-week review (shipped/slipped/learned + mood)
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_friday_stand_down_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_ending date NOT NULL UNIQUE,
  founder_user_id uuid NOT NULL REFERENCES auth.users(id),
  what_shipped text NOT NULL DEFAULT '',
  what_slipped text NOT NULL DEFAULT '',
  what_learned text NOT NULL DEFAULT '',
  ships_count int NOT NULL DEFAULT 0,
  slips_count int NOT NULL DEFAULT 0,
  mood_score int NOT NULL DEFAULT 5 CHECK (mood_score BETWEEN 1 AND 10),
  energy_score int NOT NULL DEFAULT 5 CHECK (energy_score BETWEEN 1 AND 10),
  focus_score int NOT NULL DEFAULT 5 CHECK (focus_score BETWEEN 1 AND 10),
  burnout_risk text NOT NULL DEFAULT 'low' CHECK (burnout_risk IN ('low','medium','high','critical')),
  next_week_priority text NOT NULL DEFAULT '',
  weekend_recharge_plan text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_friday_stand_down_v2_week ON founder_friday_stand_down_v2(week_ending DESC);

ALTER TABLE founder_friday_stand_down_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS friday_stand_down_v2_founder ON founder_friday_stand_down_v2;
CREATE POLICY friday_stand_down_v2_founder ON founder_friday_stand_down_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_friday_journal_entries_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stand_down_id uuid NOT NULL REFERENCES founder_friday_stand_down_v2(id) ON DELETE CASCADE,
  entry_kind text NOT NULL CHECK (entry_kind IN ('win','loss','lesson','gratitude','worry')),
  entry_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_friday_journal_v2_stand_down ON founder_friday_journal_entries_v2(stand_down_id);
CREATE INDEX IF NOT EXISTS idx_friday_journal_v2_kind ON founder_friday_journal_entries_v2(entry_kind);

ALTER TABLE founder_friday_journal_entries_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS friday_journal_v2_founder ON founder_friday_journal_entries_v2;
CREATE POLICY friday_journal_v2_founder ON founder_friday_journal_entries_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION friday_stand_down_summary_v2()
RETURNS TABLE(
  total_weeks bigint,
  avg_mood numeric,
  avg_energy numeric,
  avg_focus numeric,
  total_ships bigint,
  total_slips bigint,
  weeks_high_burnout bigint,
  weeks_low_mood bigint,
  last_week_ending date,
  last_mood int,
  last_energy int,
  ships_last_week int,
  slips_last_week int,
  total_journal_entries bigint,
  total_wins bigint,
  total_losses bigint,
  total_lessons bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT * FROM founder_friday_stand_down_v2 ORDER BY week_ending DESC LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM founder_friday_stand_down_v2),
    (SELECT round(avg(mood_score)::numeric, 2) FROM founder_friday_stand_down_v2),
    (SELECT round(avg(energy_score)::numeric, 2) FROM founder_friday_stand_down_v2),
    (SELECT round(avg(focus_score)::numeric, 2) FROM founder_friday_stand_down_v2),
    (SELECT COALESCE(sum(ships_count), 0) FROM founder_friday_stand_down_v2),
    (SELECT COALESCE(sum(slips_count), 0) FROM founder_friday_stand_down_v2),
    (SELECT count(*) FROM founder_friday_stand_down_v2 WHERE burnout_risk IN ('high','critical')),
    (SELECT count(*) FROM founder_friday_stand_down_v2 WHERE mood_score <= 4),
    (SELECT week_ending FROM latest),
    (SELECT mood_score FROM latest),
    (SELECT energy_score FROM latest),
    (SELECT ships_count FROM latest),
    (SELECT slips_count FROM latest),
    (SELECT count(*) FROM founder_friday_journal_entries_v2),
    (SELECT count(*) FROM founder_friday_journal_entries_v2 WHERE entry_kind = 'win'),
    (SELECT count(*) FROM founder_friday_journal_entries_v2 WHERE entry_kind = 'loss'),
    (SELECT count(*) FROM founder_friday_journal_entries_v2 WHERE entry_kind = 'lesson');
END $$;

REVOKE EXECUTE ON FUNCTION friday_stand_down_summary_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION friday_stand_down_summary_v2() TO authenticated;

CREATE OR REPLACE FUNCTION friday_stand_down_recent_v2()
RETURNS TABLE(
  id uuid,
  week_ending date,
  ships_count int,
  slips_count int,
  mood_score int,
  energy_score int,
  focus_score int,
  burnout_risk text,
  next_week_priority text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.week_ending, s.ships_count, s.slips_count, s.mood_score,
         s.energy_score, s.focus_score, s.burnout_risk, s.next_week_priority, s.created_at
  FROM founder_friday_stand_down_v2 s
  ORDER BY s.week_ending DESC
  LIMIT 12;
END $$;

REVOKE EXECUTE ON FUNCTION friday_stand_down_recent_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION friday_stand_down_recent_v2() TO authenticated;

CREATE OR REPLACE FUNCTION friday_mood_trend_v2()
RETURNS TABLE(
  week_ending date,
  mood_score int,
  energy_score int,
  focus_score int,
  burnout_risk text,
  delta_mood int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.week_ending, s.mood_score, s.energy_score, s.focus_score, s.burnout_risk,
         (s.mood_score - LAG(s.mood_score) OVER (ORDER BY s.week_ending))::int AS delta_mood
  FROM founder_friday_stand_down_v2 s
  ORDER BY s.week_ending DESC
  LIMIT 16;
END $$;

REVOKE EXECUTE ON FUNCTION friday_mood_trend_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION friday_mood_trend_v2() TO authenticated;

CREATE OR REPLACE FUNCTION friday_journal_recent_v2()
RETURNS TABLE(
  id uuid,
  week_ending date,
  entry_kind text,
  entry_text text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, s.week_ending, j.entry_kind, j.entry_text, j.created_at
  FROM founder_friday_journal_entries_v2 j
  JOIN founder_friday_stand_down_v2 s ON s.id = j.stand_down_id
  ORDER BY j.created_at DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION friday_journal_recent_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION friday_journal_recent_v2() TO authenticated;

CREATE OR REPLACE FUNCTION friday_ship_slip_log_v2()
RETURNS TABLE(
  id uuid,
  week_ending date,
  what_shipped text,
  what_slipped text,
  what_learned text,
  ships_count int,
  slips_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.week_ending, s.what_shipped, s.what_slipped, s.what_learned,
         s.ships_count, s.slips_count
  FROM founder_friday_stand_down_v2 s
  ORDER BY s.week_ending DESC
  LIMIT 12;
END $$;

REVOKE EXECUTE ON FUNCTION friday_ship_slip_log_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION friday_ship_slip_log_v2() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_friday_stand_down_v2(
  p_week_ending date,
  p_what_shipped text,
  p_what_slipped text,
  p_what_learned text,
  p_ships_count int,
  p_slips_count int,
  p_mood int,
  p_energy int,
  p_focus int,
  p_burnout text,
  p_next_priority text,
  p_recharge text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_friday_stand_down_v2 (
    week_ending, founder_user_id, what_shipped, what_slipped, what_learned,
    ships_count, slips_count, mood_score, energy_score, focus_score,
    burnout_risk, next_week_priority, weekend_recharge_plan
  ) VALUES (
    p_week_ending, auth.uid(), p_what_shipped, p_what_slipped, p_what_learned,
    p_ships_count, p_slips_count, p_mood, p_energy, p_focus,
    p_burnout, p_next_priority, p_recharge
  )
  ON CONFLICT (week_ending) DO UPDATE SET
    what_shipped = EXCLUDED.what_shipped,
    what_slipped = EXCLUDED.what_slipped,
    what_learned = EXCLUDED.what_learned,
    ships_count = EXCLUDED.ships_count,
    slips_count = EXCLUDED.slips_count,
    mood_score = EXCLUDED.mood_score,
    energy_score = EXCLUDED.energy_score,
    focus_score = EXCLUDED.focus_score,
    burnout_risk = EXCLUDED.burnout_risk,
    next_week_priority = EXCLUDED.next_week_priority,
    weekend_recharge_plan = EXCLUDED.weekend_recharge_plan,
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_friday_stand_down_v2',
    jsonb_build_object('stand_down_id', v_id, 'week_ending', p_week_ending, 'mood', p_mood, 'energy', p_energy)
  );

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_friday_stand_down_v2(date,text,text,text,int,int,int,int,int,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_friday_stand_down_v2(date,text,text,text,int,int,int,int,int,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_friday_journal_entry_v2(
  p_stand_down_id uuid,
  p_entry_kind text,
  p_entry_text text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_friday_journal_entries_v2 (stand_down_id, entry_kind, entry_text)
  VALUES (p_stand_down_id, p_entry_kind, p_entry_text)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_friday_journal_entry_v2',
    jsonb_build_object('journal_id', v_id, 'stand_down_id', p_stand_down_id, 'kind', p_entry_kind)
  );

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_friday_journal_entry_v2(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_friday_journal_entry_v2(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_friday_mood_check_v2(
  p_week_ending date,
  p_note text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_log_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_log_id := gen_random_uuid();
  INSERT INTO founder_action_log (id, actor_user_id, actor_email, op_name, after_value)
  VALUES (
    v_log_id,
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_friday_mood_check_v2',
    jsonb_build_object('week_ending', p_week_ending, 'note', p_note, 'checked_at', now())
  );
  RETURN v_log_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_friday_mood_check_v2(date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_friday_mood_check_v2(date,text) TO authenticated;

COMMIT;