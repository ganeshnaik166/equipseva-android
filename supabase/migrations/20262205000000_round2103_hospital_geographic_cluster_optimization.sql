BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_geographic_cluster_optimization_r2103 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_label text NOT NULL,
  region_label text NOT NULL,
  hospital_count int NOT NULL DEFAULT 0,
  current_engineers int NOT NULL DEFAULT 0,
  optimal_engineers int NOT NULL DEFAULT 0,
  optimization_status text NOT NULL CHECK (optimization_status IN ('optimized','needs_adjustment','overstaffed','understaffed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cluster_action_log_r2103 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_id uuid NOT NULL REFERENCES public.hospital_geographic_cluster_optimization_r2103(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engineer_added','transferred','escalated','optimized','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_geographic_cluster_optimization_r2103 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cluster_action_log_r2103 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_clusters_r2103 ON public.hospital_geographic_cluster_optimization_r2103;
CREATE POLICY founder_all_clusters_r2103 ON public.hospital_geographic_cluster_optimization_r2103
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2103 ON public.hospital_cluster_action_log_r2103;
CREATE POLICY founder_all_actions_r2103 ON public.hospital_cluster_action_log_r2103
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_clusters_r2103()
RETURNS SETOF public.hospital_geographic_cluster_optimization_r2103
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_geographic_cluster_optimization_r2103 ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_cluster_r2103(
  p_cluster_label text,
  p_region_label text,
  p_hospital_count int,
  p_current_engineers int,
  p_optimal_engineers int,
  p_optimization_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_geographic_cluster_optimization_r2103(
    cluster_label, region_label, hospital_count, current_engineers, optimal_engineers, optimization_status
  ) VALUES (
    p_cluster_label, p_region_label, p_hospital_count, p_current_engineers, p_optimal_engineers, p_optimization_status
  ) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cluster_r2103',
    jsonb_build_object('id', v_id, 'cluster_label', p_cluster_label, 'status', p_optimization_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2103(p_cluster_id uuid)
RETURNS SETOF public.hospital_cluster_action_log_r2103
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_cluster_action_log_r2103 WHERE cluster_id = p_cluster_id ORDER BY taken_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2103(
  p_cluster_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_cluster_action_log_r2103(cluster_id, action_type, by_email, notes_md)
  VALUES (p_cluster_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2103',
    jsonb_build_object('id', v_id, 'cluster_id', p_cluster_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2103(p_cluster_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_geographic_cluster_optimization_r2103
    SET optimization_status = p_status, updated_at = now()
    WHERE id = p_cluster_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2103',
    jsonb_build_object('cluster_id', p_cluster_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.needs_adjustment_r2103()
RETURNS SETOF public.hospital_geographic_cluster_optimization_r2103
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_geographic_cluster_optimization_r2103
    WHERE optimization_status IN ('needs_adjustment','overstaffed','understaffed')
    ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2103()
RETURNS SETOF public.hospital_cluster_action_log_r2103
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_cluster_action_log_r2103 ORDER BY taken_at DESC LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_clusters_r2103() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cluster_r2103(text,text,int,int,int,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2103(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2103(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2103(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.needs_adjustment_r2103() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2103() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_clusters_r2103() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cluster_r2103(text,text,int,int,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2103(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2103(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2103(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.needs_adjustment_r2103() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2103() TO authenticated;

COMMIT;
