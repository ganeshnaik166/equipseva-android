BEGIN;

-- Round 1799 — Hospital Engagement Score Detail
-- Per-hospital engagement breakdown (login freq, ticket activity, NPS)

CREATE TABLE IF NOT EXISTS public.hospital_engagement_scores_r1799 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_login_at timestamptz,
  login_count_30d int NOT NULL DEFAULT 0,
  tickets_opened_30d int NOT NULL DEFAULT 0,
  nps_score int,
  avg_rating numeric(4,2),
  engagement_index int NOT NULL DEFAULT 0 CHECK (engagement_index BETWEEN 0 AND 100),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  trend text NOT NULL DEFAULT 'flat' CHECK (trend IN ('up','flat','down')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engagement_scores_r1799_hospital
  ON public.hospital_engagement_scores_r1799(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_engagement_scores_r1799_index
  ON public.hospital_engagement_scores_r1799(engagement_index DESC);
CREATE INDEX IF NOT EXISTS idx_engagement_scores_r1799_recorded
  ON public.hospital_engagement_scores_r1799(recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_engagement_history_r1799 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  engagement_index int NOT NULL CHECK (engagement_index BETWEEN 0 AND 100),
  key_change_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engagement_history_r1799_hospital
  ON public.hospital_engagement_history_r1799(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_engagement_history_r1799_period
  ON public.hospital_engagement_history_r1799(period_start DESC);

ALTER TABLE public.hospital_engagement_scores_r1799 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_engagement_history_r1799 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engagement_scores_r1799_founder_all ON public.hospital_engagement_scores_r1799;
CREATE POLICY engagement_scores_r1799_founder_all ON public.hospital_engagement_scores_r1799
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS engagement_history_r1799_founder_all ON public.hospital_engagement_history_r1799;
CREATE POLICY engagement_history_r1799_founder_all ON public.hospital_engagement_history_r1799
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_scores
CREATE OR REPLACE FUNCTION public.list_scores_r1799()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  last_login_at timestamptz,
  login_count_30d int,
  tickets_opened_30d int,
  nps_score int,
  avg_rating numeric,
  engagement_index int,
  recorded_at timestamptz,
  trend text
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
  SELECT s.id, s.hospital_user_id, p.email::text,
         s.last_login_at, s.login_count_30d, s.tickets_opened_30d,
         s.nps_score, s.avg_rating, s.engagement_index, s.recorded_at, s.trend
  FROM public.hospital_engagement_scores_r1799 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.engagement_index DESC, s.recorded_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: refresh_score
CREATE OR REPLACE FUNCTION public.refresh_score_r1799(
  p_hospital_user_id uuid,
  p_login_count int,
  p_tickets_opened int,
  p_nps int,
  p_avg_rating numeric,
  p_engagement_index int,
  p_trend text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_engagement_scores_r1799(
    hospital_user_id, last_login_at, login_count_30d, tickets_opened_30d,
    nps_score, avg_rating, engagement_index, trend
  ) VALUES (
    p_hospital_user_id, now(), p_login_count, p_tickets_opened,
    p_nps, p_avg_rating, p_engagement_index, COALESCE(p_trend,'flat')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_score_r1799',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'engagement_index', p_engagement_index));
  RETURN v_id;
END;
$$;

-- RPC 3: list_history
CREATE OR REPLACE FUNCTION public.list_history_r1799(p_hospital_user_id uuid)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  period_start date,
  period_end date,
  engagement_index int,
  key_change_note text,
  created_at timestamptz
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
  SELECT h.id, h.hospital_user_id, h.period_start, h.period_end,
         h.engagement_index, h.key_change_note, h.created_at
  FROM public.hospital_engagement_history_r1799 h
  WHERE p_hospital_user_id IS NULL OR h.hospital_user_id = p_hospital_user_id
  ORDER BY h.period_start DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_history
CREATE OR REPLACE FUNCTION public.log_history_r1799(
  p_hospital_user_id uuid,
  p_period_start date,
  p_period_end date,
  p_engagement_index int,
  p_key_change_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_engagement_history_r1799(
    hospital_user_id, period_start, period_end, engagement_index, key_change_note
  ) VALUES (
    p_hospital_user_id, p_period_start, p_period_end, p_engagement_index, p_key_change_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_history_r1799',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'period_start', p_period_start, 'engagement_index', p_engagement_index));
  RETURN v_id;
END;
$$;

-- RPC 5: top_engaged
CREATE OR REPLACE FUNCTION public.top_engaged_r1799()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  engagement_index int,
  trend text,
  recorded_at timestamptz
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
  SELECT s.hospital_user_id, p.email::text, s.engagement_index, s.trend, s.recorded_at
  FROM public.hospital_engagement_scores_r1799 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.engagement_index >= 70
  ORDER BY s.engagement_index DESC
  LIMIT 25;
END;
$$;

-- RPC 6: low_engagement_queue
CREATE OR REPLACE FUNCTION public.low_engagement_queue_r1799()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  engagement_index int,
  login_count_30d int,
  tickets_opened_30d int,
  trend text,
  recorded_at timestamptz
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
  SELECT s.hospital_user_id, p.email::text, s.engagement_index,
         s.login_count_30d, s.tickets_opened_30d, s.trend, s.recorded_at
  FROM public.hospital_engagement_scores_r1799 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.engagement_index < 40
  ORDER BY s.engagement_index ASC, s.recorded_at DESC
  LIMIT 50;
END;
$$;

-- RPC 7: engagement_distribution
CREATE OR REPLACE FUNCTION public.engagement_distribution_r1799()
RETURNS TABLE (
  bucket text,
  cnt int,
  avg_login_count numeric,
  avg_tickets numeric
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
    CASE
      WHEN s.engagement_index >= 80 THEN 'high'
      WHEN s.engagement_index >= 50 THEN 'medium'
      WHEN s.engagement_index >= 25 THEN 'low'
      ELSE 'critical'
    END AS bucket,
    (COUNT(*))::int AS cnt,
    ROUND(AVG(s.login_count_30d)::numeric, 1) AS avg_login_count,
    ROUND(AVG(s.tickets_opened_30d)::numeric, 1) AS avg_tickets
  FROM public.hospital_engagement_scores_r1799 s
  GROUP BY 1
  ORDER BY
    CASE
      WHEN s.engagement_index >= 80 THEN 1
      WHEN s.engagement_index >= 50 THEN 2
      WHEN s.engagement_index >= 25 THEN 3
      ELSE 4
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_scores_r1799() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_score_r1799(uuid,int,int,int,numeric,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_history_r1799(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_history_r1799(uuid,date,date,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_engaged_r1799() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.low_engagement_queue_r1799() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.engagement_distribution_r1799() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_scores_r1799() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_score_r1799(uuid,int,int,int,numeric,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_history_r1799(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_history_r1799(uuid,date,date,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_engaged_r1799() TO authenticated;
GRANT EXECUTE ON FUNCTION public.low_engagement_queue_r1799() TO authenticated;
GRANT EXECUTE ON FUNCTION public.engagement_distribution_r1799() TO authenticated;

COMMIT;