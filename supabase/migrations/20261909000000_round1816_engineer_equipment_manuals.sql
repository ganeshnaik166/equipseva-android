BEGIN;

-- =============================================================================
-- Round 1816: Engineer Equipment-Specific Manuals
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_manuals_r1816 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_name text NOT NULL,
  manufacturer text NOT NULL,
  model_number text NOT NULL,
  version_number text NOT NULL,
  manual_url text NOT NULL,
  language text NOT NULL CHECK (language IN ('english','hindi','telugu','tamil','multilingual')),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL CHECK (status IN ('current','superseded','under_review')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_manual_access_log_r1816 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manual_id uuid NOT NULL REFERENCES public.engineer_equipment_manuals_r1816(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  accessed_at timestamptz NOT NULL DEFAULT now(),
  repair_job_id uuid,
  search_query text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eem_r1816_status ON public.engineer_equipment_manuals_r1816(status);
CREATE INDEX IF NOT EXISTS idx_eem_r1816_language ON public.engineer_equipment_manuals_r1816(language);
CREATE INDEX IF NOT EXISTS idx_emal_r1816_manual ON public.engineer_manual_access_log_r1816(manual_id);
CREATE INDEX IF NOT EXISTS idx_emal_r1816_engineer ON public.engineer_manual_access_log_r1816(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_emal_r1816_accessed ON public.engineer_manual_access_log_r1816(accessed_at DESC);

ALTER TABLE public.engineer_equipment_manuals_r1816 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_manual_access_log_r1816 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eem_r1816 ON public.engineer_equipment_manuals_r1816;
CREATE POLICY founder_all_eem_r1816 ON public.engineer_equipment_manuals_r1816
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_emal_r1816 ON public.engineer_manual_access_log_r1816;
CREATE POLICY founder_all_emal_r1816 ON public.engineer_manual_access_log_r1816
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPC 1: list_manuals
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_manuals_r1816()
RETURNS TABLE(
  id uuid,
  equipment_name text,
  manufacturer text,
  model_number text,
  version_number text,
  manual_url text,
  language text,
  status text,
  last_updated_at timestamptz,
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
  SELECT m.id, m.equipment_name, m.manufacturer, m.model_number, m.version_number,
         m.manual_url, m.language, m.status, m.last_updated_at, m.created_at
  FROM public.engineer_equipment_manuals_r1816 m
  ORDER BY m.last_updated_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_manuals_r1816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_manuals_r1816() TO authenticated;

-- =============================================================================
-- RPC 2: add_manual
-- =============================================================================
CREATE OR REPLACE FUNCTION public.add_manual_r1816(
  p_equipment_name text,
  p_manufacturer text,
  p_model_number text,
  p_version_number text,
  p_manual_url text,
  p_language text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_equipment_manuals_r1816(
    equipment_name, manufacturer, model_number, version_number,
    manual_url, language, status, last_updated_at
  )
  VALUES (p_equipment_name, p_manufacturer, p_model_number, p_version_number,
          p_manual_url, p_language, p_status, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_manual_r1816',
          jsonb_build_object('id', v_id, 'equipment_name', p_equipment_name,
                             'manufacturer', p_manufacturer, 'model_number', p_model_number,
                             'version_number', p_version_number, 'language', p_language,
                             'status', p_status));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_manual_r1816(text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_manual_r1816(text, text, text, text, text, text, text) TO authenticated;

-- =============================================================================
-- RPC 3: list_access
-- =============================================================================
CREATE OR REPLACE FUNCTION public.list_access_r1816()
RETURNS TABLE(
  id uuid,
  manual_id uuid,
  equipment_name text,
  engineer_user_id uuid,
  engineer_email text,
  accessed_at timestamptz,
  repair_job_id uuid,
  search_query text
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
  SELECT a.id, a.manual_id, m.equipment_name, a.engineer_user_id,
         p.email::text, a.accessed_at, a.repair_job_id, a.search_query
  FROM public.engineer_manual_access_log_r1816 a
  LEFT JOIN public.engineer_equipment_manuals_r1816 m ON m.id = a.manual_id
  LEFT JOIN public.profiles p ON p.id = a.engineer_user_id
  ORDER BY a.accessed_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_access_r1816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_access_r1816() TO authenticated;

-- =============================================================================
-- RPC 4: log_access
-- =============================================================================
CREATE OR REPLACE FUNCTION public.log_access_r1816(
  p_manual_id uuid,
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_search_query text
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
  INSERT INTO public.engineer_manual_access_log_r1816(
    manual_id, engineer_user_id, repair_job_id, search_query, accessed_at
  )
  VALUES (p_manual_id, p_engineer_user_id, p_repair_job_id, p_search_query, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_access_r1816',
          jsonb_build_object('id', v_id, 'manual_id', p_manual_id,
                             'engineer_user_id', p_engineer_user_id,
                             'repair_job_id', p_repair_job_id,
                             'search_query', p_search_query));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_access_r1816(uuid, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_access_r1816(uuid, uuid, uuid, text) TO authenticated;

-- =============================================================================
-- RPC 5: most_accessed_manuals
-- =============================================================================
CREATE OR REPLACE FUNCTION public.most_accessed_manuals_r1816()
RETURNS TABLE(
  manual_id uuid,
  equipment_name text,
  manufacturer text,
  model_number text,
  access_count int,
  last_access timestamptz
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
  SELECT m.id, m.equipment_name, m.manufacturer, m.model_number,
         (COUNT(a.id))::int AS access_count,
         MAX(a.accessed_at) AS last_access
  FROM public.engineer_equipment_manuals_r1816 m
  LEFT JOIN public.engineer_manual_access_log_r1816 a ON a.manual_id = m.id
  GROUP BY m.id, m.equipment_name, m.manufacturer, m.model_number
  ORDER BY access_count DESC NULLS LAST, last_access DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.most_accessed_manuals_r1816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.most_accessed_manuals_r1816() TO authenticated;

-- =============================================================================
-- RPC 6: manuals_by_language
-- =============================================================================
CREATE OR REPLACE FUNCTION public.manuals_by_language_r1816()
RETURNS TABLE(
  language text,
  manual_count int,
  current_count int,
  superseded_count int,
  under_review_count int
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
  SELECT m.language,
         (COUNT(*))::int AS manual_count,
         (COUNT(*) FILTER (WHERE m.status = 'current'))::int,
         (COUNT(*) FILTER (WHERE m.status = 'superseded'))::int,
         (COUNT(*) FILTER (WHERE m.status = 'under_review'))::int
  FROM public.engineer_equipment_manuals_r1816 m
  GROUP BY m.language
  ORDER BY manual_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.manuals_by_language_r1816() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.manuals_by_language_r1816() TO authenticated;

-- =============================================================================
-- RPC 7: search_manual
-- =============================================================================
CREATE OR REPLACE FUNCTION public.search_manual_r1816(p_query text)
RETURNS TABLE(
  id uuid,
  equipment_name text,
  manufacturer text,
  model_number text,
  version_number text,
  manual_url text,
  language text,
  status text,
  last_updated_at timestamptz
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
  SELECT m.id, m.equipment_name, m.manufacturer, m.model_number, m.version_number,
         m.manual_url, m.language, m.status, m.last_updated_at
  FROM public.engineer_equipment_manuals_r1816 m
  WHERE p_query IS NULL
     OR p_query = ''
     OR m.equipment_name ILIKE '%' || p_query || '%'
     OR m.manufacturer ILIKE '%' || p_query || '%'
     OR m.model_number ILIKE '%' || p_query || '%'
  ORDER BY m.last_updated_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.search_manual_r1816(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_manual_r1816(text) TO authenticated;

COMMIT;