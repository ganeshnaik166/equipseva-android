BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_hire_pipeline_r1786 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_title text NOT NULL,
  role_type text NOT NULL CHECK (role_type IN ('engineering','sales','operations','finance','marketing','executive')),
  candidate_name text NOT NULL,
  candidate_email text,
  current_stage text NOT NULL DEFAULT 'sourced' CHECK (current_stage IN ('sourced','screening','interviewing','reference','offer','declined','hired')),
  expected_close date,
  founder_priority text NOT NULL DEFAULT 'medium' CHECK (founder_priority IN ('critical','high','medium','low')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_hire_pipeline_notes_r1786 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.founder_hire_pipeline_r1786(id) ON DELETE CASCADE,
  note_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note_md text NOT NULL,
  decision_impact text NOT NULL DEFAULT 'neutral' CHECK (decision_impact IN ('positive','neutral','negative','blocker')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_hire_pipeline_r1786 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_hire_pipeline_notes_r1786 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pipeline_r1786 ON public.founder_hire_pipeline_r1786;
CREATE POLICY founder_all_pipeline_r1786 ON public.founder_hire_pipeline_r1786
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_notes_r1786 ON public.founder_hire_pipeline_notes_r1786;
CREATE POLICY founder_all_notes_r1786 ON public.founder_hire_pipeline_notes_r1786
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pipeline_r1786_stage ON public.founder_hire_pipeline_r1786(current_stage);
CREATE INDEX IF NOT EXISTS idx_pipeline_r1786_priority ON public.founder_hire_pipeline_r1786(founder_priority);
CREATE INDEX IF NOT EXISTS idx_notes_r1786_pipeline ON public.founder_hire_pipeline_notes_r1786(pipeline_id, note_at DESC);

-- RPC 1: list_pipeline
DROP FUNCTION IF EXISTS public.list_pipeline_r1786();
CREATE OR REPLACE FUNCTION public.list_pipeline_r1786()
RETURNS TABLE (
  id uuid,
  role_title text,
  role_type text,
  candidate_name text,
  candidate_email text,
  current_stage text,
  expected_close date,
  founder_priority text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.role_title, p.role_type, p.candidate_name, p.candidate_email,
         p.current_stage, p.expected_close, p.founder_priority, p.created_at
  FROM public.founder_hire_pipeline_r1786 p
  ORDER BY
    CASE p.founder_priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    p.created_at DESC;
END;
$$;

-- RPC 2: add_candidate
DROP FUNCTION IF EXISTS public.add_candidate_r1786(text, text, text, text, text, date, text);
CREATE OR REPLACE FUNCTION public.add_candidate_r1786(
  p_role_title text,
  p_role_type text,
  p_candidate_name text,
  p_candidate_email text,
  p_current_stage text,
  p_expected_close date,
  p_founder_priority text
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
  INSERT INTO public.founder_hire_pipeline_r1786 (role_title, role_type, candidate_name, candidate_email, current_stage, expected_close, founder_priority)
  VALUES (p_role_title, p_role_type, p_candidate_name, p_candidate_email, COALESCE(p_current_stage,'sourced'), p_expected_close, COALESCE(p_founder_priority,'medium'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_candidate_r1786',
          jsonb_build_object('id', v_id, 'role_title', p_role_title, 'candidate_name', p_candidate_name));
  RETURN v_id;
END;
$$;

-- RPC 3: list_notes
DROP FUNCTION IF EXISTS public.list_notes_r1786(uuid);
CREATE OR REPLACE FUNCTION public.list_notes_r1786(p_pipeline_id uuid)
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  note_at timestamptz,
  by_email text,
  note_md text,
  decision_impact text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.pipeline_id, n.note_at, n.by_email, n.note_md, n.decision_impact
  FROM public.founder_hire_pipeline_notes_r1786 n
  WHERE n.pipeline_id = p_pipeline_id
  ORDER BY n.note_at DESC;
END;
$$;

-- RPC 4: add_note
DROP FUNCTION IF EXISTS public.add_note_r1786(uuid, text, text);
CREATE OR REPLACE FUNCTION public.add_note_r1786(
  p_pipeline_id uuid,
  p_note_md text,
  p_decision_impact text
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
  INSERT INTO public.founder_hire_pipeline_notes_r1786 (pipeline_id, by_email, note_md, decision_impact)
  VALUES (p_pipeline_id, (auth.jwt()->>'email'), p_note_md, COALESCE(p_decision_impact,'neutral'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_note_r1786',
          jsonb_build_object('id', v_id, 'pipeline_id', p_pipeline_id, 'decision_impact', p_decision_impact));
  RETURN v_id;
END;
$$;

-- RPC 5: advance_stage
DROP FUNCTION IF EXISTS public.advance_stage_r1786(uuid, text);
CREATE OR REPLACE FUNCTION public.advance_stage_r1786(
  p_pipeline_id uuid,
  p_new_stage text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_stage NOT IN ('sourced','screening','interviewing','reference','offer','declined','hired') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;

  UPDATE public.founder_hire_pipeline_r1786
  SET current_stage = p_new_stage, updated_at = now()
  WHERE id = p_pipeline_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'advance_stage_r1786',
          jsonb_build_object('id', p_pipeline_id, 'new_stage', p_new_stage));
END;
$$;

-- RPC 6: stage_summary
DROP FUNCTION IF EXISTS public.stage_summary_r1786();
CREATE OR REPLACE FUNCTION public.stage_summary_r1786()
RETURNS TABLE (
  stage text,
  total int,
  critical_count int,
  high_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.current_stage AS stage,
         (COUNT(*))::int AS total,
         (COUNT(*) FILTER (WHERE p.founder_priority = 'critical'))::int AS critical_count,
         (COUNT(*) FILTER (WHERE p.founder_priority = 'high'))::int AS high_count
  FROM public.founder_hire_pipeline_r1786 p
  GROUP BY p.current_stage
  ORDER BY p.current_stage;
END;
$$;

-- RPC 7: top_priority_roles
DROP FUNCTION IF EXISTS public.top_priority_roles_r1786();
CREATE OR REPLACE FUNCTION public.top_priority_roles_r1786()
RETURNS TABLE (
  id uuid,
  role_title text,
  role_type text,
  candidate_name text,
  current_stage text,
  founder_priority text,
  expected_close date,
  days_to_close int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.role_title, p.role_type, p.candidate_name, p.current_stage, p.founder_priority,
         p.expected_close,
         CASE WHEN p.expected_close IS NULL THEN NULL
              ELSE (p.expected_close - CURRENT_DATE)::int END AS days_to_close
  FROM public.founder_hire_pipeline_r1786 p
  WHERE p.founder_priority IN ('critical','high')
    AND p.current_stage NOT IN ('hired','declined')
  ORDER BY
    CASE p.founder_priority WHEN 'critical' THEN 1 ELSE 2 END,
    p.expected_close NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pipeline_r1786() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_candidate_r1786(text, text, text, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_notes_r1786(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_note_r1786(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.advance_stage_r1786(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stage_summary_r1786() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_priority_roles_r1786() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pipeline_r1786() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_candidate_r1786(text, text, text, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_notes_r1786(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_note_r1786(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage_r1786(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_summary_r1786() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_priority_roles_r1786() TO authenticated;

COMMIT;