BEGIN;

-- ============================================================
-- Round 1764 — Engineer Customer Conflict Log
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_customer_conflicts_r1764 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  severity text NOT NULL CHECK (severity IN ('minor','moderate','serious','escalated')),
  conflict_summary text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_mediation','resolved','escalated_to_legal')),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecc_r1764_engineer ON public.engineer_customer_conflicts_r1764(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecc_r1764_hospital ON public.engineer_customer_conflicts_r1764(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_ecc_r1764_status ON public.engineer_customer_conflicts_r1764(status);
CREATE INDEX IF NOT EXISTS idx_ecc_r1764_severity ON public.engineer_customer_conflicts_r1764(severity);
CREATE INDEX IF NOT EXISTS idx_ecc_r1764_occurred ON public.engineer_customer_conflicts_r1764(occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_conflict_resolution_steps_r1764 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conflict_id uuid NOT NULL REFERENCES public.engineer_customer_conflicts_r1764(id) ON DELETE CASCADE,
  step_type text NOT NULL CHECK (step_type IN ('apology','refund','reassign','training','legal_review','founder_call')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecrs_r1764_conflict ON public.engineer_conflict_resolution_steps_r1764(conflict_id);
CREATE INDEX IF NOT EXISTS idx_ecrs_r1764_step_type ON public.engineer_conflict_resolution_steps_r1764(step_type);
CREATE INDEX IF NOT EXISTS idx_ecrs_r1764_taken ON public.engineer_conflict_resolution_steps_r1764(taken_at DESC);

ALTER TABLE public.engineer_customer_conflicts_r1764 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_conflict_resolution_steps_r1764 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecc_r1764 ON public.engineer_customer_conflicts_r1764;
CREATE POLICY founder_all_ecc_r1764 ON public.engineer_customer_conflicts_r1764
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ecrs_r1764 ON public.engineer_conflict_resolution_steps_r1764;
CREATE POLICY founder_all_ecrs_r1764 ON public.engineer_conflict_resolution_steps_r1764
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_conflicts_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.list_conflicts_r1764();
CREATE OR REPLACE FUNCTION public.list_conflicts_r1764()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_user_id uuid,
  hospital_email text,
  occurred_at timestamptz,
  severity text,
  conflict_summary text,
  status text,
  resolved_at timestamptz,
  step_count int,
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
    c.id,
    c.engineer_user_id,
    ep.email::text AS engineer_email,
    c.hospital_user_id,
    hp.email::text AS hospital_email,
    c.occurred_at,
    c.severity,
    c.conflict_summary,
    c.status,
    c.resolved_at,
    (SELECT COUNT(*) FROM public.engineer_conflict_resolution_steps_r1764 s WHERE s.conflict_id = c.id)::int AS step_count,
    c.created_at
  FROM public.engineer_customer_conflicts_r1764 c
  LEFT JOIN public.profiles ep ON ep.id = c.engineer_user_id
  LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
  ORDER BY c.occurred_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 2: log_conflict_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.log_conflict_r1764(uuid, uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_conflict_r1764(
  p_engineer_user_id uuid,
  p_hospital_user_id uuid,
  p_severity text,
  p_conflict_summary text
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
  INSERT INTO public.engineer_customer_conflicts_r1764(
    engineer_user_id, hospital_user_id, severity, conflict_summary
  ) VALUES (p_engineer_user_id, p_hospital_user_id, p_severity, p_conflict_summary)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_conflict_r1764',
    jsonb_build_object(
      'conflict_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'hospital_user_id', p_hospital_user_id,
      'severity', p_severity
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_resolution_steps_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.list_resolution_steps_r1764(uuid);
CREATE OR REPLACE FUNCTION public.list_resolution_steps_r1764(p_conflict_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  conflict_id uuid,
  step_type text,
  taken_at timestamptz,
  by_email text,
  outcome text,
  conflict_severity text,
  conflict_status text
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
    s.id,
    s.conflict_id,
    s.step_type,
    s.taken_at,
    s.by_email,
    s.outcome,
    c.severity AS conflict_severity,
    c.status AS conflict_status
  FROM public.engineer_conflict_resolution_steps_r1764 s
  JOIN public.engineer_customer_conflicts_r1764 c ON c.id = s.conflict_id
  WHERE p_conflict_id IS NULL OR s.conflict_id = p_conflict_id
  ORDER BY s.taken_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 4: log_step_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.log_step_r1764(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_step_r1764(
  p_conflict_id uuid,
  p_step_type text,
  p_by_email text,
  p_outcome text
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
  INSERT INTO public.engineer_conflict_resolution_steps_r1764(
    conflict_id, step_type, by_email, outcome
  ) VALUES (p_conflict_id, p_step_type, p_by_email, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.engineer_customer_conflicts_r1764
  SET updated_at = now(),
      status = CASE WHEN status = 'open' THEN 'in_mediation' ELSE status END
  WHERE id = p_conflict_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_step_r1764',
    jsonb_build_object(
      'step_id', v_id,
      'conflict_id', p_conflict_id,
      'step_type', p_step_type,
      'by_email', p_by_email
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: close_conflict_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.close_conflict_r1764(uuid, text);
CREATE OR REPLACE FUNCTION public.close_conflict_r1764(
  p_conflict_id uuid,
  p_final_status text DEFAULT 'resolved'
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
  IF p_final_status NOT IN ('resolved','escalated_to_legal') THEN
    RAISE EXCEPTION 'invalid final status: %', p_final_status;
  END IF;

  UPDATE public.engineer_customer_conflicts_r1764
  SET status = p_final_status,
      resolved_at = now(),
      updated_at = now()
  WHERE id = p_conflict_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'close_conflict_r1764',
    jsonb_build_object(
      'conflict_id', p_conflict_id,
      'final_status', p_final_status
    )
  );
END;
$$;

-- ============================================================
-- RPC 6: severity_distribution_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.severity_distribution_r1764();
CREATE OR REPLACE FUNCTION public.severity_distribution_r1764()
RETURNS TABLE (
  severity text,
  total_count int,
  open_count int,
  in_mediation_count int,
  resolved_count int,
  escalated_legal_count int,
  avg_resolution_hours numeric
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
    c.severity,
    (COUNT(*))::int AS total_count,
    (COUNT(*) FILTER (WHERE c.status = 'open'))::int AS open_count,
    (COUNT(*) FILTER (WHERE c.status = 'in_mediation'))::int AS in_mediation_count,
    (COUNT(*) FILTER (WHERE c.status = 'resolved'))::int AS resolved_count,
    (COUNT(*) FILTER (WHERE c.status = 'escalated_to_legal'))::int AS escalated_legal_count,
    ROUND(AVG(EXTRACT(EPOCH FROM (c.resolved_at - c.occurred_at)) / 3600.0) FILTER (WHERE c.resolved_at IS NOT NULL)::numeric, 2) AS avg_resolution_hours
  FROM public.engineer_customer_conflicts_r1764 c
  GROUP BY c.severity
  ORDER BY
    CASE c.severity
      WHEN 'escalated' THEN 1
      WHEN 'serious' THEN 2
      WHEN 'moderate' THEN 3
      WHEN 'minor' THEN 4
      ELSE 5
    END;
END;
$$;

-- ============================================================
-- RPC 7: open_conflicts_summary_r1764
-- ============================================================
DROP FUNCTION IF EXISTS public.open_conflicts_summary_r1764();
CREATE OR REPLACE FUNCTION public.open_conflicts_summary_r1764()
RETURNS TABLE (
  total_open int,
  total_in_mediation int,
  total_resolved int,
  total_escalated_legal int,
  oldest_open_hours numeric,
  serious_or_escalated_open int,
  conflicts_last_7d int,
  resolved_last_7d int
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
    (COUNT(*) FILTER (WHERE c.status = 'open'))::int AS total_open,
    (COUNT(*) FILTER (WHERE c.status = 'in_mediation'))::int AS total_in_mediation,
    (COUNT(*) FILTER (WHERE c.status = 'resolved'))::int AS total_resolved,
    (COUNT(*) FILTER (WHERE c.status = 'escalated_to_legal'))::int AS total_escalated_legal,
    ROUND(EXTRACT(EPOCH FROM (now() - MIN(c.occurred_at) FILTER (WHERE c.status IN ('open','in_mediation')))) / 3600.0, 2) AS oldest_open_hours,
    (COUNT(*) FILTER (WHERE c.status IN ('open','in_mediation') AND c.severity IN ('serious','escalated')))::int AS serious_or_escalated_open,
    (COUNT(*) FILTER (WHERE c.occurred_at >= now() - interval '7 days'))::int AS conflicts_last_7d,
    (COUNT(*) FILTER (WHERE c.resolved_at >= now() - interval '7 days'))::int AS resolved_last_7d
  FROM public.engineer_customer_conflicts_r1764 c;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_conflicts_r1764() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_conflict_r1764(uuid, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_resolution_steps_r1764(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_step_r1764(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_conflict_r1764(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.severity_distribution_r1764() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_conflicts_summary_r1764() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_conflicts_r1764() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_conflict_r1764(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_resolution_steps_r1764(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_step_r1764(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_conflict_r1764(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.severity_distribution_r1764() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_conflicts_summary_r1764() TO authenticated;

COMMIT;