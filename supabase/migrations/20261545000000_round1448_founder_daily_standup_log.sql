BEGIN;

-- ============================================================================
-- r1448 — Founder daily standup log
-- Records what founder + lead engineer shipped yesterday, intend to ship today,
-- and any blockers. Tracks streak + surfaces oldest unresolved blocker.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: founder_standup_entries
-- One row per (author, standup_date). Author is founder or lead engineer.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_standup_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  standup_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  author_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  author_role text NOT NULL CHECK (author_role IN ('founder','lead_engineer')),
  shipped_yesterday text NOT NULL DEFAULT '',
  intent_today text NOT NULL DEFAULT '',
  mood text CHECK (mood IN ('green','yellow','red')) DEFAULT 'green',
  hours_worked_yesterday numeric(4,1),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (standup_date, author_user_id)
);

CREATE INDEX IF NOT EXISTS idx_standup_entries_date ON public.founder_standup_entries(standup_date DESC);
CREATE INDEX IF NOT EXISTS idx_standup_entries_author ON public.founder_standup_entries(author_user_id, standup_date DESC);

ALTER TABLE public.founder_standup_entries ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Table 2: founder_standup_blockers
-- One row per blocker. Linked to a standup entry; resolved_at when cleared.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_standup_blockers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL REFERENCES public.founder_standup_entries(id) ON DELETE CASCADE,
  raised_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  raised_on date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')) DEFAULT 'p2',
  category text CHECK (category IN ('engineering','ops','legal','finance','people','external')) DEFAULT 'engineering',
  title text NOT NULL,
  detail text,
  resolved_at timestamptz,
  resolved_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_standup_blockers_entry ON public.founder_standup_blockers(entry_id);
CREATE INDEX IF NOT EXISTS idx_standup_blockers_open ON public.founder_standup_blockers(raised_on) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_standup_blockers_sev ON public.founder_standup_blockers(severity, raised_on DESC) WHERE resolved_at IS NULL;

ALTER TABLE public.founder_standup_blockers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7 SECDEF read RPCs (STABLE) + 4 log_founder_* helpers (VOLATILE)
-- ============================================================================

-- ---------- 1) get_standup_kpis ---------------------------------------------
CREATE OR REPLACE FUNCTION public.get_standup_kpis()
RETURNS TABLE (
  metric text,
  value_num numeric,
  value_text text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_streak int := 0;
  v_check_date date := v_today;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  -- compute current streak: consecutive days back from today with >=1 entry
  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM founder_standup_entries WHERE standup_date = v_check_date
    );
    v_streak := v_streak + 1;
    v_check_date := v_check_date - 1;
  END LOOP;

  RETURN QUERY
  SELECT 'entries_today'::text, COUNT(*)::numeric, NULL::text
  FROM founder_standup_entries WHERE standup_date = v_today
  UNION ALL
  SELECT 'entries_7d', COUNT(*)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6
  UNION ALL
  SELECT 'entries_30d', COUNT(*)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 29
  UNION ALL
  SELECT 'streak_days', v_streak::numeric, NULL
  UNION ALL
  SELECT 'open_blockers', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL
  UNION ALL
  SELECT 'open_p0', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL AND severity = 'p0'
  UNION ALL
  SELECT 'open_p1', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL AND severity = 'p1'
  UNION ALL
  SELECT 'open_p2', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL AND severity = 'p2'
  UNION ALL
  SELECT 'open_p3', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL AND severity = 'p3'
  UNION ALL
  SELECT 'blockers_resolved_7d', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at >= now() - interval '7 days'
  UNION ALL
  SELECT 'blockers_resolved_30d', COUNT(*)::numeric, NULL
  FROM founder_standup_blockers WHERE resolved_at >= now() - interval '30 days'
  UNION ALL
  SELECT 'avg_hours_yesterday_7d',
         COALESCE(ROUND(AVG(hours_worked_yesterday)::numeric, 1), 0),
         NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6 AND hours_worked_yesterday IS NOT NULL
  UNION ALL
  SELECT 'red_mood_7d', COUNT(*)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6 AND mood = 'red'
  UNION ALL
  SELECT 'yellow_mood_7d', COUNT(*)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6 AND mood = 'yellow'
  UNION ALL
  SELECT 'green_mood_7d', COUNT(*)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6 AND mood = 'green'
  UNION ALL
  SELECT 'oldest_blocker_age_days',
         COALESCE(EXTRACT(DAY FROM (now() - MIN(created_at))), 0)::numeric,
         NULL
  FROM founder_standup_blockers WHERE resolved_at IS NULL
  UNION ALL
  SELECT 'authors_active_7d', COUNT(DISTINCT author_user_id)::numeric, NULL
  FROM founder_standup_entries WHERE standup_date >= v_today - 6;
