BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_free_trials_r1787 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trial_start timestamptz NOT NULL DEFAULT now(),
  trial_end timestamptz NOT NULL,
  trial_type text NOT NULL CHECK (trial_type IN ('pilot_amc','free_repair_quota','extended_warranty','first_month')),
  trial_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','converted','extended','lost')),
  converted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_trial_conversion_efforts_r1787 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trial_id uuid NOT NULL REFERENCES public.hospital_free_trials_r1787(id) ON DELETE CASCADE,
  effort_type text NOT NULL CHECK (effort_type IN ('upgrade_offer','discount','founder_call','customer_event','case_study')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_free_trials_r1787 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_trial_conversion_efforts_r1787 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_trials_r1787 ON public.hospital_free_trials_r1787;
CREATE POLICY founder_all_trials_r1787 ON public.hospital_free_trials_r1787
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_efforts_r1787 ON public.hospital_trial_conversion_efforts_r1787;
CREATE POLICY founder_all_efforts_r1787 ON public.hospital_trial_conversion_efforts_r1787
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_trials_r1787_status ON public.hospital_free_trials_r1787(status);
CREATE INDEX IF NOT EXISTS idx_trials_r1787_end ON public.hospital_free_trials_r1787(trial_end);
CREATE INDEX IF NOT EXISTS idx_efforts_r1787_trial ON public.hospital_trial_conversion_efforts_r1787(trial_id);

-- 1. list_trials
DROP FUNCTION IF EXISTS public.list_trials_r1787();
CREATE OR REPLACE FUNCTION public.list_trials_r1787()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  trial_start timestamptz,
  trial_end timestamptz,
  trial_type text,
  trial_value_rupees bigint,
  status text,
  converted_at timestamptz,
  efforts_count int
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
    t.id,
    t.hospital_user_id,
    p.email::text,
    t.trial_start,
    t.trial_end,
    t.trial_type,
    t.trial_value_rupees,
    t.status,
    t.converted_at,
    (SELECT COUNT(*) FROM public.hospital_trial_conversion_efforts_r1787 e WHERE e.trial_id = t.id)::int
  FROM public.hospital_free_trials_r1787 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  ORDER BY t.trial_end ASC
  LIMIT 200;
END;
$$;

-- 2. log_trial
DROP FUNCTION IF EXISTS public.log_trial_r1787(uuid, timestamptz, timestamptz, text, bigint);
CREATE OR REPLACE FUNCTION public.log_trial_r1787(
  p_hospital_user_id uuid,
  p_trial_start timestamptz,
  p_trial_end timestamptz,
  p_trial_type text,
  p_trial_value_rupees bigint
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
  INSERT INTO public.hospital_free_trials_r1787(hospital_user_id, trial_start, trial_end, trial_type, trial_value_rupees)
  VALUES (p_hospital_user_id, p_trial_start, p_trial_end, p_trial_type, p_trial_value_rupees)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trial_r1787',
    jsonb_build_object('trial_id', v_id, 'hospital_user_id', p_hospital_user_id, 'trial_type', p_trial_type, 'value_rupees', p_trial_value_rupees));

  RETURN v_id;
END;
$$;

-- 3. list_efforts
DROP FUNCTION IF EXISTS public.list_efforts_r1787(uuid);
CREATE OR REPLACE FUNCTION public.list_efforts_r1787(p_trial_id uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  trial_id uuid,
  effort_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
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
  SELECT e.id, e.trial_id, e.effort_type, e.taken_at, e.by_email, e.outcome
  FROM public.hospital_trial_conversion_efforts_r1787 e
  WHERE (p_trial_id IS NULL OR e.trial_id = p_trial_id)
  ORDER BY e.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_effort
DROP FUNCTION IF EXISTS public.log_effort_r1787(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_effort_r1787(
  p_trial_id uuid,
  p_effort_type text,
  p_by_email text,
  p_outcome text
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
  INSERT INTO public.hospital_trial_conversion_efforts_r1787(trial_id, effort_type, by_email, outcome)
  VALUES (p_trial_id, p_effort_type, p_by_email, p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_effort_r1787',
    jsonb_build_object('effort_id', v_id, 'trial_id', p_trial_id, 'effort_type', p_effort_type));

  RETURN v_id;
END;
$$;

-- 5. mark_converted
DROP FUNCTION IF EXISTS public.mark_converted_r1787(uuid);
CREATE OR REPLACE FUNCTION public.mark_converted_r1787(p_trial_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.hospital_free_trials_r1787
  SET status = 'converted', converted_at = now(), updated_at = now()
  WHERE id = p_trial_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_converted_r1787',
    jsonb_build_object('trial_id', p_trial_id));
END;
$$;

-- 6. conversion_rate_summary
DROP FUNCTION IF EXISTS public.conversion_rate_summary_r1787();
CREATE OR REPLACE FUNCTION public.conversion_rate_summary_r1787()
RETURNS TABLE(
  trial_type text,
  total_trials int,
  converted int,
  expired int,
  active int,
  lost int,
  conversion_pct numeric,
  total_value_rupees bigint
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
    t.trial_type,
    COUNT(*)::int AS total_trials,
    (COUNT(*) FILTER (WHERE t.status = 'converted'))::int AS converted,
    (COUNT(*) FILTER (WHERE t.status = 'expired'))::int AS expired,
    (COUNT(*) FILTER (WHERE t.status = 'active'))::int AS active,
    (COUNT(*) FILTER (WHERE t.status = 'lost'))::int AS lost,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE t.status = 'converted'))::numeric / COUNT(*)::numeric, 2)
      ELSE 0
    END AS conversion_pct,
    COALESCE(SUM(t.trial_value_rupees), 0)::bigint
  FROM public.hospital_free_trials_r1787 t
  GROUP BY t.trial_type
  ORDER BY t.trial_type;
END;
$$;

-- 7. expiring_trials
DROP FUNCTION IF EXISTS public.expiring_trials_r1787(int);
CREATE OR REPLACE FUNCTION public.expiring_trials_r1787(p_days_ahead int DEFAULT 7)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  trial_end timestamptz,
  days_remaining int,
  trial_type text,
  trial_value_rupees bigint,
  status text
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
    t.id,
    t.hospital_user_id,
    p.email::text,
    t.trial_end,
    EXTRACT(DAY FROM (t.trial_end - now()))::int AS days_remaining,
    t.trial_type,
    t.trial_value_rupees,
    t.status
  FROM public.hospital_free_trials_r1787 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  WHERE t.status = 'active'
    AND t.trial_end <= (now() + (p_days_ahead || ' days')::interval)
    AND t.trial_end >= now()
  ORDER BY t.trial_end ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_trials_r1787() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trials_r1787() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_trial_r1787(uuid, timestamptz, timestamptz, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_trial_r1787(uuid, timestamptz, timestamptz, text, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_efforts_r1787(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_efforts_r1787(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_effort_r1787(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_effort_r1787(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_converted_r1787(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_converted_r1787(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.conversion_rate_summary_r1787() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conversion_rate_summary_r1787() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.expiring_trials_r1787(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_trials_r1787(int) TO authenticated;

COMMIT;