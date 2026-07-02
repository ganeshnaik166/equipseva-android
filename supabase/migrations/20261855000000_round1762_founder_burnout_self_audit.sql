BEGIN;

-- =========================================================================
-- Round r1762 — Founder Burnout Self-Audit
-- Daily self-audit: sleep, mood, energy, hours worked + interventions log.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_burnout_self_audit_r1762 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_date date NOT NULL UNIQUE,
  sleep_hours numeric(4,2),
  mood_score int CHECK (mood_score BETWEEN 1 AND 10),
  energy_score int CHECK (energy_score BETWEEN 1 AND 10),
  hours_worked numeric(5,2),
  drank_water boolean DEFAULT false,
  exercised boolean DEFAULT false,
  notes_md text,
  recorded_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_burnout_intervention_log_r1762 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_date date REFERENCES public.founder_burnout_self_audit_r1762(audit_date) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('vacation','reduced_hours','founder_buddy','therapy','meditation')),
  started_at timestamptz DEFAULT now(),
  effective boolean,
  note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.founder_burnout_self_audit_r1762 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_burnout_intervention_log_r1762 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_audit_r1762 ON public.founder_burnout_self_audit_r1762;
CREATE POLICY founder_only_audit_r1762 ON public.founder_burnout_self_audit_r1762
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_intervention_r1762 ON public.founder_burnout_intervention_log_r1762;
CREATE POLICY founder_only_intervention_r1762 ON public.founder_burnout_intervention_log_r1762
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_audits
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_audits_r1762(p_limit int DEFAULT 60)
RETURNS TABLE(
  id uuid,
  audit_date date,
  sleep_hours numeric,
  mood_score int,
  energy_score int,
  hours_worked numeric,
  drank_water boolean,
  exercised boolean,
  notes_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.audit_date, a.sleep_hours, a.mood_score, a.energy_score,
         a.hours_worked, a.drank_water, a.exercised, a.notes_md, a.recorded_at
  FROM public.founder_burnout_self_audit_r1762 a
  ORDER BY a.audit_date DESC
  LIMIT p_limit;
END;
$$;

-- =========================================================================
-- RPC 2: record_audit
-- =========================================================================
CREATE OR REPLACE FUNCTION public.record_audit_r1762(
  p_audit_date date,
  p_sleep_hours numeric,
  p_mood_score int,
  p_energy_score int,
  p_hours_worked numeric,
  p_drank_water boolean,
  p_exercised boolean,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_burnout_self_audit_r1762(
    audit_date, sleep_hours, mood_score, energy_score, hours_worked,
    drank_water, exercised, notes_md, recorded_at
  )
  VALUES (
    p_audit_date, p_sleep_hours, p_mood_score, p_energy_score, p_hours_worked,
    COALESCE(p_drank_water,false), COALESCE(p_exercised,false), p_notes_md, now()
  )
  ON CONFLICT (audit_date) DO UPDATE SET
    sleep_hours = EXCLUDED.sleep_hours,
    mood_score = EXCLUDED.mood_score,
    energy_score = EXCLUDED.energy_score,
    hours_worked = EXCLUDED.hours_worked,
    drank_water = EXCLUDED.drank_water,
    exercised = EXCLUDED.exercised,
    notes_md = EXCLUDED.notes_md,
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_audit_r1762',
          jsonb_build_object('audit_date', p_audit_date, 'mood', p_mood_score, 'energy', p_energy_score));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC 3: list_interventions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_interventions_r1762(p_limit int DEFAULT 60)
RETURNS TABLE(
  id uuid,
  audit_date date,
  intervention_type text,
  started_at timestamptz,
  effective boolean,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.audit_date, i.intervention_type, i.started_at, i.effective, i.note
  FROM public.founder_burnout_intervention_log_r1762 i
  ORDER BY i.started_at DESC
  LIMIT p_limit;
END;
$$;

-- =========================================================================
-- RPC 4: log_intervention
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_intervention_r1762(
  p_audit_date date,
  p_intervention_type text,
  p_effective boolean,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_intervention_type NOT IN ('vacation','reduced_hours','founder_buddy','therapy','meditation') THEN
    RAISE EXCEPTION 'invalid intervention_type';
  END IF;
  INSERT INTO public.founder_burnout_intervention_log_r1762(audit_date, intervention_type, started_at, effective, note)
  VALUES (p_audit_date, p_intervention_type, now(), p_effective, p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_intervention_r1762',
          jsonb_build_object('audit_date', p_audit_date, 'type', p_intervention_type));

  RETURN v_id;
END;
$$;

-- =========================================================================
-- RPC 5: audit_summary (last 30 days rollup)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.audit_summary_r1762()
RETURNS TABLE(
  total_days int,
  avg_sleep numeric,
  avg_mood numeric,
  avg_energy numeric,
  avg_hours_worked numeric,
  water_days int,
  exercise_days int,
  low_energy_days int,
  low_mood_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_days,
    ROUND(AVG(a.sleep_hours)::numeric, 2) AS avg_sleep,
    ROUND(AVG(a.mood_score)::numeric, 2) AS avg_mood,
    ROUND(AVG(a.energy_score)::numeric, 2) AS avg_energy,
    ROUND(AVG(a.hours_worked)::numeric, 2) AS avg_hours_worked,
    (COUNT(*) FILTER (WHERE a.drank_water))::int AS water_days,
    (COUNT(*) FILTER (WHERE a.exercised))::int AS exercise_days,
    (COUNT(*) FILTER (WHERE a.energy_score <= 4))::int AS low_energy_days,
    (COUNT(*) FILTER (WHERE a.mood_score <= 4))::int AS low_mood_days
  FROM public.founder_burnout_self_audit_r1762 a
  WHERE a.audit_date >= (current_date - INTERVAL '30 days');
END;
$$;

-- =========================================================================
-- RPC 6: recent_low_energy_days
-- =========================================================================
CREATE OR REPLACE FUNCTION public.recent_low_energy_days_r1762(p_limit int DEFAULT 30)
RETURNS TABLE(
  audit_date date,
  energy_score int,
  sleep_hours numeric,
  hours_worked numeric,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.audit_date, a.energy_score, a.sleep_hours, a.hours_worked, a.notes_md
  FROM public.founder_burnout_self_audit_r1762 a
  WHERE a.energy_score <= 4
  ORDER BY a.audit_date DESC
  LIMIT p_limit;
END;
$$;

-- =========================================================================
-- RPC 7: recent_high_burnout_signals
-- Days with low sleep AND low mood AND high hours.
-- =========================================================================
CREATE OR REPLACE FUNCTION public.recent_high_burnout_signals_r1762(p_limit int DEFAULT 30)
RETURNS TABLE(
  audit_date date,
  sleep_hours numeric,
  mood_score int,
  energy_score int,
  hours_worked numeric,
  signal_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.audit_date,
    a.sleep_hours,
    a.mood_score,
    a.energy_score,
    a.hours_worked,
    (
      (CASE WHEN a.sleep_hours < 6 THEN 1 ELSE 0 END)
      + (CASE WHEN a.mood_score <= 4 THEN 1 ELSE 0 END)
      + (CASE WHEN a.energy_score <= 4 THEN 1 ELSE 0 END)
      + (CASE WHEN a.hours_worked > 12 THEN 1 ELSE 0 END)
    )::int AS signal_count
  FROM public.founder_burnout_self_audit_r1762 a
  WHERE (
    (a.sleep_hours IS NOT NULL AND a.sleep_hours < 6)
    OR (a.mood_score IS NOT NULL AND a.mood_score <= 4)
    OR (a.energy_score IS NOT NULL AND a.energy_score <= 4)
    OR (a.hours_worked IS NOT NULL AND a.hours_worked > 12)
  )
  ORDER BY signal_count DESC, a.audit_date DESC
  LIMIT p_limit;
END;
$$;

-- =========================================================================
-- Permissions
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.list_audits_r1762(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_audit_r1762(date, numeric, int, int, numeric, boolean, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_interventions_r1762(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_intervention_r1762(date, text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.audit_summary_r1762() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_low_energy_days_r1762(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_high_burnout_signals_r1762(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r1762(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_audit_r1762(date, numeric, int, int, numeric, boolean, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_interventions_r1762(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_intervention_r1762(date, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_summary_r1762() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_low_energy_days_r1762(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_high_burnout_signals_r1762(int) TO authenticated;

COMMIT;