BEGIN;

-- Round 1576: Founder investor demo day prep tracker
-- Tables for accelerator demo day prep: deck slots, 5-min pitch, 1-on-1 schedule + rehearsal log

CREATE TABLE IF NOT EXISTS founder_demo_day_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accelerator_name text NOT NULL,
  cohort_label text,
  demo_day_date date,
  city text,
  country text DEFAULT 'India',
  deck_slot_minutes int NOT NULL DEFAULT 5,
  deck_url text,
  pitch_status text NOT NULL DEFAULT 'draft' CHECK (pitch_status IN ('draft','rehearsing','final','delivered','cancelled')),
  one_on_one_count int NOT NULL DEFAULT 0,
  one_on_one_schedule_url text,
  expected_investor_count int,
  priority text NOT NULL DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  founder_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_demo_day_rehearsals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid REFERENCES founder_demo_day_targets(id) ON DELETE CASCADE,
  rehearsed_at timestamptz NOT NULL DEFAULT now(),
  duration_seconds int NOT NULL DEFAULT 300,
  self_score int CHECK (self_score BETWEEN 1 AND 10),
  weak_slide_numbers int[] DEFAULT ARRAY[]::int[],
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_demo_day_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_demo_day_rehearsals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS demo_day_targets_founder_only ON founder_demo_day_targets;
CREATE POLICY demo_day_targets_founder_only ON founder_demo_day_targets
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS demo_day_rehearsals_founder_only ON founder_demo_day_rehearsals;
CREATE POLICY demo_day_rehearsals_founder_only ON founder_demo_day_rehearsals
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================================
-- READ RPCs (STABLE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_demo_day_target_list()
RETURNS TABLE(id uuid, accelerator_name text, cohort_label text, demo_day_date date, city text, country text,
              deck_slot_minutes int, deck_url text, pitch_status text, one_on_one_count int,
              expected_investor_count int, priority text, days_until int, updated_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.accelerator_name, t.cohort_label, t.demo_day_date, t.city, t.country,
         t.deck_slot_minutes, t.deck_url, t.pitch_status, t.one_on_one_count,
         t.expected_investor_count, t.priority,
         CASE WHEN t.demo_day_date IS NOT NULL THEN (t.demo_day_date - CURRENT_DATE)::int ELSE NULL END,
         t.updated_at
  FROM founder_demo_day_targets t
  ORDER BY COALESCE(t.demo_day_date, CURRENT_DATE + 365) ASC, t.priority ASC;
END; $$;

CREATE OR REPLACE FUNCTION founder_demo_day_upcoming_30d()
RETURNS TABLE(id uuid, accelerator_name text, demo_day_date date, days_until int, pitch_status text, priority text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.accelerator_name, t.demo_day_date,
         (t.demo_day_date - CURRENT_DATE)::int, t.pitch_status, t.priority
  FROM founder_demo_day_targets t
  WHERE t.demo_day_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
  ORDER BY t.demo_day_date ASC;
END; $$;

CREATE OR REPLACE FUNCTION founder_demo_day_rehearsal_log(p_target_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid, target_id uuid, accelerator_name text, rehearsed_at timestamptz, duration_seconds int,
              self_score int, weak_slide_count int, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.target_id, t.accelerator_name, r.rehearsed_at, r.duration_seconds,
         r.self_score, COALESCE(array_length(r.weak_slide_numbers, 1), 0), r.notes
  FROM founder_demo_day_rehearsals r
  LEFT JOIN founder_demo_day_targets t ON t.id = r.target_id
  WHERE p_target_id IS NULL OR r.target_id = p_target_id
  ORDER BY r.rehearsed_at DESC
  LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION founder_demo_day_kpi_snapshot()
RETURNS TABLE(total_targets int, p0_targets int, upcoming_30d int, finalized_pitches int,
              total_rehearsals_30d int, avg_self_score numeric, total_1on1_slots int,
              targets_missing_deck int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM founder_demo_day_targets),
    (SELECT COUNT(*)::int FROM founder_demo_day_targets WHERE priority = 'p0'),
    (SELECT COUNT(*)::int FROM founder_demo_day_targets WHERE demo_day_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30),
    (SELECT COUNT(*)::int FROM founder_demo_day_targets WHERE pitch_status = 'final'),
    (SELECT COUNT(*)::int FROM founder_demo_day_rehearsals WHERE rehearsed_at > now() - interval '30 days'),
    (SELECT ROUND(AVG(self_score)::numeric, 2) FROM founder_demo_day_rehearsals WHERE rehearsed_at > now() - interval '30 days'),
    (SELECT COALESCE(SUM(one_on_one_count), 0)::int FROM founder_demo_day_targets),
    (SELECT COUNT(*)::int FROM founder_demo_day_targets WHERE deck_url IS NULL OR deck_url = '');
END; $$;

CREATE OR REPLACE FUNCTION founder_demo_day_pitch_status_breakdown()
RETURNS TABLE(pitch_status text, target_count int, p0_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.pitch_status, COUNT(*)::int,
         SUM(CASE WHEN t.priority = 'p0' THEN 1 ELSE 0 END)::int
  FROM founder_demo_day_targets t
  GROUP BY t.pitch_status
  ORDER BY COUNT(*) DESC;
END; $$;

-- =====================================================================
-- WRITE RPCs (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_demo_day_target_upsert(
  p_id uuid,
  p_accelerator_name text,
  p_cohort_label text,
  p_demo_day_date date,
  p_city text,
  p_country text,
  p_deck_slot_minutes int,
  p_deck_url text,
  p_pitch_status text,
  p_one_on_one_count int,
  p_one_on_one_schedule_url text,
  p_expected_investor_count int,
  p_priority text,
  p_founder_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO founder_demo_day_targets(accelerator_name, cohort_label, demo_day_date, city, country,
      deck_slot_minutes, deck_url, pitch_status, one_on_one_count, one_on_one_schedule_url,
      expected_investor_count, priority, founder_notes)
    VALUES (p_accelerator_name, p_cohort_label, p_demo_day_date, p_city, COALESCE(p_country, 'India'),
      COALESCE(p_deck_slot_minutes, 5), p_deck_url, COALESCE(p_pitch_status, 'draft'),
      COALESCE(p_one_on_one_count, 0), p_one_on_one_schedule_url,
      p_expected_investor_count, COALESCE(p_priority, 'p2'), p_founder_notes)
    RETURNING id INTO v_id;
  ELSE
    UPDATE founder_demo_day_targets SET
      accelerator_name = p_accelerator_name,
      cohort_label = p_cohort_label,
      demo_day_date = p_demo_day_date,
      city = p_city,
      country = COALESCE(p_country, country),
      deck_slot_minutes = COALESCE(p_deck_slot_minutes, deck_slot_minutes),
      deck_url = p_deck_url,
      pitch_status = COALESCE(p_pitch_status, pitch_status),
      one_on_one_count = COALESCE(p_one_on_one_count, one_on_one_count),
      one_on_one_schedule_url = p_one_on_one_schedule_url,
      expected_investor_count = p_expected_investor_count,
      priority = COALESCE(p_priority, priority),
      founder_notes = p_founder_notes,
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;
  PERFORM log_founder_demo_day_target_upsert(v_id, p_accelerator_name, p_pitch_status);
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION founder_demo_day_rehearsal_record(
  p_target_id uuid,
  p_duration_seconds int,
  p_self_score int,
  p_weak_slide_numbers int[],
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_demo_day_rehearsals(target_id, duration_seconds, self_score, weak_slide_numbers, notes)
  VALUES (p_target_id, COALESCE(p_duration_seconds, 300), p_self_score, COALESCE(p_weak_slide_numbers, ARRAY[]::int[]), p_notes)
  RETURNING id INTO v_id;
  PERFORM log_founder_demo_day_rehearsal(v_id, p_target_id, p_self_score);
  RETURN v_id;
END; $$;

-- =====================================================================
-- log_founder_* helpers
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_demo_day_target_upsert(p_target_id uuid, p_accelerator_name text, p_pitch_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_demo_day_target_upsert',
          jsonb_build_object('target_id', p_target_id, 'accelerator', p_accelerator_name, 'pitch_status', p_pitch_status));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_demo_day_rehearsal(p_rehearsal_id uuid, p_target_id uuid, p_self_score int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_demo_day_rehearsal_record',
          jsonb_build_object('rehearsal_id', p_rehearsal_id, 'target_id', p_target_id, 'self_score', p_self_score));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_demo_day_view(p_view_name text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_demo_day_view',
          jsonb_build_object('view', p_view_name));
END; $$;

-- =====================================================================
-- Grants
-- =====================================================================

REVOKE EXECUTE ON FUNCTION founder_demo_day_target_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_target_list() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_upcoming_30d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_upcoming_30d() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_rehearsal_log(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_rehearsal_log(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_kpi_snapshot() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_pitch_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_pitch_status_breakdown() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_target_upsert(uuid, text, text, date, text, text, int, text, text, int, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_target_upsert(uuid, text, text, date, text, text, int, text, text, int, text, int, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_demo_day_rehearsal_record(uuid, int, int, int[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_demo_day_rehearsal_record(uuid, int, int, int[], text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_demo_day_target_upsert(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_demo_day_target_upsert(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_demo_day_rehearsal(uuid, uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_demo_day_rehearsal(uuid, uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_demo_day_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_demo_day_view(text) TO authenticated;

COMMIT;