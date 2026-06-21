BEGIN;

-- =====================================================================
-- Round 1746 — Founder Acquihire Pipeline
-- Track potential team-acquihires + per-target due-diligence checklist.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_acquihire_pipeline_r1746 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_team_name text NOT NULL,
  founder_count int NOT NULL DEFAULT 0,
  employee_count int NOT NULL DEFAULT 0,
  current_runway_months int NOT NULL DEFAULT 0,
  asking_price_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'intro'
    CHECK (status IN ('intro','diligence','loi','negotiating','closed','passed')),
  expected_close_date date,
  founder_contact_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_acquihire_due_diligence_r1746 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.founder_acquihire_pipeline_r1746(id) ON DELETE CASCADE,
  diligence_area text NOT NULL
    CHECK (diligence_area IN ('culture','tech','finances','customers','legal','team')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','clean','concerns','blockers')),
  notes_md text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_acquihire_pipeline_r1746_status
  ON public.founder_acquihire_pipeline_r1746(status);
CREATE INDEX IF NOT EXISTS idx_acquihire_dd_r1746_target
  ON public.founder_acquihire_due_diligence_r1746(target_id);
CREATE INDEX IF NOT EXISTS idx_acquihire_dd_r1746_status
  ON public.founder_acquihire_due_diligence_r1746(status);

ALTER TABLE public.founder_acquihire_pipeline_r1746 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_acquihire_due_diligence_r1746 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_pipeline_r1746 ON public.founder_acquihire_pipeline_r1746;
CREATE POLICY founder_only_pipeline_r1746
  ON public.founder_acquihire_pipeline_r1746
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_dd_r1746 ON public.founder_acquihire_due_diligence_r1746;
CREATE POLICY founder_only_dd_r1746
  ON public.founder_acquihire_due_diligence_r1746
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_acquihire_pipeline_r1746 FROM PUBLIC, anon;
REVOKE ALL ON public.founder_acquihire_due_diligence_r1746 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.founder_acquihire_pipeline_r1746 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.founder_acquihire_due_diligence_r1746 TO authenticated;

-- =====================================================================
-- RPCs
-- =====================================================================

-- 1) list_targets
CREATE OR REPLACE FUNCTION public.list_targets_r1746()
RETURNS TABLE (
  id uuid,
  target_team_name text,
  founder_count int,
  employee_count int,
  current_runway_months int,
  asking_price_rupees bigint,
  status text,
  expected_close_date date,
  founder_contact_email text,
  diligence_total int,
  diligence_clean int,
  diligence_blockers int,
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
  SELECT
    t.id,
    t.target_team_name,
    t.founder_count,
    t.employee_count,
    t.current_runway_months,
    t.asking_price_rupees,
    t.status,
    t.expected_close_date,
    t.founder_contact_email,
    (COUNT(d.id))::int AS diligence_total,
    (COUNT(*) FILTER (WHERE d.status = 'clean'))::int AS diligence_clean,
    (COUNT(*) FILTER (WHERE d.status = 'blockers'))::int AS diligence_blockers,
    t.created_at
  FROM public.founder_acquihire_pipeline_r1746 t
  LEFT JOIN public.founder_acquihire_due_diligence_r1746 d ON d.target_id = t.id
  GROUP BY t.id
  ORDER BY t.created_at DESC;
END;
$$;

-- 2) add_target
CREATE OR REPLACE FUNCTION public.add_target_r1746(
  p_target_team_name text,
  p_founder_count int,
  p_employee_count int,
  p_current_runway_months int,
  p_asking_price_rupees bigint,
  p_expected_close_date date,
  p_founder_contact_email text,
  p_notes_md text
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

  INSERT INTO public.founder_acquihire_pipeline_r1746 (
    target_team_name, founder_count, employee_count, current_runway_months,
    asking_price_rupees, expected_close_date, founder_contact_email, notes_md
  ) VALUES (
    p_target_team_name, p_founder_count, p_employee_count, p_current_runway_months,
    p_asking_price_rupees, p_expected_close_date, p_founder_contact_email, p_notes_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_target_r1746',
    jsonb_build_object(
      'target_id', v_id,
      'target_team_name', p_target_team_name,
      'asking_price_rupees', p_asking_price_rupees
    )
  );

  RETURN v_id;
END;
$$;

-- 3) list_diligence
CREATE OR REPLACE FUNCTION public.list_diligence_r1746(p_target_id uuid)
RETURNS TABLE (
  id uuid,
  target_id uuid,
  target_team_name text,
  diligence_area text,
  status text,
  notes_md text,
  completed_at timestamptz,
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
  SELECT
    d.id,
    d.target_id,
    t.target_team_name,
    d.diligence_area,
    d.status,
    d.notes_md,
    d.completed_at,
    d.created_at
  FROM public.founder_acquihire_due_diligence_r1746 d
  JOIN public.founder_acquihire_pipeline_r1746 t ON t.id = d.target_id
  WHERE (p_target_id IS NULL OR d.target_id = p_target_id)
  ORDER BY d.created_at DESC;
END;
$$;

-- 4) update_diligence
CREATE OR REPLACE FUNCTION public.update_diligence_r1746(
  p_target_id uuid,
  p_diligence_area text,
  p_status text,
  p_notes_md text
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

  SELECT id INTO v_id
  FROM public.founder_acquihire_due_diligence_r1746
  WHERE target_id = p_target_id AND diligence_area = p_diligence_area
  LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.founder_acquihire_due_diligence_r1746 (
      target_id, diligence_area, status, notes_md,
      completed_at
    ) VALUES (
      p_target_id, p_diligence_area, p_status, p_notes_md,
      CASE WHEN p_status IN ('clean','concerns','blockers') THEN now() ELSE NULL END
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.founder_acquihire_due_diligence_r1746
    SET status = p_status,
        notes_md = COALESCE(p_notes_md, notes_md),
        completed_at = CASE WHEN p_status IN ('clean','concerns','blockers') THEN now() ELSE completed_at END,
        updated_at = now()
    WHERE id = v_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'update_diligence_r1746',
    jsonb_build_object(
      'target_id', p_target_id,
      'diligence_area', p_diligence_area,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

-- 5) close_target
CREATE OR REPLACE FUNCTION public.close_target_r1746(
  p_target_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_new_status NOT IN ('closed','passed') THEN
    RAISE EXCEPTION 'invalid close status: %', p_new_status;
  END IF;

  UPDATE public.founder_acquihire_pipeline_r1746
  SET status = p_new_status,
      updated_at = now()
  WHERE id = p_target_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'close_target_r1746',
    jsonb_build_object(
      'target_id', p_target_id,
      'new_status', p_new_status
    )
  );
END;
$$;

-- 6) pipeline_value_summary
CREATE OR REPLACE FUNCTION public.pipeline_value_summary_r1746()
RETURNS TABLE (
  status text,
  target_count int,
  total_asking_rupees bigint,
  total_founder_count int,
  total_employee_count int,
  avg_runway_months numeric
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
    t.status,
    (COUNT(*))::int AS target_count,
    COALESCE(SUM(t.asking_price_rupees), 0)::bigint AS total_asking_rupees,
    COALESCE(SUM(t.founder_count), 0)::int AS total_founder_count,
    COALESCE(SUM(t.employee_count), 0)::int AS total_employee_count,
    COALESCE(AVG(t.current_runway_months), 0)::numeric AS avg_runway_months
  FROM public.founder_acquihire_pipeline_r1746 t
  GROUP BY t.status
  ORDER BY t.status;
END;
$$;

-- 7) blocked_diligence
CREATE OR REPLACE FUNCTION public.blocked_diligence_r1746()
RETURNS TABLE (
  id uuid,
  target_id uuid,
  target_team_name text,
  diligence_area text,
  status text,
  notes_md text,
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
  SELECT
    d.id,
    d.target_id,
    t.target_team_name,
    d.diligence_area,
    d.status,
    d.notes_md,
    d.created_at
  FROM public.founder_acquihire_due_diligence_r1746 d
  JOIN public.founder_acquihire_pipeline_r1746 t ON t.id = d.target_id
  WHERE d.status IN ('blockers','concerns')
    AND t.status NOT IN ('closed','passed')
  ORDER BY
    CASE d.status WHEN 'blockers' THEN 0 ELSE 1 END,
    d.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_targets_r1746() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_target_r1746(text, int, int, int, bigint, date, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_diligence_r1746(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_diligence_r1746(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_target_r1746(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pipeline_value_summary_r1746() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.blocked_diligence_r1746() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_targets_r1746() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_target_r1746(text, int, int, int, bigint, date, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_diligence_r1746(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_diligence_r1746(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_target_r1746(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pipeline_value_summary_r1746() TO authenticated;
GRANT EXECUTE ON FUNCTION public.blocked_diligence_r1746() TO authenticated;

COMMIT;