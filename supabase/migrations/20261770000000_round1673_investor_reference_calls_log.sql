BEGIN;

-- ============================================================================
-- Round 1673 — Investor Reference Calls Log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_reference_calls_r1673 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  investor_id uuid NOT NULL,
  reference_name text NOT NULL,
  reference_org text,
  reference_email text,
  call_scheduled_at timestamptz,
  call_completed_at timestamptz,
  call_outcome text CHECK (call_outcome IN ('very_positive','positive','neutral','negative','no_show')),
  notes_md text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_reference_questions_r1673 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  call_id uuid NOT NULL REFERENCES public.investor_reference_calls_r1673(id) ON DELETE CASCADE,
  question_text text NOT NULL,
  answer_summary text,
  response_quality text CHECK (response_quality IN ('excellent','good','concerning')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ref_calls_r1673_investor ON public.investor_reference_calls_r1673(investor_id);
CREATE INDEX IF NOT EXISTS idx_ref_calls_r1673_scheduled ON public.investor_reference_calls_r1673(call_scheduled_at);
CREATE INDEX IF NOT EXISTS idx_ref_questions_r1673_call ON public.investor_reference_questions_r1673(call_id);

ALTER TABLE public.investor_reference_calls_r1673 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_reference_questions_r1673 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ref_calls_r1673 ON public.investor_reference_calls_r1673;
CREATE POLICY founder_all_ref_calls_r1673 ON public.investor_reference_calls_r1673
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ref_questions_r1673 ON public.investor_reference_questions_r1673;
CREATE POLICY founder_all_ref_questions_r1673 ON public.investor_reference_questions_r1673
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_calls
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_list_calls();
CREATE OR REPLACE FUNCTION public.r1673_list_calls()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  reference_name text,
  reference_org text,
  reference_email text,
  call_scheduled_at timestamptz,
  call_completed_at timestamptz,
  call_outcome text,
  question_count int,
  concerning_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.investor_id,
    c.reference_name,
    c.reference_org,
    c.reference_email,
    c.call_scheduled_at,
    c.call_completed_at,
    c.call_outcome,
    (COUNT(q.id))::int AS question_count,
    (COUNT(q.id) FILTER (WHERE q.response_quality = 'concerning'))::int AS concerning_count
  FROM public.investor_reference_calls_r1673 c
  LEFT JOIN public.investor_reference_questions_r1673 q ON q.call_id = c.id
  GROUP BY c.id
  ORDER BY c.call_scheduled_at DESC NULLS LAST, c.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_list_calls() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_list_calls() TO authenticated;

-- ============================================================================
-- RPC 2: schedule_call
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_schedule_call(uuid, text, text, text, timestamptz);
CREATE OR REPLACE FUNCTION public.r1673_schedule_call(
  p_investor_id uuid,
  p_reference_name text,
  p_reference_org text,
  p_reference_email text,
  p_scheduled_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_reference_calls_r1673(
    investor_id, reference_name, reference_org, reference_email, call_scheduled_at
  ) VALUES (
    p_investor_id, p_reference_name, p_reference_org, p_reference_email, p_scheduled_at
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1673_schedule_call',
    jsonb_build_object(
      'call_id', v_id,
      'investor_id', p_investor_id,
      'reference_name', p_reference_name,
      'scheduled_at', p_scheduled_at
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_schedule_call(uuid, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_schedule_call(uuid, text, text, text, timestamptz) TO authenticated;

-- ============================================================================
-- RPC 3: record_outcome
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_record_outcome(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r1673_record_outcome(
  p_call_id uuid,
  p_outcome text,
  p_notes_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_outcome NOT IN ('very_positive','positive','neutral','negative','no_show') THEN
    RAISE EXCEPTION 'invalid outcome: %', p_outcome;
  END IF;

  UPDATE public.investor_reference_calls_r1673
  SET call_outcome = p_outcome,
      notes_md = COALESCE(p_notes_md, notes_md),
      call_completed_at = COALESCE(call_completed_at, now()),
      updated_at = now()
  WHERE id = p_call_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1673_record_outcome',
    jsonb_build_object(
      'call_id', p_call_id,
      'outcome', p_outcome
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_record_outcome(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_record_outcome(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 4: list_questions
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_list_questions(uuid);
CREATE OR REPLACE FUNCTION public.r1673_list_questions(p_call_id uuid)
RETURNS TABLE (
  id uuid,
  call_id uuid,
  question_text text,
  answer_summary text,
  response_quality text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    q.id,
    q.call_id,
    q.question_text,
    q.answer_summary,
    q.response_quality,
    q.created_at
  FROM public.investor_reference_questions_r1673 q
  WHERE q.call_id = p_call_id
  ORDER BY q.created_at ASC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_list_questions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_list_questions(uuid) TO authenticated;

-- ============================================================================
-- RPC 5: add_question
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_add_question(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r1673_add_question(
  p_call_id uuid,
  p_question_text text,
  p_answer_summary text,
  p_response_quality text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_response_quality IS NOT NULL AND p_response_quality NOT IN ('excellent','good','concerning') THEN
    RAISE EXCEPTION 'invalid response_quality: %', p_response_quality;
  END IF;

  INSERT INTO public.investor_reference_questions_r1673(
    call_id, question_text, answer_summary, response_quality
  ) VALUES (
    p_call_id, p_question_text, p_answer_summary, p_response_quality
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1673_add_question',
    jsonb_build_object(
      'question_id', v_id,
      'call_id', p_call_id,
      'response_quality', p_response_quality
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_add_question(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_add_question(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 6: reference_summary_per_investor
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_reference_summary_per_investor();
CREATE OR REPLACE FUNCTION public.r1673_reference_summary_per_investor()
RETURNS TABLE (
  investor_id uuid,
  total_calls int,
  completed_calls int,
  very_positive_count int,
  positive_count int,
  neutral_count int,
  negative_count int,
  no_show_count int,
  concerning_questions int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.investor_id,
    (COUNT(*))::int AS total_calls,
    (COUNT(*) FILTER (WHERE c.call_completed_at IS NOT NULL))::int AS completed_calls,
    (COUNT(*) FILTER (WHERE c.call_outcome = 'very_positive'))::int AS very_positive_count,
    (COUNT(*) FILTER (WHERE c.call_outcome = 'positive'))::int AS positive_count,
    (COUNT(*) FILTER (WHERE c.call_outcome = 'neutral'))::int AS neutral_count,
    (COUNT(*) FILTER (WHERE c.call_outcome = 'negative'))::int AS negative_count,
    (COUNT(*) FILTER (WHERE c.call_outcome = 'no_show'))::int AS no_show_count,
    (
      SELECT (COUNT(*))::int
      FROM public.investor_reference_questions_r1673 q
      JOIN public.investor_reference_calls_r1673 c2 ON c2.id = q.call_id
      WHERE c2.investor_id = c.investor_id
        AND q.response_quality = 'concerning'
    ) AS concerning_questions
  FROM public.investor_reference_calls_r1673 c
  GROUP BY c.investor_id
  ORDER BY total_calls DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_reference_summary_per_investor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_reference_summary_per_investor() TO authenticated;

-- ============================================================================
-- RPC 7: concerning_references
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1673_concerning_references();
CREATE OR REPLACE FUNCTION public.r1673_concerning_references()
RETURNS TABLE (
  call_id uuid,
  investor_id uuid,
  reference_name text,
  reference_org text,
  call_outcome text,
  concerning_questions int,
  call_completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    c.id AS call_id,
    c.investor_id,
    c.reference_name,
    c.reference_org,
    c.call_outcome,
    (COUNT(q.id) FILTER (WHERE q.response_quality = 'concerning'))::int AS concerning_questions,
    c.call_completed_at
  FROM public.investor_reference_calls_r1673 c
  LEFT JOIN public.investor_reference_questions_r1673 q ON q.call_id = c.id
  GROUP BY c.id
  HAVING
    c.call_outcome IN ('negative','no_show')
    OR (COUNT(q.id) FILTER (WHERE q.response_quality = 'concerning')) > 0
  ORDER BY concerning_questions DESC, c.call_completed_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1673_concerning_references() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1673_concerning_references() TO authenticated;

COMMIT;