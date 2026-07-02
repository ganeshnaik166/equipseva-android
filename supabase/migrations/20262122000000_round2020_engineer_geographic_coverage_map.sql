BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_geographic_coverage_map_r2020 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  total_engineers int NOT NULL DEFAULT 0,
  active_engineers int NOT NULL DEFAULT 0,
  coverage_quality text NOT NULL CHECK (coverage_quality IN ('excellent','good','fair','poor','gap')),
  area_sq_km numeric NOT NULL DEFAULT 0,
  density_score int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expanding','contracting','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_coverage_action_log_r2020 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coverage_id uuid NOT NULL REFERENCES public.engineer_geographic_coverage_map_r2020(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('hire_initiated','transfer_in','transfer_out','regional_pivot','capacity_added')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_geographic_coverage_map_r2020 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_coverage_action_log_r2020 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_coverage_r2020 ON public.engineer_geographic_coverage_map_r2020;
CREATE POLICY founder_all_coverage_r2020 ON public.engineer_geographic_coverage_map_r2020
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2020 ON public.engineer_coverage_action_log_r2020;
CREATE POLICY founder_all_actions_r2020 ON public.engineer_coverage_action_log_r2020
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_coverages_r2020()
RETURNS SETOF public.engineer_geographic_coverage_map_r2020
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_geographic_coverage_map_r2020 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_coverage_r2020(
  p_region text,
  p_total int,
  p_active int,
  p_quality text,
  p_area numeric,
  p_density int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_geographic_coverage_map_r2020(region_label,total_engineers,active_engineers,coverage_quality,area_sq_km,density_score)
  VALUES (p_region,p_total,p_active,p_quality,p_area,p_density) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_coverage_r2020', jsonb_build_object('id',v_id,'region',p_region,'quality',p_quality));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2020(p_coverage uuid)
RETURNS SETOF public.engineer_coverage_action_log_r2020
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_coverage_action_log_r2020 WHERE coverage_id = p_coverage ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2020(
  p_coverage uuid,
  p_action text,
  p_by_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_coverage_action_log_r2020(coverage_id,action_type,by_email,notes_md)
  VALUES (p_coverage,p_action,p_by_email,p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2020', jsonb_build_object('id',v_id,'coverage_id',p_coverage,'action',p_action));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2020(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_geographic_coverage_map_r2020 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2020', jsonb_build_object('id',p_id,'status',p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.gap_regions_r2020()
RETURNS SETOF public.engineer_geographic_coverage_map_r2020
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_geographic_coverage_map_r2020 WHERE coverage_quality IN ('poor','gap') ORDER BY density_score ASC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2020()
RETURNS SETOF public.engineer_coverage_action_log_r2020
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_coverage_action_log_r2020 ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_coverages_r2020() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_coverage_r2020(text,int,int,text,numeric,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2020(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2020(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2020(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.gap_regions_r2020() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2020() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_coverages_r2020() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_coverage_r2020(text,int,int,text,numeric,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2020(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2020(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2020(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.gap_regions_r2020() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2020() TO authenticated;

COMMIT;
