BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_vendor_feedback_r1868 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  vendor_name text NOT NULL,
  equipment_category text,
  feedback_type text NOT NULL CHECK (feedback_type IN ('quality','support','manuals','pricing','delivery','training')),
  score int NOT NULL CHECK (score BETWEEN 1 AND 5),
  feedback_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_vendor_feedback_summary_r1868 (
  vendor_name text PRIMARY KEY,
  total_responses int NOT NULL DEFAULT 0,
  avg_quality numeric(4,2),
  avg_support numeric(4,2),
  avg_manuals numeric(4,2),
  recommended boolean NOT NULL DEFAULT false,
  recomputed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_vendor_feedback_r1868 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_vendor_feedback_summary_r1868 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_feedback_r1868 ON public.engineer_vendor_feedback_r1868;
CREATE POLICY founder_all_feedback_r1868 ON public.engineer_vendor_feedback_r1868
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_summary_r1868 ON public.engineer_vendor_feedback_summary_r1868;
CREATE POLICY founder_all_summary_r1868 ON public.engineer_vendor_feedback_summary_r1868
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_evf_r1868_vendor ON public.engineer_vendor_feedback_r1868(vendor_name);
CREATE INDEX IF NOT EXISTS idx_evf_r1868_engineer ON public.engineer_vendor_feedback_r1868(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evf_r1868_recorded ON public.engineer_vendor_feedback_r1868(recorded_at DESC);

CREATE OR REPLACE FUNCTION public.list_feedback_r1868()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  vendor_name text,
  equipment_category text,
  feedback_type text,
  score int,
  feedback_md text,
  recorded_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.engineer_user_id, u.email::text AS engineer_email,
         f.vendor_name, f.equipment_category, f.feedback_type, f.score,
         f.feedback_md, f.recorded_at, f.created_at
  FROM public.engineer_vendor_feedback_r1868 f
  LEFT JOIN auth.users u ON u.id = f.engineer_user_id
  ORDER BY f.recorded_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_feedback_r1868(
  p_engineer_user_id uuid,
  p_vendor_name text,
  p_equipment_category text,
  p_feedback_type text,
  p_score int,
  p_feedback_md text
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
  INSERT INTO public.engineer_vendor_feedback_r1868(
    engineer_user_id, vendor_name, equipment_category, feedback_type, score, feedback_md
  ) VALUES (
    p_engineer_user_id, p_vendor_name, p_equipment_category, p_feedback_type, p_score, p_feedback_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_feedback_r1868',
    jsonb_build_object('id', v_id, 'vendor_name', p_vendor_name, 'feedback_type', p_feedback_type, 'score', p_score));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_summary_r1868()
RETURNS TABLE (
  vendor_name text,
  total_responses int,
  avg_quality numeric,
  avg_support numeric,
  avg_manuals numeric,
  recommended boolean,
  recomputed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.vendor_name, s.total_responses, s.avg_quality, s.avg_support, s.avg_manuals,
         s.recommended, s.recomputed_at
  FROM public.engineer_vendor_feedback_summary_r1868 s
  ORDER BY s.total_responses DESC, s.vendor_name ASC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_summary_r1868()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.engineer_vendor_feedback_summary_r1868 (
    vendor_name, total_responses, avg_quality, avg_support, avg_manuals, recommended, recomputed_at
  )
  SELECT
    vendor_name,
    COUNT(*)::int AS total_responses,
    ROUND(AVG(CASE WHEN feedback_type = 'quality' THEN score END)::numeric, 2) AS avg_quality,
    ROUND(AVG(CASE WHEN feedback_type = 'support' THEN score END)::numeric, 2) AS avg_support,
    ROUND(AVG(CASE WHEN feedback_type = 'manuals' THEN score END)::numeric, 2) AS avg_manuals,
    (AVG(score) >= 3.5) AS recommended,
    now() AS recomputed_at
  FROM public.engineer_vendor_feedback_r1868
  GROUP BY vendor_name
  ON CONFLICT (vendor_name) DO UPDATE
    SET total_responses = EXCLUDED.total_responses,
        avg_quality = EXCLUDED.avg_quality,
        avg_support = EXCLUDED.avg_support,
        avg_manuals = EXCLUDED.avg_manuals,
        recommended = EXCLUDED.recommended,
        recomputed_at = EXCLUDED.recomputed_at,
        updated_at = now();

  SELECT COUNT(*)::int INTO v_count FROM public.engineer_vendor_feedback_summary_r1868;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_summary_r1868',
    jsonb_build_object('vendor_count', v_count));
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_vendors_r1868()
RETURNS TABLE (
  vendor_name text,
  total_responses int,
  avg_quality numeric,
  avg_support numeric,
  avg_manuals numeric,
  recommended boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.vendor_name, s.total_responses, s.avg_quality, s.avg_support, s.avg_manuals, s.recommended
  FROM public.engineer_vendor_feedback_summary_r1868 s
  WHERE s.recommended = true
  ORDER BY COALESCE(s.avg_quality, 0) DESC, s.total_responses DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.vendors_to_drop_r1868()
RETURNS TABLE (
  vendor_name text,
  total_responses int,
  avg_quality numeric,
  avg_support numeric,
  avg_manuals numeric,
  recommended boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.vendor_name, s.total_responses, s.avg_quality, s.avg_support, s.avg_manuals, s.recommended
  FROM public.engineer_vendor_feedback_summary_r1868 s
  WHERE s.recommended = false AND s.total_responses >= 3
  ORDER BY COALESCE(s.avg_quality, 0) ASC, s.total_responses DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_feedback_r1868()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  vendor_name text,
  equipment_category text,
  feedback_type text,
  score int,
  feedback_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, u.email::text AS engineer_email, f.vendor_name, f.equipment_category,
         f.feedback_type, f.score, f.feedback_md, f.recorded_at
  FROM public.engineer_vendor_feedback_r1868 f
  LEFT JOIN auth.users u ON u.id = f.engineer_user_id
  WHERE f.recorded_at >= now() - interval '30 days'
  ORDER BY f.recorded_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_feedback_r1868() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_feedback_r1868(uuid, text, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_summary_r1868() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_summary_r1868() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_vendors_r1868() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vendors_to_drop_r1868() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_feedback_r1868() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_feedback_r1868() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_feedback_r1868(uuid, text, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_summary_r1868() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_summary_r1868() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_vendors_r1868() TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendors_to_drop_r1868() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_feedback_r1868() TO authenticated;

COMMIT;