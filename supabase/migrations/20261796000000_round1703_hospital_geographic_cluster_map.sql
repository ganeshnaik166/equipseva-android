BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_geo_clusters_r1703 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_label text NOT NULL,
  city text NOT NULL,
  area_polygon_md text,
  hospital_count int NOT NULL DEFAULT 0,
  avg_distance_km numeric(10,2) NOT NULL DEFAULT 0,
  recommended_engineer_count int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cluster_membership_r1703 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cluster_id uuid NOT NULL REFERENCES public.hospital_geo_clusters_r1703(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  distance_to_centroid_km numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cluster_id, hospital_user_id)
);

ALTER TABLE public.hospital_geo_clusters_r1703 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cluster_membership_r1703 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1703_clusters ON public.hospital_geo_clusters_r1703;
CREATE POLICY founder_all_r1703_clusters ON public.hospital_geo_clusters_r1703
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1703_membership ON public.hospital_cluster_membership_r1703;
CREATE POLICY founder_all_r1703_membership ON public.hospital_cluster_membership_r1703
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_r1703_clusters_city ON public.hospital_geo_clusters_r1703(city);
CREATE INDEX IF NOT EXISTS idx_r1703_membership_cluster ON public.hospital_cluster_membership_r1703(cluster_id);
CREATE INDEX IF NOT EXISTS idx_r1703_membership_hospital ON public.hospital_cluster_membership_r1703(hospital_user_id);

-- 1. list_clusters
CREATE OR REPLACE FUNCTION public.r1703_list_clusters()
RETURNS TABLE (
  id uuid,
  cluster_label text,
  city text,
  hospital_count int,
  avg_distance_km numeric,
  recommended_engineer_count int,
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
  SELECT c.id, c.cluster_label, c.city, c.hospital_count, c.avg_distance_km,
         c.recommended_engineer_count, c.created_at
  FROM public.hospital_geo_clusters_r1703 c
  ORDER BY c.hospital_count DESC, c.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. define_cluster
CREATE OR REPLACE FUNCTION public.r1703_define_cluster(
  p_label text,
  p_city text,
  p_polygon_md text,
  p_recommended_engineers int
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
  INSERT INTO public.hospital_geo_clusters_r1703 (cluster_label, city, area_polygon_md, recommended_engineer_count)
  VALUES (p_label, p_city, p_polygon_md, COALESCE(p_recommended_engineers, 1))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1703_define_cluster',
          jsonb_build_object('cluster_id', v_id, 'label', p_label, 'city', p_city));
  RETURN v_id;
END;
$$;

-- 3. list_members
CREATE OR REPLACE FUNCTION public.r1703_list_members(p_cluster_id uuid)
RETURNS TABLE (
  membership_id uuid,
  hospital_user_id uuid,
  hospital_name text,
  joined_at timestamptz,
  distance_to_centroid_km numeric
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
  SELECT m.id, m.hospital_user_id,
         COALESCE(o.name, p.full_name, p.email, '') AS hospital_name,
         m.joined_at, m.distance_to_centroid_km
  FROM public.hospital_cluster_membership_r1703 m
  JOIN public.profiles p ON p.id = m.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE m.cluster_id = p_cluster_id
  ORDER BY m.distance_to_centroid_km ASC
  LIMIT 500;
END;
$$;

-- 4. add_member
CREATE OR REPLACE FUNCTION public.r1703_add_member(
  p_cluster_id uuid,
  p_hospital_user_id uuid,
  p_distance_km numeric
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
  INSERT INTO public.hospital_cluster_membership_r1703 (cluster_id, hospital_user_id, distance_to_centroid_km)
  VALUES (p_cluster_id, p_hospital_user_id, COALESCE(p_distance_km, 0))
  ON CONFLICT (cluster_id, hospital_user_id) DO UPDATE
    SET distance_to_centroid_km = EXCLUDED.distance_to_centroid_km,
        updated_at = now()
  RETURNING id INTO v_id;

  UPDATE public.hospital_geo_clusters_r1703 c
  SET hospital_count = (SELECT (COUNT(*))::int FROM public.hospital_cluster_membership_r1703 WHERE cluster_id = p_cluster_id),
      avg_distance_km = COALESCE((SELECT AVG(distance_to_centroid_km)::numeric(10,2) FROM public.hospital_cluster_membership_r1703 WHERE cluster_id = p_cluster_id), 0),
      updated_at = now()
  WHERE c.id = p_cluster_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1703_add_member',
          jsonb_build_object('cluster_id', p_cluster_id, 'hospital_user_id', p_hospital_user_id));
  RETURN v_id;
END;
$$;

-- 5. cluster_efficiency_summary
CREATE OR REPLACE FUNCTION public.r1703_cluster_efficiency_summary()
RETURNS TABLE (
  total_clusters int,
  total_clustered_hospitals int,
  avg_hospitals_per_cluster numeric,
  avg_distance_overall_km numeric,
  total_recommended_engineers int
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
    (SELECT (COUNT(*))::int FROM public.hospital_geo_clusters_r1703),
    (SELECT (COUNT(DISTINCT hospital_user_id))::int FROM public.hospital_cluster_membership_r1703),
    COALESCE((SELECT AVG(hospital_count)::numeric(10,2) FROM public.hospital_geo_clusters_r1703), 0),
    COALESCE((SELECT AVG(distance_to_centroid_km)::numeric(10,2) FROM public.hospital_cluster_membership_r1703), 0),
    COALESCE((SELECT SUM(recommended_engineer_count)::int FROM public.hospital_geo_clusters_r1703), 0);
END;
$$;

-- 6. top_dense_clusters
CREATE OR REPLACE FUNCTION public.r1703_top_dense_clusters()
RETURNS TABLE (
  id uuid,
  cluster_label text,
  city text,
  hospital_count int,
  avg_distance_km numeric,
  density_score numeric
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
  SELECT c.id, c.cluster_label, c.city, c.hospital_count, c.avg_distance_km,
         CASE WHEN c.avg_distance_km > 0
              THEN (c.hospital_count::numeric / c.avg_distance_km)::numeric(10,2)
              ELSE c.hospital_count::numeric END AS density_score
  FROM public.hospital_geo_clusters_r1703 c
  WHERE c.hospital_count > 0
  ORDER BY density_score DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- 7. hospitals_without_cluster
CREATE OR REPLACE FUNCTION public.r1703_hospitals_without_cluster()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  city text,
  active_amc boolean
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
  SELECT p.id,
         COALESCE(o.name, p.full_name, p.email, '') AS hospital_name,
         COALESCE(o.city, '') AS city,
         EXISTS (SELECT 1 FROM public.amc_contracts a WHERE a.hospital_user_id = p.id AND a.status = 'active') AS active_amc
  FROM public.profiles p
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE p.role = 'hospital'
    AND NOT EXISTS (
      SELECT 1 FROM public.hospital_cluster_membership_r1703 m WHERE m.hospital_user_id = p.id
    )
  ORDER BY hospital_name ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1703_list_clusters() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_define_cluster(text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_list_members(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_add_member(uuid, uuid, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_cluster_efficiency_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_top_dense_clusters() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1703_hospitals_without_cluster() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1703_list_clusters() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_define_cluster(text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_list_members(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_add_member(uuid, uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_cluster_efficiency_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_top_dense_clusters() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1703_hospitals_without_cluster() TO authenticated;

COMMIT;