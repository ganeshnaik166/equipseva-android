BEGIN;

-- =========================================================
-- Round 1666 — Founder Daily Standup Tracker
-- =========================================================

CREATE TABLE founder_standup_entries_r1666 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_date date NOT NULL UNIQUE,
  yesterday_md text NOT NULL DEFAULT '',
  today_md text NOT NULL DEFAULT '',
  blockers_md text NOT NULL DEFAULT '',
  mood text CHECK (mood IN ('great','good','ok','low','burned_out')),
  energy_score int CHECK (energy_score BETWEEN 1 AND 10),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE founder_standup_blocker_actions_r1666 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id uuid NOT NULL REFERENCES founder_standup_entries_r1666(id) ON DELETE CASCADE,
  blocker_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_r1666_entries_date ON founder_standup_entries_r1666(entry_date DESC);
CREATE INDEX idx_r1666_blockers_entry ON founder_standup_blocker_actions_r1666(entry_id);
CREATE INDEX idx_r1666_blockers_status ON founder_standup_blocker_actions_r1666(status);

ALTER TABLE founder_standup_entries_r1666 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_standup_blocker_actions_r1666 ENABLE ROW LEVEL SECURITY;

CREATE POLICY r1666_entries_founder_all ON founder_standup_entries_r1666
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE POLICY r1666_blockers_founder_all ON founder_standup_blocker_actions_r1666
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================
-- RPC 1 — list_entries (last 60 days)
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_list_entries()
RETURNS TABLE (
  id uuid,
  entry_date date,
  yesterday_md text,
  today_md text,
  blockers_md text,
  mood text,
  energy_score int,
  open_blocker_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.entry_date,
      e.yesterday_md,
      e.today_md,
      e.blockers_md,
      e.mood,
      e.energy_score,
      (SELECT (COUNT(*) FILTER (WHERE b.status IN ('open','in_progress')))::int
         FROM founder_standup_blocker_actions_r1666 b
        WHERE b.entry_id = e.id) AS open_blocker_count,
      e.created_at
    FROM founder_standup_entries_r1666 e
    WHERE e.entry_date >= (CURRENT_DATE - INTERVAL '60 days')
    ORDER BY e.entry_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_list_entries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_list_entries() TO authenticated;

-- =========================================================
-- RPC 2 — record_entry (upsert by entry_date)
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_record_entry(
  p_entry_date date,
  p_yesterday_md text,
  p_today_md text,
  p_blockers_md text,
  p_mood text,
  p_energy_score int
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_standup_entries_r1666(entry_date, yesterday_md, today_md, blockers_md, mood, energy_score)
  VALUES (p_entry_date, COALESCE(p_yesterday_md,''), COALESCE(p_today_md,''), COALESCE(p_blockers_md,''), p_mood, p_energy_score)
  ON CONFLICT (entry_date) DO UPDATE
    SET yesterday_md = EXCLUDED.yesterday_md,
        today_md = EXCLUDED.today_md,
        blockers_md = EXCLUDED.blockers_md,
        mood = EXCLUDED.mood,
        energy_score = EXCLUDED.energy_score,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1666_record_entry',
          jsonb_build_object('entry_id', v_id, 'entry_date', p_entry_date, 'mood', p_mood, 'energy', p_energy_score));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_record_entry(date, text, text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_record_entry(date, text, text, text, text, int) TO authenticated;

-- =========================================================
-- RPC 3 — list_blockers (per entry)
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_list_blockers(p_entry_id uuid)
RETURNS TABLE (
  id uuid,
  entry_id uuid,
  blocker_text text,
  owner_email text,
  due_date date,
  status text,
  resolved_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.entry_id, b.blocker_text, b.owner_email, b.due_date, b.status, b.resolved_at, b.created_at
      FROM founder_standup_blocker_actions_r1666 b
     WHERE b.entry_id = p_entry_id
     ORDER BY b.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_list_blockers(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_list_blockers(uuid) TO authenticated;

-- =========================================================
-- RPC 4 — add_blocker_action
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_add_blocker_action(
  p_entry_id uuid,
  p_blocker_text text,
  p_owner_email text,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_standup_blocker_actions_r1666(entry_id, blocker_text, owner_email, due_date, status)
  VALUES (p_entry_id, p_blocker_text, p_owner_email, p_due_date, 'open')
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1666_add_blocker_action',
          jsonb_build_object('blocker_id', v_id, 'entry_id', p_entry_id, 'owner', p_owner_email, 'due', p_due_date));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_add_blocker_action(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_add_blocker_action(uuid, text, text, date) TO authenticated;

-- =========================================================
-- RPC 5 — resolve_blocker
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_resolve_blocker(
  p_blocker_id uuid,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('open','in_progress','resolved','dropped') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE founder_standup_blocker_actions_r1666
     SET status = p_status,
         resolved_at = CASE WHEN p_status IN ('resolved','dropped') THEN now() ELSE NULL END,
         updated_at = now()
   WHERE id = p_blocker_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1666_resolve_blocker',
          jsonb_build_object('blocker_id', p_blocker_id, 'status', p_status));

  RETURN p_blocker_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_resolve_blocker(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_resolve_blocker(uuid, text) TO authenticated;

-- =========================================================
-- RPC 6 — mood_trend (last 30 days)
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_mood_trend()
RETURNS TABLE (
  entry_date date,
  mood text,
  energy_score int,
  rolling_avg_energy numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.entry_date,
      e.mood,
      e.energy_score,
      ROUND(AVG(e.energy_score) OVER (ORDER BY e.entry_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)::numeric, 2) AS rolling_avg_energy
    FROM founder_standup_entries_r1666 e
    WHERE e.entry_date >= (CURRENT_DATE - INTERVAL '30 days')
    ORDER BY e.entry_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_mood_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_mood_trend() TO authenticated;

-- =========================================================
-- RPC 7 — open_blockers_list (all open across entries)
-- =========================================================
CREATE OR REPLACE FUNCTION public.r1666_open_blockers_list()
RETURNS TABLE (
  id uuid,
  entry_id uuid,
  entry_date date,
  blocker_text text,
  owner_email text,
  due_date date,
  status text,
  days_open int,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      b.id,
      b.entry_id,
      e.entry_date,
      b.blocker_text,
      b.owner_email,
      b.due_date,
      b.status,
      GREATEST(0, (CURRENT_DATE - b.created_at::date))::int AS days_open,
      b.created_at
    FROM founder_standup_blocker_actions_r1666 b
    JOIN founder_standup_entries_r1666 e ON e.id = b.entry_id
    WHERE b.status IN ('open','in_progress')
    ORDER BY b.created_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1666_open_blockers_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1666_open_blockers_list() TO authenticated;

COMMIT;