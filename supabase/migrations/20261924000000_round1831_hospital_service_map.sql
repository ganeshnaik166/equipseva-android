BEGIN;

-- ============================================================
-- Round 1831 — Hospital Service Map
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_geo_locations_r1831 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude numeric(10,6) NOT NULL,
  longitude numeric(10,6) NOT NULL,
  city text,
  area text,
  last_geo_updated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsgl_r1831_hospital ON public.hospital_service_geo_locations_r1831(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hsgl_r1831_area ON public.hospital_service_geo_locations_r1831(area);
CREATE INDEX IF NOT EXISTS idx_hsgl_r1831_city ON public.hospital_service_geo_locations_r1831(city);

CREATE TABLE IF NOT EXISTS public.hospital_service_geo_hotspots_r1831 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  area text NOT NULL,
  total_jobs_30d int NOT NULL DEFAULT 0,
  avg_response_min int NOT NULL DEFAULT 0,
  density_score int NOT NULL DEFAULT 0,
  recommended_engineer_cluster int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsgh_r1831_area ON public.hospital_service_geo_hotspots_r1831(area);
CREATE INDEX IF NOT EXISTS idx_hsgh_r1831_density ON public.hospital_service_geo_hotspots_r1831(density_score DESC);

ALTER TABLE public.hospital_service_geo_locations_r1831 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_geo_hotspots_r1831 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hsgl_r1831 ON public.hospital_service_geo_locations_r1831;
CREATE POLICY founder_all_hsgl_r1831 ON public.hospital_service_geo_locations_r1831
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hsgh_r1831 ON public.hospital_service_geo_hotspots_r1831;
CREATE POLICY founder_all_hsgh_r1831 ON public.hospital_service_geo_hotspots_r1831
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- 7 RPCs
-- ============================================================

-- 1. list_locations
DROP FUNCTION IF EXISTS public.list_hospital_service_geo_locations_r1831();
CREATE FUNCTION public.list_hospital_service_geo_locations_r1831()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  latitude numeric,
  longitude numeric,
  city text,
  area text,
  last_geo_updated_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.hospital_user_id,
         COALESCE(o.name, p.full_name, p.email),
         l.latitude, l.longitude, l.city, l.area, l.last_geo_updated_at, l.status
  FROM public.hospital_service_geo_locations_r1831 l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY l.last_geo_updated_at DESC
  LIMIT 500;
END;
$$;

-- 2. set_location
DROP FUNCTION IF EXISTS public.set_hospital_service_geo_location_r1831(uuid, numeric, numeric, text, text, text);
CREATE FUNCTION public.set_hospital_service_geo_location_r1831(
  p_hospital_user_id uuid,
  p_latitude numeric,
  p_longitude numeric,
  p_city text,
  p_area text,
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

  INSERT INTO public.hospital_service_geo_locations_r1831
    (hospital_user_id, latitude, longitude, city, area, last_geo_updated_at, status)
  VALUES (p_hospital_user_id, p_latitude, p_longitude, p_city, p_area, now(), COALESCE(p_status,'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_hospital_service_geo_location_r1831',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'area', p_area));

  RETURN v_id;
END;
$$;

-- 3. list_hotspots
DROP FUNCTION IF EXISTS public.list_hospital_service_geo_hotspots_r1831();
CREATE FUNCTION public.list_hospital_service_geo_hotspots_r1831()
RETURNS TABLE (
  id uuid,
  area text,
  total_jobs_30d int,
  avg_response_min int,
  density_score int,
  recommended_engineer_cluster int,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.area, h.total_jobs_30d, h.avg_response_min,
         h.density_score, h.recommended_engineer_cluster, h.updated_at
  FROM public.hospital_service_geo_hotspots_r1831 h
  ORDER BY h.density_score DESC
  LIMIT 200;
END;
$$;

-- 4. refresh_hotspots
DROP FUNCTION IF EXISTS public.refresh_hospital_service_geo_hotspots_r1831();
CREATE FUNCTION public.refresh_hospital_service_geo_hotspots_r1831()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM public.hospital_service_geo_hotspots_r1831;

  INSERT INTO public.hospital_service_geo_hotspots_r1831
    (area, total_jobs_30d, avg_response_min, density_score, recommended_engineer_cluster)
  SELECT
    COALESCE(l.area, 'unknown'),
    (COUNT(rj.id))::int,
    0,
    (COUNT(rj.id) * 10)::int,
    GREATEST(1, (COUNT(rj.id) / 20)::int)
  FROM public.hospital_service_geo_locations_r1831 l
  LEFT JOIN public.repair_jobs rj
    ON rj.hospital_id = l.hospital_user_id
   AND rj.completed_at >= now() - interval '30 days'
  GROUP BY COALESCE(l.area, 'unknown');

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_hospital_service_geo_hotspots_r1831',
          jsonb_build_object('rows', v_count));

  RETURN v_count;
END;
$$;

-- 5. dense_areas
DROP FUNCTION IF EXISTS public.dense_hospital_service_geo_areas_r1831();
CREATE FUNCTION public.dense_hospital_service_geo_areas_r1831()
RETURNS TABLE (
  area text,
  density_score int,
  total_jobs_30d int,
  recommended_engineer_cluster int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.area, h.density_score, h.total_jobs_30d, h.recommended_engineer_cluster
  FROM public.hospital_service_geo_hotspots_r1831 h
  WHERE h.density_score >= 50
  ORDER BY h.density_score DESC
  LIMIT 50;
END;
$$;

-- 6. underserved_areas
DROP FUNCTION IF EXISTS public.underserved_hospital_service_geo_areas_r1831();
CREATE FUNCTION public.underserved_hospital_service_geo_areas_r1831()
RETURNS TABLE (
  area text,
  density_score int,
  total_jobs_30d int,
  recommended_engineer_cluster int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.area, h.density_score, h.total_jobs_30d, h.recommended_engineer_cluster
  FROM public.hospital_service_geo_hotspots_r1831 h
  WHERE h.density_score < 50
  ORDER BY h.density_score ASC
  LIMIT 50;
END;
$$;

-- 7. geo_distribution
DROP FUNCTION IF EXISTS public.hospital_service_geo_distribution_r1831();
CREATE FUNCTION public.hospital_service_geo_distribution_r1831()
RETURNS TABLE (
  city text,
  total_locations int,
  active_locations int,
  inactive_locations int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(l.city, 'unknown'),
         (COUNT(*))::int,
         (COUNT(*) FILTER (WHERE l.status = 'active'))::int,
         (COUNT(*) FILTER (WHERE l.status = 'inactive'))::int
  FROM public.hospital_service_geo_locations_r1831 l
  GROUP BY COALESCE(l.city, 'unknown')
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;

-- REVOKE + GRANT
REVOKE EXECUTE ON FUNCTION public.list_hospital_service_geo_locations_r1831() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_hospital_service_geo_location_r1831(uuid, numeric, numeric, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_hospital_service_geo_hotspots_r1831() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_hospital_service_geo_hotspots_r1831() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dense_hospital_service_geo_areas_r1831() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.underserved_hospital_service_geo_areas_r1831() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hospital_service_geo_distribution_r1831() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_service_geo_locations_r1831() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_hospital_service_geo_location_r1831(uuid, numeric, numeric, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hospital_service_geo_hotspots_r1831() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_hospital_service_geo_hotspots_r1831() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dense_hospital_service_geo_areas_r1831() TO authenticated;
GRANT EXECUTE ON FUNCTION public.underserved_hospital_service_geo_areas_r1831() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hospital_service_geo_distribution_r1831() TO authenticated;

COMMIT;