END;
$$;
REVOKE ALL ON FUNCTION public.get_standup_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_standup_kpis() TO authenticated;

-- ---------- 2) list_recent_standup_entries ---------------------------------
CREATE OR REPLACE FUNCTION public.list_recent_standup_entries(p_days int DEFAULT 14)
RETURNS TABLE (
  id uuid,
  standup_date date,
  author_role text,
  author_email text,
  shipped_yesterday text,
  intent_today text,
  mood text,
  hours_worked_yesterday numeric,
  blocker_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT e.id, e.standup_date, e.author_role,
         u.email::text AS author_email,
         e.shipped_yesterday, e.intent_today, e.mood, e.hours_worked_yesterday,
         (SELECT COUNT(*)::int FROM founder_standup_blockers b WHERE b.entry_id = e.id) AS blocker_count,
         e.created_at
  FROM founder_standup_entries e
  LEFT JOIN auth.users u ON u.id = e.author_user_id
  WHERE e.standup_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - GREATEST(p_days,1)
  ORDER BY e.standup_date DESC, e.author_role;
END;
$$;
REVOKE ALL ON FUNCTION public.list_recent_standup_entries(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_recent_standup_entries(int) TO authenticated;

-- ---------- 3) list_open_blockers ------------------------------------------
CREATE OR REPLACE FUNCTION public.list_open_blockers()
RETURNS TABLE (
  id uuid,
  raised_on date,
  age_days int,
  severity text,
  category text,
  title text,
  detail text,
  raised_by_email text,
  entry_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT b.id, b.raised_on,
         GREATEST(0, ((now() AT TIME ZONE 'Asia/Kolkata')::date - b.raised_on))::int AS age_days,
         b.severity, b.category, b.title, b.detail,
         u.email::text AS raised_by_email,
         b.entry_id
  FROM founder_standup_blockers b
  LEFT JOIN auth.users u ON u.id = b.raised_by_user_id
  WHERE b.resolved_at IS NULL
  ORDER BY
    CASE b.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    b.raised_on ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.list_open_blockers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_open_blockers() TO authenticated;

-- ---------- 4) list_recently_resolved_blockers -----------------------------
CREATE OR REPLACE FUNCTION public.list_recently_resolved_blockers(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  raised_on date,
  resolved_at timestamptz,
  ttr_days numeric,
  severity text,
  category text,
  title text,
  resolved_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT b.id, b.raised_on, b.resolved_at,
         ROUND(EXTRACT(EPOCH FROM (b.resolved_at - b.created_at))/86400.0, 2) AS ttr_days,
         b.severity, b.category, b.title, b.resolved_note
  FROM founder_standup_blockers b
  WHERE b.resolved_at IS NOT NULL
    AND b.resolved_at >= now() - (GREATEST(p_days,1) || ' days')::interval
  ORDER BY b.resolved_at DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.list_recently_resolved_blockers(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_recently_resolved_blockers(int) TO authenticated;

-- ---------- 5) get_streak_history ------------------------------------------
CREATE OR REPLACE FUNCTION public.get_streak_history(p_days int DEFAULT 30)
RETURNS TABLE (
  d date,
  entry_count int,
  authors text[],
  any_red_mood boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      ((now() AT TIME ZONE 'Asia/Kolkata')::date - GREATEST(p_days,1) + 1),
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      '1 day'::interval
    )::date AS d
  )
  SELECT days.d,
         COALESCE(COUNT(e.id)::int, 0) AS entry_count,
         COALESCE(array_agg(DISTINCT e.author_role) FILTER (WHERE e.id IS NOT NULL), ARRAY[]::text[]) AS authors,
         BOOL_OR(e.mood = 'red') AS any_red_mood
  FROM days
  LEFT JOIN founder_standup_entries e ON e.standup_date = days.d
  GROUP BY days.d
  ORDER BY days.d DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.get_streak_history(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_streak_history(int) TO authenticated;

-- ---------- 6) get_blocker_severity_breakdown ------------------------------
CREATE OR REPLACE FUNCTION public.get_blocker_severity_breakdown()
RETURNS TABLE (
  severity text,
  category text,
  open_count int,
  resolved_30d int,
  median_age_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT s.sev AS severity,
         c.cat AS category,
         COALESCE(SUM(CASE WHEN b.resolved_at IS NULL THEN 1 ELSE 0 END)::int, 0) AS open_count,
         COALESCE(SUM(CASE WHEN b.resolved_at >= now() - interval '30 days' THEN 1 ELSE 0 END)::int, 0) AS resolved_30d,
         COALESCE(
           percentile_disc(0.5) WITHIN GROUP (
             ORDER BY EXTRACT(DAY FROM (COALESCE(b.resolved_at, now()) - b.created_at))
           )::numeric,
           0
         ) AS median_age_days
  FROM (VALUES ('p0'),('p1'),('p2'),('p3')) AS s(sev)
  CROSS JOIN (VALUES ('engineering'),('ops'),('legal'),('finance'),('people'),('external')) AS c(cat)
  LEFT JOIN founder_standup_blockers b ON b.severity = s.sev AND b.category = c.cat
  GROUP BY s.sev, c.cat
  HAVING COUNT(b.id) > 0
  ORDER BY
    CASE s.sev WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    c.cat;
END;
$$;
REVOKE ALL ON FUNCTION public.get_blocker_severity_breakdown() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_blocker_severity_breakdown() TO authenticated;

-- ---------- 7) get_author_engagement ---------------------------------------
CREATE OR REPLACE FUNCTION public.get_author_engagement(p_days int DEFAULT 30)
RETURNS TABLE (
  author_role text,
  author_email text,
  entries_count int,
  days_active int,
  avg_hours_worked numeric,
  blockers_raised int,
  last_entry_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT e.author_role,
         u.email::text AS author_email,
         COUNT(e.id)::int AS entries_count,
         COUNT(DISTINCT e.standup_date)::int AS days_active,
         COALESCE(ROUND(AVG(e.hours_worked_yesterday)::numeric, 1), 0) AS avg_hours_worked,
         (SELECT COUNT(*)::int FROM founder_standup_blockers b WHERE b.raised_by_user_id = e.author_user_id) AS blockers_raised,
         MAX(e.standup_date) AS last_entry_date
  FROM founder_standup_entries e
  LEFT JOIN auth.users u ON u.id = e.author_user_id
  WHERE e.standup_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date - GREATEST(p_days,1)
  GROUP BY e.author_role, e.author_user_id, u.email
  ORDER BY entries_count DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.get_author_engagement(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_author_engagement(int) TO authenticated;

-- ============================================================================
-- log_founder_* write helpers (VOLATILE, SECDEF, founder-gated)
-- ============================================================================

-- ---------- log_founder_standup_entry ---------------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_standup_entry(
  p_author_role text,
  p_shipped_yesterday text,
  p_intent_today text,
  p_mood text DEFAULT 'green',
  p_hours_worked numeric DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_author_role NOT IN ('founder','lead_engineer') THEN RAISE EXCEPTION 'bad_role'; END IF;
  IF p_mood NOT IN ('green','yellow','red') THEN RAISE EXCEPTION 'bad_mood'; END IF;

  INSERT INTO founder_standup_entries
    (standup_date, author_user_id, author_role, shipped_yesterday, intent_today, mood, hours_worked_yesterday, notes)
  VALUES
    (v_today, auth.uid(), p_author_role, COALESCE(p_shipped_yesterday,''), COALESCE(p_intent_today,''), p_mood, p_hours_worked, p_notes)
  ON CONFLICT (standup_date, author_user_id) DO UPDATE
    SET shipped_yesterday = EXCLUDED.shipped_yesterday,
        intent_today = EXCLUDED.intent_today,
        mood = EXCLUDED.mood,
        hours_worked_yesterday = EXCLUDED.hours_worked_yesterday,
        notes = EXCLUDED.notes,
        updated_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_standup_entry(text,text,text,text,numeric,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_standup_entry(text,text,text,text,numeric,text) TO authenticated;

-- ---------- log_founder_standup_blocker ------------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_standup_blocker(
  p_entry_id uuid,
  p_title text,
  p_severity text DEFAULT 'p2',
  p_category text DEFAULT 'engineering',
  p_detail text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_severity NOT IN ('p0','p1','p2','p3') THEN RAISE EXCEPTION 'bad_severity'; END IF;
  IF p_category NOT IN ('engineering','ops','legal','finance','people','external') THEN RAISE EXCEPTION 'bad_category'; END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN RAISE EXCEPTION 'title_required'; END IF;

  INSERT INTO founder_standup_blockers
    (entry_id, raised_by_user_id, severity, category, title, detail)
  VALUES
    (p_entry_id, auth.uid(), p_severity, p_category, p_title, p_detail)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_standup_blocker(uuid,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_standup_blocker(uuid,text,text,text,text) TO authenticated;

-- ---------- log_founder_blocker_resolved -----------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_blocker_resolved(
  p_blocker_id uuid,
  p_resolved_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_standup_blockers
     SET resolved_at = COALESCE(resolved_at, now()),
         resolved_note = COALESCE(p_resolved_note, resolved_note)
   WHERE id = p_blocker_id;

  RETURN p_blocker_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_blocker_resolved(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_blocker_resolved(uuid,text) TO authenticated;

-- ---------- log_founder_standup_entry_delete ------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_standup_entry_delete(
  p_entry_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM founder_standup_entries WHERE id = p_entry_id AND author_user_id = auth.uid();
  RETURN p_entry_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_standup_entry_delete(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_standup_entry_delete(uuid) TO authenticated;

COMMIT;