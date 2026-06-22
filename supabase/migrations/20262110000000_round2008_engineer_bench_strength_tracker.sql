BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_bench_strength_r2008 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  specialty text NOT NULL CHECK (specialty IN ('imaging','ventilator','anesthesia','lab','monitor','general')),
  active_engineers int NOT NULL DEFAULT 0,
  available_capacity int NOT NULL DEFAULT 0,
  demand_score int NOT NULL DEFAULT 0,
  bench_status text NOT NULL DEFAULT 'balanced' CHECK (bench_status IN ('strong','balanced','thin','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_bench_action_log_r2008 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bench_id uuid NOT NULL REFERENCES public.engineer_bench_strength_r2008(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('hired','lost_engineer','rotated','capacity_added','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_bench_strength_r2008 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_bench_action_log_r2008 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bench_strength_r2008_founder ON public.engineer_bench_strength_r2008;
CREATE POLICY bench_strength_r2008_founder ON public.engineer_bench_strength_r2008
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS bench_action_r2008_founder ON public.engineer_bench_action_log_r2008;
CREATE POLICY bench_action_r2008_founder ON public.engineer_bench_action_log_r2008
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_benches
CREATE OR REPLACE FUNCTION public.list_benches_r2008()
RETURNS SETOF public.engineer_bench_strength_r2008
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_strength_r2008 ORDER BY captured_at DESC;
END;
$$;

-- 2. log_bench
CREATE OR REPLACE FUNCTION public.log_bench_r2008(
  p_region_label text,
  p_specialty text,
  p_active_engineers int,
  p_available_capacity int,
  p_demand_score int,
  p_bench_status text
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
  INSERT INTO public.engineer_bench_strength_r2008(
    region_label, specialty, active_engineers, available_capacity, demand_score, bench_status
  ) VALUES (
    p_region_label, p_specialty, p_active_engineers, p_available_capacity, p_demand_score, p_bench_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bench_r2008',
    jsonb_build_object('bench_id', v_id, 'region', p_region_label, 'specialty', p_specialty));

  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2008(p_bench_id uuid)
RETURNS SETOF public.engineer_bench_action_log_r2008
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_action_log_r2008
    WHERE bench_id = p_bench_id ORDER BY taken_at DESC;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2008(
  p_bench_id uuid,
  p_action_type text,
  p_by_email text,
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
  INSERT INTO public.engineer_bench_action_log_r2008(bench_id, action_type, by_email, notes_md)
  VALUES (p_bench_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2008',
    jsonb_build_object('action_id', v_id, 'bench_id', p_bench_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2008(p_bench_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_bench_strength_r2008
    SET bench_status = p_status, updated_at = now()
    WHERE id = p_bench_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2008',
    jsonb_build_object('bench_id', p_bench_id, 'status', p_status));
END;
$$;

-- 6. thin_benches
CREATE OR REPLACE FUNCTION public.thin_benches_r2008()
RETURNS SETOF public.engineer_bench_strength_r2008
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_strength_r2008
    WHERE bench_status IN ('thin','critical') ORDER BY captured_at DESC;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2008(p_limit int DEFAULT 50)
RETURNS SETOF public.engineer_bench_action_log_r2008
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_bench_action_log_r2008
    ORDER BY taken_at DESC LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_benches_r2008() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_bench_r2008(text,text,int,int,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2008(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2008(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2008(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.thin_benches_r2008() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2008(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_benches_r2008() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_bench_r2008(text,text,int,int,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2008(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2008(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2008(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.thin_benches_r2008() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2008(int) TO authenticated;

COMMIT;
