BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_competitor_watch_r2229 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_name text NOT NULL,
  competitor_type text NOT NULL CHECK (competitor_type IN ('oem','service_chain','startup','distributor','in_house')),
  hq_country text,
  hq_city text,
  founded_year int,
  estimated_revenue_inr_cr numeric(12,2),
  estimated_engineers int,
  estimated_hospitals_served int,
  threat_level text NOT NULL DEFAULT 'medium' CHECK (threat_level IN ('low','medium','high','critical')),
  threat_rationale text,
  primary_strength text,
  primary_weakness text,
  overlap_pct int CHECK (overlap_pct BETWEEN 0 AND 100),
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_competitor_moves_r2229 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  competitor_id uuid NOT NULL REFERENCES public.founder_competitor_watch_r2229(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  move_type text NOT NULL CHECK (move_type IN ('product_launch','pricing','hire','funding','partnership','contract_win','contract_loss','expansion','press','regulation','other')),
  headline text NOT NULL,
  source_url text,
  source_summary text,
  threat_delta text NOT NULL DEFAULT 'neutral' CHECK (threat_delta IN ('increases','neutral','decreases')),
  counter_move text,
  counter_move_status text NOT NULL DEFAULT 'planned' CHECK (counter_move_status IN ('planned','in_progress','shipped','dropped')),
  counter_move_owner uuid REFERENCES public.profiles(id),
  counter_move_eta_at timestamptz,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_competitor_watch_r2229 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_competitor_moves_r2229 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_competitor_watch_r2229 ON public.founder_competitor_watch_r2229;
CREATE POLICY founder_all_competitor_watch_r2229 ON public.founder_competitor_watch_r2229
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_competitor_moves_r2229 ON public.founder_competitor_moves_r2229;
CREATE POLICY founder_all_competitor_moves_r2229 ON public.founder_competitor_moves_r2229
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_competitor_watch_threat_r2229 ON public.founder_competitor_watch_r2229(threat_level, is_active);
CREATE INDEX IF NOT EXISTS idx_competitor_moves_observed_r2229 ON public.founder_competitor_moves_r2229(observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_competitor_moves_competitor_r2229 ON public.founder_competitor_moves_r2229(competitor_id);

-- RPC 1: list competitors with move counts and last-move snapshot
DROP FUNCTION IF EXISTS public.founder_competitor_list_r2229();
CREATE OR REPLACE FUNCTION public.founder_competitor_list_r2229()
RETURNS TABLE(
  id uuid,
  competitor_name text,
  competitor_type text,
  hq_country text,
  threat_level text,
  estimated_revenue_inr_cr numeric,
  estimated_hospitals_served int,
  overlap_pct int,
  is_active boolean,
  total_moves int,
  open_counters int,
  last_move_at timestamptz,
  last_headline text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.id,
    w.competitor_name,
    w.competitor_type,
    w.hq_country,
    w.threat_level,
    w.estimated_revenue_inr_cr,
    w.estimated_hospitals_served,
    w.overlap_pct,
    w.is_active,
    (COUNT(m.id))::int AS total_moves,
    (COUNT(m.id) FILTER (WHERE m.counter_move_status IN ('planned','in_progress')))::int AS open_counters,
    MAX(m.observed_at) AS last_move_at,
    (ARRAY_AGG(m.headline ORDER BY m.observed_at DESC) FILTER (WHERE m.headline IS NOT NULL))[1] AS last_headline
  FROM public.founder_competitor_watch_r2229 w
  LEFT JOIN public.founder_competitor_moves_r2229 m ON m.competitor_id = w.id
  GROUP BY w.id
  ORDER BY
    CASE w.threat_level WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    w.competitor_name;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_list_r2229() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_list_r2229() TO authenticated;

-- RPC 2: recent moves feed
DROP FUNCTION IF EXISTS public.founder_competitor_moves_recent_r2229(int);
CREATE OR REPLACE FUNCTION public.founder_competitor_moves_recent_r2229(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  competitor_id uuid,
  competitor_name text,
  threat_level text,
  observed_at timestamptz,
  move_type text,
  headline text,
  source_url text,
  threat_delta text,
  counter_move text,
  counter_move_status text,
  counter_move_eta_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.competitor_id, w.competitor_name, w.threat_level,
         m.observed_at, m.move_type, m.headline, m.source_url,
         m.threat_delta, m.counter_move, m.counter_move_status, m.counter_move_eta_at
  FROM public.founder_competitor_moves_r2229 m
  JOIN public.founder_competitor_watch_r2229 w ON w.id = m.competitor_id
  ORDER BY m.observed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_moves_recent_r2229(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_moves_recent_r2229(int) TO authenticated;

-- RPC 3: threat distribution rollup
DROP FUNCTION IF EXISTS public.founder_competitor_threat_rollup_r2229();
CREATE OR REPLACE FUNCTION public.founder_competitor_threat_rollup_r2229()
RETURNS TABLE(
  threat_level text,
  competitor_count int,
  total_moves_90d int,
  open_counters int,
  shipped_counters_90d int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.threat_level,
    (COUNT(DISTINCT w.id))::int,
    (COUNT(m.id) FILTER (WHERE m.observed_at >= now() - interval '90 days'))::int,
    (COUNT(m.id) FILTER (WHERE m.counter_move_status IN ('planned','in_progress')))::int,
    (COUNT(m.id) FILTER (WHERE m.counter_move_status = 'shipped' AND m.updated_at >= now() - interval '90 days'))::int
  FROM public.founder_competitor_watch_r2229 w
  LEFT JOIN public.founder_competitor_moves_r2229 m ON m.competitor_id = w.id
  WHERE w.is_active
  GROUP BY w.threat_level
  ORDER BY CASE w.threat_level WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_threat_rollup_r2229() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_threat_rollup_r2229() TO authenticated;

-- RPC 4: counter-move kanban (status buckets)
DROP FUNCTION IF EXISTS public.founder_competitor_counter_kanban_r2229();
CREATE OR REPLACE FUNCTION public.founder_competitor_counter_kanban_r2229()
RETURNS TABLE(
  counter_move_status text,
  move_count int,
  competitor_count int,
  next_eta_at timestamptz,
  overdue_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.counter_move_status,
    (COUNT(*))::int,
    (COUNT(DISTINCT m.competitor_id))::int,
    MIN(m.counter_move_eta_at) FILTER (WHERE m.counter_move_eta_at IS NOT NULL),
    (COUNT(*) FILTER (WHERE m.counter_move_eta_at < now() AND m.counter_move_status IN ('planned','in_progress')))::int
  FROM public.founder_competitor_moves_r2229 m
  WHERE m.counter_move IS NOT NULL AND m.counter_move <> ''
  GROUP BY m.counter_move_status
  ORDER BY CASE m.counter_move_status WHEN 'in_progress' THEN 0 WHEN 'planned' THEN 1 WHEN 'shipped' THEN 2 ELSE 3 END;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_counter_kanban_r2229() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_counter_kanban_r2229() TO authenticated;

-- RPC 5: upsert competitor
DROP FUNCTION IF EXISTS public.founder_competitor_upsert_r2229(uuid, text, text, text, text, int, numeric, int, int, text, text, int, boolean, text);
CREATE OR REPLACE FUNCTION public.founder_competitor_upsert_r2229(
  p_id uuid,
  p_competitor_name text,
  p_competitor_type text,
  p_hq_country text,
  p_hq_city text,
  p_founded_year int,
  p_estimated_revenue_inr_cr numeric,
  p_estimated_engineers int,
  p_estimated_hospitals_served int,
  p_threat_level text,
  p_threat_rationale text,
  p_overlap_pct int,
  p_is_active boolean,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_user uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_user := auth.uid();
  v_email := auth.jwt()->>'email';

  IF p_id IS NULL THEN
    INSERT INTO public.founder_competitor_watch_r2229(
      competitor_name, competitor_type, hq_country, hq_city, founded_year,
      estimated_revenue_inr_cr, estimated_engineers, estimated_hospitals_served,
      threat_level, threat_rationale, overlap_pct, is_active, notes, created_by
    ) VALUES (
      p_competitor_name, p_competitor_type, p_hq_country, p_hq_city, p_founded_year,
      p_estimated_revenue_inr_cr, p_estimated_engineers, p_estimated_hospitals_served,
      COALESCE(p_threat_level,'medium'), p_threat_rationale, p_overlap_pct,
      COALESCE(p_is_active, true), p_notes, v_user
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE public.founder_competitor_watch_r2229 SET
      competitor_name = p_competitor_name,
      competitor_type = p_competitor_type,
      hq_country = p_hq_country,
      hq_city = p_hq_city,
      founded_year = p_founded_year,
      estimated_revenue_inr_cr = p_estimated_revenue_inr_cr,
      estimated_engineers = p_estimated_engineers,
      estimated_hospitals_served = p_estimated_hospitals_served,
      threat_level = COALESCE(p_threat_level, threat_level),
      threat_rationale = p_threat_rationale,
      overlap_pct = p_overlap_pct,
      is_active = COALESCE(p_is_active, is_active),
      notes = p_notes,
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (v_user, v_email, 'founder_competitor_upsert_r2229',
          jsonb_build_object('id', v_id, 'name', p_competitor_name, 'threat_level', p_threat_level));

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_upsert_r2229(uuid, text, text, text, text, int, numeric, int, int, text, text, int, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_upsert_r2229(uuid, text, text, text, text, int, numeric, int, int, text, text, int, boolean, text) TO authenticated;

-- RPC 6: log a move
DROP FUNCTION IF EXISTS public.founder_competitor_move_log_r2229(uuid, text, text, text, text, text, text, text, timestamptz);
CREATE OR REPLACE FUNCTION public.founder_competitor_move_log_r2229(
  p_competitor_id uuid,
  p_move_type text,
  p_headline text,
  p_source_url text,
  p_source_summary text,
  p_threat_delta text,
  p_counter_move text,
  p_counter_move_status text,
  p_counter_move_eta_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_user uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_user := auth.uid();
  v_email := auth.jwt()->>'email';

  INSERT INTO public.founder_competitor_moves_r2229(
    competitor_id, move_type, headline, source_url, source_summary,
    threat_delta, counter_move, counter_move_status, counter_move_eta_at, created_by
  ) VALUES (
    p_competitor_id, p_move_type, p_headline, p_source_url, p_source_summary,
    COALESCE(p_threat_delta,'neutral'), p_counter_move,
    COALESCE(p_counter_move_status,'planned'), p_counter_move_eta_at, v_user
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (v_user, v_email, 'founder_competitor_move_log_r2229',
          jsonb_build_object('id', v_id, 'competitor_id', p_competitor_id, 'headline', p_headline));

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_move_log_r2229(uuid, text, text, text, text, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_move_log_r2229(uuid, text, text, text, text, text, text, text, timestamptz) TO authenticated;

-- RPC 7: update counter-move status
DROP FUNCTION IF EXISTS public.founder_competitor_counter_update_r2229(uuid, text);
CREATE OR REPLACE FUNCTION public.founder_competitor_counter_update_r2229(
  p_move_id uuid,
  p_counter_move_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_user uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_counter_move_status NOT IN ('planned','in_progress','shipped','dropped') THEN
    RAISE EXCEPTION 'invalid counter_move_status';
  END IF;
  v_user := auth.uid();
  v_email := auth.jwt()->>'email';

  UPDATE public.founder_competitor_moves_r2229
    SET counter_move_status = p_counter_move_status, updated_at = now()
  WHERE id = p_move_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (v_user, v_email, 'founder_competitor_counter_update_r2229',
          jsonb_build_object('id', p_move_id, 'status', p_counter_move_status));

  RETURN p_move_id;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_competitor_counter_update_r2229(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_competitor_counter_update_r2229(uuid, text) TO authenticated;

COMMIT;
