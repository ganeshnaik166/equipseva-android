BEGIN;

-- ============================================================================
-- Round 1726: Founder Inspiration Library
-- Books/articles/podcasts founder consumed + key takeaways + applications
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_inspirations_r1726 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type text NOT NULL CHECK (source_type IN ('book','article','podcast','talk','movie','conversation')),
  title text NOT NULL,
  author text,
  consumed_at timestamptz NOT NULL DEFAULT now(),
  key_takeaways_md text,
  would_recommend boolean NOT NULL DEFAULT false,
  rating int CHECK (rating IS NULL OR (rating >= 1 AND rating <= 10)),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_inspiration_applications_r1726 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspiration_id uuid NOT NULL REFERENCES public.founder_inspirations_r1726(id) ON DELETE CASCADE,
  applied_to text NOT NULL,
  application_note text,
  applied_at timestamptz NOT NULL DEFAULT now(),
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fi_r1726_consumed ON public.founder_inspirations_r1726(consumed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fi_r1726_rating ON public.founder_inspirations_r1726(rating DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_fia_r1726_insp ON public.founder_inspiration_applications_r1726(inspiration_id);
CREATE INDEX IF NOT EXISTS idx_fia_r1726_applied ON public.founder_inspiration_applications_r1726(applied_at DESC);

ALTER TABLE public.founder_inspirations_r1726 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_inspiration_applications_r1726 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fi_r1726_founder ON public.founder_inspirations_r1726;
CREATE POLICY p_fi_r1726_founder ON public.founder_inspirations_r1726
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fia_r1726_founder ON public.founder_inspiration_applications_r1726;
CREATE POLICY p_fia_r1726_founder ON public.founder_inspiration_applications_r1726
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_inspirations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_inspirations_r1726()
RETURNS TABLE(
  id uuid,
  source_type text,
  title text,
  author text,
  consumed_at timestamptz,
  rating int,
  would_recommend boolean,
  app_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    fi.id,
    fi.source_type,
    fi.title,
    fi.author,
    fi.consumed_at,
    fi.rating,
    fi.would_recommend,
    (SELECT COUNT(*) FROM public.founder_inspiration_applications_r1726 a WHERE a.inspiration_id = fi.id)::int AS app_count
  FROM public.founder_inspirations_r1726 fi
  ORDER BY fi.consumed_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_inspiration
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_inspiration_r1726(
  p_source_type text,
  p_title text,
  p_author text,
  p_key_takeaways_md text,
  p_would_recommend boolean,
  p_rating int
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
  INSERT INTO public.founder_inspirations_r1726(source_type, title, author, key_takeaways_md, would_recommend, rating)
  VALUES (p_source_type, p_title, p_author, p_key_takeaways_md, COALESCE(p_would_recommend, false), p_rating)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_inspiration_r1726',
    jsonb_build_object('inspiration_id', v_id, 'title', p_title, 'source_type', p_source_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_applications
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_applications_r1726()
RETURNS TABLE(
  id uuid,
  inspiration_id uuid,
  inspiration_title text,
  applied_to text,
  application_note text,
  applied_at timestamptz,
  has_outcome boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.inspiration_id,
    fi.title AS inspiration_title,
    a.applied_to,
    a.application_note,
    a.applied_at,
    (a.outcome_md IS NOT NULL AND length(a.outcome_md) > 0) AS has_outcome
  FROM public.founder_inspiration_applications_r1726 a
  JOIN public.founder_inspirations_r1726 fi ON fi.id = a.inspiration_id
  ORDER BY a.applied_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_application
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_application_r1726(
  p_inspiration_id uuid,
  p_applied_to text,
  p_application_note text,
  p_outcome_md text
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
  INSERT INTO public.founder_inspiration_applications_r1726(inspiration_id, applied_to, application_note, outcome_md)
  VALUES (p_inspiration_id, p_applied_to, p_application_note, p_outcome_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_application_r1726',
    jsonb_build_object('application_id', v_id, 'inspiration_id', p_inspiration_id, 'applied_to', p_applied_to));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: top_rated
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_rated_r1726()
RETURNS TABLE(
  id uuid,
  source_type text,
  title text,
  author text,
  rating int,
  would_recommend boolean,
  consumed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    fi.id,
    fi.source_type,
    fi.title,
    fi.author,
    fi.rating,
    fi.would_recommend,
    fi.consumed_at
  FROM public.founder_inspirations_r1726 fi
  WHERE fi.rating IS NOT NULL AND fi.rating >= 8
  ORDER BY fi.rating DESC NULLS LAST, fi.consumed_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- RPC 6: recent_takeaways
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_takeaways_r1726()
RETURNS TABLE(
  id uuid,
  title text,
  source_type text,
  consumed_at timestamptz,
  key_takeaways_md text,
  rating int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    fi.id,
    fi.title,
    fi.source_type,
    fi.consumed_at,
    fi.key_takeaways_md,
    fi.rating
  FROM public.founder_inspirations_r1726 fi
  WHERE fi.key_takeaways_md IS NOT NULL AND length(fi.key_takeaways_md) > 0
  ORDER BY fi.consumed_at DESC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- RPC 7: applied_inspirations_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.applied_inspirations_summary_r1726()
RETURNS TABLE(
  source_type text,
  total_inspirations int,
  applied_count int,
  recommend_count int,
  avg_rating numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    fi.source_type,
    COUNT(*)::int AS total_inspirations,
    (COUNT(*) FILTER (WHERE EXISTS (
      SELECT 1 FROM public.founder_inspiration_applications_r1726 a WHERE a.inspiration_id = fi.id
    )))::int AS applied_count,
    (COUNT(*) FILTER (WHERE fi.would_recommend))::int AS recommend_count,
    ROUND(AVG(fi.rating)::numeric, 2) AS avg_rating
  FROM public.founder_inspirations_r1726 fi
  GROUP BY fi.source_type
  ORDER BY total_inspirations DESC;
END;
$$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_inspirations_r1726() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_inspiration_r1726(text, text, text, text, boolean, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_applications_r1726() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_application_r1726(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_rated_r1726() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_takeaways_r1726() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.applied_inspirations_summary_r1726() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_inspirations_r1726() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_inspiration_r1726(text, text, text, text, boolean, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_applications_r1726() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_application_r1726(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_rated_r1726() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_takeaways_r1726() TO authenticated;
GRANT EXECUTE ON FUNCTION public.applied_inspirations_summary_r1726() TO authenticated;

COMMIT;