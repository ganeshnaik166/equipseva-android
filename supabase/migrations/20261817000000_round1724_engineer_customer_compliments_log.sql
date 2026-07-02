BEGIN;

-- Round r1724 — Engineer Customer Compliments Log
-- HEAVY founder-console feature: hospital praise/thank-you notes per engineer

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_compliments_r1724 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  compliment_text text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  source text NOT NULL CHECK (source IN ('call','email','in_person','sms','whatsapp')),
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive')),
  used_in_review boolean NOT NULL DEFAULT false,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_comp_r1724_engineer ON public.engineer_compliments_r1724(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_comp_r1724_received ON public.engineer_compliments_r1724(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng_comp_r1724_used ON public.engineer_compliments_r1724(used_in_review);

CREATE TABLE IF NOT EXISTS public.engineer_compliment_responses_r1724 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliment_id uuid NOT NULL REFERENCES public.engineer_compliments_r1724(id) ON DELETE CASCADE,
  response_type text NOT NULL CHECK (response_type IN ('thank_you_call','featured_in_newsletter','cash_bonus','badge_awarded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_comp_resp_r1724_comp ON public.engineer_compliment_responses_r1724(compliment_id);
CREATE INDEX IF NOT EXISTS idx_eng_comp_resp_r1724_taken ON public.engineer_compliment_responses_r1724(taken_at DESC);

-- =============================================================================
-- RLS
-- =============================================================================

ALTER TABLE public.engineer_compliments_r1724 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_compliment_responses_r1724 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eng_comp_r1724 ON public.engineer_compliments_r1724;
CREATE POLICY founder_all_eng_comp_r1724 ON public.engineer_compliments_r1724
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eng_comp_resp_r1724 ON public.engineer_compliment_responses_r1724;
CREATE POLICY founder_all_eng_comp_resp_r1724 ON public.engineer_compliment_responses_r1724
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs (7)
-- =============================================================================

-- 1) list_compliments
DROP FUNCTION IF EXISTS public.list_compliments_r1724(int);
CREATE OR REPLACE FUNCTION public.list_compliments_r1724(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_user_id uuid,
  hospital_email text,
  compliment_text text,
  received_at timestamptz,
  source text,
  sentiment text,
  used_in_review boolean,
  used_at timestamptz,
  response_count int
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
      c.id,
      c.engineer_user_id,
      pe.email,
      c.hospital_user_id,
      ph.email,
      c.compliment_text,
      c.received_at,
      c.source,
      c.sentiment,
      c.used_in_review,
      c.used_at,
      (SELECT COUNT(*) FROM public.engineer_compliment_responses_r1724 r WHERE r.compliment_id = c.id)::int
    FROM public.engineer_compliments_r1724 c
    LEFT JOIN public.profiles pe ON pe.id = c.engineer_user_id
    LEFT JOIN public.profiles ph ON ph.id = c.hospital_user_id
    ORDER BY c.received_at DESC
    LIMIT COALESCE(p_limit, 100);
END;
$$;

-- 2) log_compliment
DROP FUNCTION IF EXISTS public.log_compliment_r1724(uuid, uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_compliment_r1724(
  p_engineer_user_id uuid,
  p_hospital_user_id uuid,
  p_compliment_text text,
  p_source text,
  p_sentiment text
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
  INSERT INTO public.engineer_compliments_r1724 (
    engineer_user_id, hospital_user_id, compliment_text, source, sentiment
  ) VALUES (
    p_engineer_user_id, p_hospital_user_id, p_compliment_text, p_source, p_sentiment
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1724.log_compliment',
    jsonb_build_object(
      'compliment_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'hospital_user_id', p_hospital_user_id,
      'source', p_source,
      'sentiment', p_sentiment
    )
  );
  RETURN v_id;
END;
$$;

-- 3) list_responses
DROP FUNCTION IF EXISTS public.list_responses_r1724(uuid);
CREATE OR REPLACE FUNCTION public.list_responses_r1724(
  p_compliment_id uuid
)
RETURNS TABLE (
  id uuid,
  compliment_id uuid,
  response_type text,
  taken_at timestamptz,
  by_email text,
  note text
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
    SELECT r.id, r.compliment_id, r.response_type, r.taken_at, r.by_email, r.note
    FROM public.engineer_compliment_responses_r1724 r
    WHERE r.compliment_id = p_compliment_id
    ORDER BY r.taken_at DESC;
END;
$$;

-- 4) add_response
DROP FUNCTION IF EXISTS public.add_response_r1724(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_response_r1724(
  p_compliment_id uuid,
  p_response_type text,
  p_by_email text,
  p_note text
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
  INSERT INTO public.engineer_compliment_responses_r1724 (
    compliment_id, response_type, by_email, note
  ) VALUES (
    p_compliment_id, p_response_type, p_by_email, p_note
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1724.add_response',
    jsonb_build_object(
      'response_id', v_id,
      'compliment_id', p_compliment_id,
      'response_type', p_response_type
    )
  );
  RETURN v_id;
END;
$$;

-- 5) mark_used_in_review
DROP FUNCTION IF EXISTS public.mark_used_in_review_r1724(uuid);
CREATE OR REPLACE FUNCTION public.mark_used_in_review_r1724(
  p_compliment_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_compliments_r1724
    SET used_in_review = true,
        used_at = now(),
        updated_at = now()
  WHERE id = p_compliment_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1724.mark_used_in_review',
    jsonb_build_object('compliment_id', p_compliment_id)
  );
  RETURN true;
END;
$$;

-- 6) top_complimented_engineers
DROP FUNCTION IF EXISTS public.top_complimented_engineers_r1724(int, int);
CREATE OR REPLACE FUNCTION public.top_complimented_engineers_r1724(
  p_days int DEFAULT 90,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  compliment_count int,
  very_positive_count int,
  positive_count int,
  used_in_review_count int,
  last_received_at timestamptz
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
      c.engineer_user_id,
      p.email,
      COUNT(*)::int,
      (COUNT(*) FILTER (WHERE c.sentiment = 'very_positive'))::int,
      (COUNT(*) FILTER (WHERE c.sentiment = 'positive'))::int,
      (COUNT(*) FILTER (WHERE c.used_in_review))::int,
      MAX(c.received_at)
    FROM public.engineer_compliments_r1724 c
    LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
    WHERE c.received_at >= now() - (COALESCE(p_days, 90) || ' days')::interval
    GROUP BY c.engineer_user_id, p.email
    ORDER BY COUNT(*) DESC, MAX(c.received_at) DESC
    LIMIT COALESCE(p_limit, 20);
END;
$$;

-- 7) recent_compliment_summary
DROP FUNCTION IF EXISTS public.recent_compliment_summary_r1724(int);
CREATE OR REPLACE FUNCTION public.recent_compliment_summary_r1724(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  total_compliments int,
  very_positive_count int,
  positive_count int,
  unique_engineers int,
  unique_hospitals int,
  used_in_review_count int,
  with_response_count int,
  call_count int,
  email_count int,
  in_person_count int,
  sms_count int,
  whatsapp_count int
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
      COUNT(*)::int,
      (COUNT(*) FILTER (WHERE c.sentiment = 'very_positive'))::int,
      (COUNT(*) FILTER (WHERE c.sentiment = 'positive'))::int,
      COUNT(DISTINCT c.engineer_user_id)::int,
      COUNT(DISTINCT c.hospital_user_id)::int,
      (COUNT(*) FILTER (WHERE c.used_in_review))::int,
      (COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1 FROM public.engineer_compliment_responses_r1724 r WHERE r.compliment_id = c.id
      )))::int,
      (COUNT(*) FILTER (WHERE c.source = 'call'))::int,
      (COUNT(*) FILTER (WHERE c.source = 'email'))::int,
      (COUNT(*) FILTER (WHERE c.source = 'in_person'))::int,
      (COUNT(*) FILTER (WHERE c.source = 'sms'))::int,
      (COUNT(*) FILTER (WHERE c.source = 'whatsapp'))::int
    FROM public.engineer_compliments_r1724 c
    WHERE c.received_at >= now() - (COALESCE(p_days, 30) || ' days')::interval;
END;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.list_compliments_r1724(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_compliments_r1724(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_compliment_r1724(uuid, uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_compliment_r1724(uuid, uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_responses_r1724(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_responses_r1724(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.add_response_r1724(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_response_r1724(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_used_in_review_r1724(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_used_in_review_r1724(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_complimented_engineers_r1724(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_complimented_engineers_r1724(int, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_compliment_summary_r1724(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_compliment_summary_r1724(int) TO authenticated;

COMMIT;