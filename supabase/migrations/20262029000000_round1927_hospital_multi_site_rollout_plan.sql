BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_multi_site_rollouts_r1927 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  site_count int NOT NULL DEFAULT 0,
  sites_live_count int NOT NULL DEFAULT 0,
  target_completion_date date,
  status text NOT NULL DEFAULT 'planning' CHECK (status IN ('planning','in_progress','blocked','live','paused')),
  started_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_rollout_site_log_r1927 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rollout_id uuid NOT NULL REFERENCES public.hospital_multi_site_rollouts_r1927(id) ON DELETE CASCADE,
  site_name text NOT NULL,
  site_status text NOT NULL DEFAULT 'pending' CHECK (site_status IN ('pending','scoped','in_progress','live','escalated')),
  went_live_at timestamptz,
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_multi_site_rollouts_r1927 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_rollout_site_log_r1927 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rollouts_founder_r1927 ON public.hospital_multi_site_rollouts_r1927;
CREATE POLICY rollouts_founder_r1927 ON public.hospital_multi_site_rollouts_r1927
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS site_log_founder_r1927 ON public.hospital_rollout_site_log_r1927;
CREATE POLICY site_log_founder_r1927 ON public.hospital_rollout_site_log_r1927
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_rollouts
CREATE OR REPLACE FUNCTION public.list_rollouts_r1927()
RETURNS TABLE(id uuid, hospital_id uuid, site_count int, sites_live_count int, target_completion_date date, status text, started_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, r.site_count, r.sites_live_count, r.target_completion_date, r.status, r.started_at, r.created_at
  FROM public.hospital_multi_site_rollouts_r1927 r
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_rollout (write)
CREATE OR REPLACE FUNCTION public.log_rollout_r1927(
  p_hospital_id uuid,
  p_site_count int,
  p_target_completion_date date,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_multi_site_rollouts_r1927(hospital_id, site_count, target_completion_date, status, started_at)
  VALUES (p_hospital_id, COALESCE(p_site_count,0), p_target_completion_date, COALESCE(p_status,'planning'), now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_rollout_r1927',
    jsonb_build_object('rollout_id', v_id, 'hospital_id', p_hospital_id, 'site_count', p_site_count, 'status', p_status));

  RETURN v_id;
END;
$$;

-- 3. list_sites
CREATE OR REPLACE FUNCTION public.list_sites_r1927(p_rollout_id uuid)
RETURNS TABLE(id uuid, rollout_id uuid, site_name text, site_status text, went_live_at timestamptz, by_email text, notes_md text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.rollout_id, s.site_name, s.site_status, s.went_live_at, s.by_email, s.notes_md, s.created_at
  FROM public.hospital_rollout_site_log_r1927 s
  WHERE s.rollout_id = p_rollout_id
  ORDER BY s.created_at DESC
  LIMIT 500;
END;
$$;

-- 4. log_site (write)
CREATE OR REPLACE FUNCTION public.log_site_r1927(
  p_rollout_id uuid,
  p_site_name text,
  p_site_status text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_rollout_site_log_r1927(rollout_id, site_name, site_status, went_live_at, by_email, notes_md)
  VALUES (
    p_rollout_id,
    p_site_name,
    COALESCE(p_site_status,'pending'),
    CASE WHEN COALESCE(p_site_status,'pending') = 'live' THEN now() ELSE NULL END,
    (auth.jwt()->>'email'),
    p_notes_md
  )
  RETURNING id INTO v_id;

  IF COALESCE(p_site_status,'pending') = 'live' THEN
    UPDATE public.hospital_multi_site_rollouts_r1927
    SET sites_live_count = sites_live_count + 1, updated_at = now()
    WHERE id = p_rollout_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_site_r1927',
    jsonb_build_object('site_log_id', v_id, 'rollout_id', p_rollout_id, 'site_name', p_site_name, 'site_status', p_site_status));

  RETURN v_id;
END;
$$;

-- 5. mark_status (write)
CREATE OR REPLACE FUNCTION public.mark_status_r1927(
  p_rollout_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_multi_site_rollouts_r1927
  SET status = p_status, updated_at = now()
  WHERE id = p_rollout_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1927',
    jsonb_build_object('rollout_id', p_rollout_id, 'status', p_status));
END;
$$;

-- 6. rollouts_behind_schedule
CREATE OR REPLACE FUNCTION public.rollouts_behind_schedule_r1927()
RETURNS TABLE(id uuid, hospital_id uuid, site_count int, sites_live_count int, target_completion_date date, status text, days_overdue int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_id, r.site_count, r.sites_live_count, r.target_completion_date, r.status,
    (CURRENT_DATE - r.target_completion_date)::int AS days_overdue
  FROM public.hospital_multi_site_rollouts_r1927 r
  WHERE r.target_completion_date IS NOT NULL
    AND r.target_completion_date < CURRENT_DATE
    AND r.status NOT IN ('live','paused')
  ORDER BY r.target_completion_date ASC
  LIMIT 100;
END;
$$;

-- 7. recent_sites
CREATE OR REPLACE FUNCTION public.recent_sites_r1927()
RETURNS TABLE(id uuid, rollout_id uuid, site_name text, site_status text, went_live_at timestamptz, by_email text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.rollout_id, s.site_name, s.site_status, s.went_live_at, s.by_email, s.created_at
  FROM public.hospital_rollout_site_log_r1927 s
  ORDER BY s.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_rollouts_r1927() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_rollout_r1927(uuid, int, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sites_r1927(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_site_r1927(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1927(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rollouts_behind_schedule_r1927() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_sites_r1927() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_rollouts_r1927() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_rollout_r1927(uuid, int, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sites_r1927(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_site_r1927(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1927(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rollouts_behind_schedule_r1927() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_sites_r1927() TO authenticated;

COMMIT;
