BEGIN;

-- ============================================================================
-- Round 2377: Founder weekly outside-Equipseva conversations
-- Track non-work-related conversations had each week (family, friends, hobbies)
-- as a founder wellness indicator.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_outside_conversations_r2377 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start    date NOT NULL,
  contact_name  text NOT NULL,
  relationship  text NOT NULL CHECK (relationship IN ('family','friend','mentor','hobby_group','neighbor','old_colleague','other')),
  channel       text NOT NULL CHECK (channel IN ('in_person','phone_call','video_call','text_chat','meal','walk','event')),
  topic         text NOT NULL,
  work_mentioned boolean NOT NULL DEFAULT false,
  duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 1 AND 1440),
  energy_after  smallint NOT NULL CHECK (energy_after BETWEEN 1 AND 5),
  notes         text,
  logged_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_foc_r2377_week ON public.founder_outside_conversations_r2377(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_foc_r2377_founder ON public.founder_outside_conversations_r2377(founder_id);
CREATE INDEX IF NOT EXISTS idx_foc_r2377_relationship ON public.founder_outside_conversations_r2377(relationship);

ALTER TABLE public.founder_outside_conversations_r2377 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_outside_conversations_r2377;
CREATE POLICY founder_all ON public.founder_outside_conversations_r2377
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_outside_weekly_targets_r2377 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start    date NOT NULL UNIQUE,
  target_conversations integer NOT NULL DEFAULT 5 CHECK (target_conversations >= 0),
  target_family integer NOT NULL DEFAULT 2 CHECK (target_family >= 0),
  target_non_work_minutes integer NOT NULL DEFAULT 180 CHECK (target_non_work_minutes >= 0),
  reflection    text,
  set_by        uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fowt_r2377_week ON public.founder_outside_weekly_targets_r2377(week_start DESC);

ALTER TABLE public.founder_outside_weekly_targets_r2377 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_outside_weekly_targets_r2377;
CREATE POLICY founder_all ON public.founder_outside_weekly_targets_r2377
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: weekly summary (counts + minutes + energy + work-mention rate)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_weekly_summary(weeks_back integer DEFAULT 8)
RETURNS TABLE (
  week_start date,
  conversation_count integer,
  unique_contacts integer,
  total_minutes integer,
  avg_energy_after numeric,
  work_mention_rate numeric,
  family_count integer,
  friend_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.week_start,
    COUNT(*)::int,
    COUNT(DISTINCT c.contact_name)::int,
    COALESCE(SUM(c.duration_minutes),0)::int,
    ROUND(AVG(c.energy_after)::numeric, 2),
    ROUND((SUM(CASE WHEN c.work_mentioned THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0)) * 100, 1),
    SUM(CASE WHEN c.relationship = 'family' THEN 1 ELSE 0 END)::int,
    SUM(CASE WHEN c.relationship = 'friend' THEN 1 ELSE 0 END)::int
  FROM public.founder_outside_conversations_r2377 c
  WHERE c.week_start >= (CURRENT_DATE - (weeks_back || ' weeks')::interval)::date
  GROUP BY c.week_start
  ORDER BY c.week_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_weekly_summary(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_weekly_summary(integer) TO authenticated;

-- ============================================================================
-- RPC 2: current week target vs actual
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_current_week_status()
RETURNS TABLE (
  week_start date,
  target_conversations integer,
  actual_conversations integer,
  target_family integer,
  actual_family integer,
  target_non_work_minutes integer,
  actual_non_work_minutes integer,
  on_track boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  wk date := date_trunc('week', CURRENT_DATE)::date;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH t AS (
    SELECT * FROM public.founder_outside_weekly_targets_r2377 WHERE week_start = wk
  ),
  a AS (
    SELECT
      COUNT(*)::int AS conv_n,
      SUM(CASE WHEN relationship='family' THEN 1 ELSE 0 END)::int AS fam_n,
      COALESCE(SUM(CASE WHEN work_mentioned=false THEN duration_minutes ELSE 0 END),0)::int AS non_work_min
    FROM public.founder_outside_conversations_r2377
    WHERE week_start = wk
  )
  SELECT
    wk,
    COALESCE((SELECT target_conversations FROM t),5),
    (SELECT conv_n FROM a),
    COALESCE((SELECT target_family FROM t),2),
    (SELECT fam_n FROM a),
    COALESCE((SELECT target_non_work_minutes FROM t),180),
    (SELECT non_work_min FROM a),
    ((SELECT conv_n FROM a) >= COALESCE((SELECT target_conversations FROM t),5)
      AND (SELECT fam_n FROM a) >= COALESCE((SELECT target_family FROM t),2)
      AND (SELECT non_work_min FROM a) >= COALESCE((SELECT target_non_work_minutes FROM t),180));
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_current_week_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_current_week_status() TO authenticated;

-- ============================================================================
-- RPC 3: relationship breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_relationship_breakdown(weeks_back integer DEFAULT 8)
RETURNS TABLE (
  relationship text,
  conversation_count integer,
  total_minutes integer,
  avg_energy numeric,
  share_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_n integer;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*) INTO total_n
  FROM public.founder_outside_conversations_r2377
  WHERE week_start >= (CURRENT_DATE - (weeks_back || ' weeks')::interval)::date;

  RETURN QUERY
  SELECT
    c.relationship,
    COUNT(*)::int,
    COALESCE(SUM(c.duration_minutes),0)::int,
    ROUND(AVG(c.energy_after)::numeric, 2),
    ROUND((COUNT(*)::numeric / NULLIF(total_n,0)) * 100, 1)
  FROM public.founder_outside_conversations_r2377 c
  WHERE c.week_start >= (CURRENT_DATE - (weeks_back || ' weeks')::interval)::date
  GROUP BY c.relationship
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_relationship_breakdown(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_relationship_breakdown(integer) TO authenticated;

-- ============================================================================
-- RPC 4: recent conversations log
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_recent_conversations(limit_n integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  week_start date,
  logged_at timestamptz,
  contact_name text,
  relationship text,
  channel text,
  topic text,
  duration_minutes integer,
  energy_after smallint,
  work_mentioned boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT c.id, c.week_start, c.logged_at, c.contact_name, c.relationship,
         c.channel, c.topic, c.duration_minutes, c.energy_after, c.work_mentioned
  FROM public.founder_outside_conversations_r2377 c
  ORDER BY c.logged_at DESC
  LIMIT GREATEST(limit_n, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_recent_conversations(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_recent_conversations(integer) TO authenticated;

-- ============================================================================
-- RPC 5: wellness streak (consecutive weeks meeting target_conversations)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_wellness_streak()
RETURNS TABLE (
  current_streak_weeks integer,
  best_streak_weeks integer,
  weeks_with_data integer,
  weeks_on_target integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  cur_streak int := 0;
  best int := 0;
  run int := 0;
  weeks_d int := 0;
  weeks_o int := 0;
  r record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  FOR r IN
    SELECT c.week_start, COUNT(*) AS n,
      COALESCE((SELECT target_conversations FROM public.founder_outside_weekly_targets_r2377 t WHERE t.week_start = c.week_start),5) AS tgt
    FROM public.founder_outside_conversations_r2377 c
    GROUP BY c.week_start
    ORDER BY c.week_start ASC
  LOOP
    weeks_d := weeks_d + 1;
    IF r.n >= r.tgt THEN
      run := run + 1;
      weeks_o := weeks_o + 1;
      IF run > best THEN best := run; END IF;
    ELSE
      run := 0;
    END IF;
  END LOOP;

  cur_streak := run;

  RETURN QUERY SELECT cur_streak, best, weeks_d, weeks_o;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_wellness_streak() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_wellness_streak() TO authenticated;

-- ============================================================================
-- RPC 6: channel mix (in_person vs video vs phone vs text)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_channel_mix(weeks_back integer DEFAULT 8)
RETURNS TABLE (
  channel text,
  conversation_count integer,
  total_minutes integer,
  avg_energy numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.channel,
    COUNT(*)::int,
    COALESCE(SUM(c.duration_minutes),0)::int,
    ROUND(AVG(c.energy_after)::numeric, 2)
  FROM public.founder_outside_conversations_r2377 c
  WHERE c.week_start >= (CURRENT_DATE - (weeks_back || ' weeks')::interval)::date
  GROUP BY c.channel
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_channel_mix(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_channel_mix(integer) TO authenticated;

-- ============================================================================
-- RPC 7: top contacts (people founder spends most non-work time with)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_r2377_top_contacts(weeks_back integer DEFAULT 8, limit_n integer DEFAULT 10)
RETURNS TABLE (
  contact_name text,
  relationship text,
  conversation_count integer,
  total_minutes integer,
  avg_energy numeric,
  last_seen date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.contact_name,
    MAX(c.relationship),
    COUNT(*)::int,
    COALESCE(SUM(c.duration_minutes),0)::int,
    ROUND(AVG(c.energy_after)::numeric, 2),
    MAX(c.week_start)
  FROM public.founder_outside_conversations_r2377 c
  WHERE c.week_start >= (CURRENT_DATE - (weeks_back || ' weeks')::interval)::date
  GROUP BY c.contact_name
  ORDER BY COUNT(*) DESC, SUM(c.duration_minutes) DESC
  LIMIT GREATEST(limit_n, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_r2377_top_contacts(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r2377_top_contacts(integer, integer) TO authenticated;

COMMIT;
