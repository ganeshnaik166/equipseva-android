BEGIN;

-- =====================================================================
-- Round 1823: Hospital Equipment Procurement Cycle
-- Tracks multi-month hospital equipment procurement decisions,
-- our pitch status, and activities (demos, site visits, negotiations).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.hospital_procurement_cycles_r1823 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_category text NOT NULL,
  decision_committee text[] NOT NULL DEFAULT '{}',
  decision_deadline date,
  our_pitch_status text NOT NULL DEFAULT 'pre_intro'
    CHECK (our_pitch_status IN ('pre_intro','intro_made','under_consideration','shortlisted','won','lost')),
  our_quote_rupees bigint,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','won','lost','cancelled')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpc_r1823_hospital
  ON public.hospital_procurement_cycles_r1823(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hpc_r1823_status
  ON public.hospital_procurement_cycles_r1823(status);
CREATE INDEX IF NOT EXISTS idx_hpc_r1823_deadline
  ON public.hospital_procurement_cycles_r1823(decision_deadline);

CREATE TABLE IF NOT EXISTS public.hospital_procurement_activities_r1823 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.hospital_procurement_cycles_r1823(id) ON DELETE CASCADE,
  activity_type text NOT NULL
    CHECK (activity_type IN ('site_visit','demo','proposal','reference_call','negotiation')),
  activity_at timestamptz NOT NULL DEFAULT now(),
  our_team text[] NOT NULL DEFAULT '{}',
  outcome_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpa_r1823_cycle
  ON public.hospital_procurement_activities_r1823(cycle_id);
CREATE INDEX IF NOT EXISTS idx_hpa_r1823_at
  ON public.hospital_procurement_activities_r1823(activity_at DESC);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------

ALTER TABLE public.hospital_procurement_cycles_r1823 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_procurement_activities_r1823 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpc_r1823_founder_all ON public.hospital_procurement_cycles_r1823;
CREATE POLICY hpc_r1823_founder_all ON public.hospital_procurement_cycles_r1823
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hpa_r1823_founder_all ON public.hospital_procurement_activities_r1823;
CREATE POLICY hpa_r1823_founder_all ON public.hospital_procurement_activities_r1823
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------

-- 1) list_cycles
DROP FUNCTION IF EXISTS public.list_cycles_r1823();
CREATE OR REPLACE FUNCTION public.list_cycles_r1823()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_category text,
  decision_committee text[],
  decision_deadline date,
  our_pitch_status text,
  our_quote_rupees bigint,
  status text,
  decided_at timestamptz,
  activity_count bigint,
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
    c.hospital_user_id,
    p.email::text AS hospital_email,
    c.equipment_category,
    c.decision_committee,
    c.decision_deadline,
    c.our_pitch_status,
    c.our_quote_rupees,
    c.status,
    c.decided_at,
    (SELECT COUNT(*) FROM public.hospital_procurement_activities_r1823 a WHERE a.cycle_id = c.id) AS activity_count,
    c.created_at
  FROM public.hospital_procurement_cycles_r1823 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

-- 2) log_cycle (write)
DROP FUNCTION IF EXISTS public.log_cycle_r1823(uuid, text, text[], date, text, bigint);
CREATE OR REPLACE FUNCTION public.log_cycle_r1823(
  p_hospital_user_id uuid,
  p_equipment_category text,
  p_decision_committee text[],
  p_decision_deadline date,
  p_our_pitch_status text,
  p_our_quote_rupees bigint
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

  INSERT INTO public.hospital_procurement_cycles_r1823(
    hospital_user_id, equipment_category, decision_committee,
    decision_deadline, our_pitch_status, our_quote_rupees
  )
  VALUES (
    p_hospital_user_id, p_equipment_category, COALESCE(p_decision_committee, '{}'),
    p_decision_deadline, COALESCE(p_our_pitch_status, 'pre_intro'), p_our_quote_rupees
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_cycle_r1823',
    jsonb_build_object(
      'cycle_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'equipment_category', p_equipment_category,
      'our_pitch_status', p_our_pitch_status
    )
  );

  RETURN v_id;
END;
$$;

-- 3) list_activities
DROP FUNCTION IF EXISTS public.list_activities_r1823(uuid);
CREATE OR REPLACE FUNCTION public.list_activities_r1823(p_cycle_id uuid)
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  activity_type text,
  activity_at timestamptz,
  our_team text[],
  outcome_summary text,
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
    a.id, a.cycle_id, a.activity_type, a.activity_at,
    a.our_team, a.outcome_summary, a.created_at
  FROM public.hospital_procurement_activities_r1823 a
  WHERE p_cycle_id IS NULL OR a.cycle_id = p_cycle_id
  ORDER BY a.activity_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_activity (write)
DROP FUNCTION IF EXISTS public.log_activity_r1823(uuid, text, text[], text);
CREATE OR REPLACE FUNCTION public.log_activity_r1823(
  p_cycle_id uuid,
  p_activity_type text,
  p_our_team text[],
  p_outcome_summary text
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

  INSERT INTO public.hospital_procurement_activities_r1823(
    cycle_id, activity_type, our_team, outcome_summary
  )
  VALUES (
    p_cycle_id, p_activity_type, COALESCE(p_our_team, '{}'), p_outcome_summary
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_activity_r1823',
    jsonb_build_object(
      'activity_id', v_id,
      'cycle_id', p_cycle_id,
      'activity_type', p_activity_type
    )
  );

  RETURN v_id;
END;
$$;

-- 5) mark_decision (write)
DROP FUNCTION IF EXISTS public.mark_decision_r1823(uuid, text, text);
CREATE OR REPLACE FUNCTION public.mark_decision_r1823(
  p_cycle_id uuid,
  p_status text,
  p_our_pitch_status text
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

  IF p_status NOT IN ('open','won','lost','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.hospital_procurement_cycles_r1823
  SET
    status = p_status,
    our_pitch_status = COALESCE(p_our_pitch_status, our_pitch_status),
    decided_at = CASE WHEN p_status IN ('won','lost','cancelled') THEN now() ELSE decided_at END,
    updated_at = now()
  WHERE id = p_cycle_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_decision_r1823',
    jsonb_build_object(
      'cycle_id', p_cycle_id,
      'status', p_status,
      'our_pitch_status', p_our_pitch_status
    )
  );
END;
$$;

-- 6) win_rate_by_category
DROP FUNCTION IF EXISTS public.win_rate_by_category_r1823();
CREATE OR REPLACE FUNCTION public.win_rate_by_category_r1823()
RETURNS TABLE (
  equipment_category text,
  total_cycles int,
  won_cycles int,
  lost_cycles int,
  open_cycles int,
  win_rate_pct numeric
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
    c.equipment_category,
    COUNT(*)::int AS total_cycles,
    (COUNT(*) FILTER (WHERE c.status = 'won'))::int AS won_cycles,
    (COUNT(*) FILTER (WHERE c.status = 'lost'))::int AS lost_cycles,
    (COUNT(*) FILTER (WHERE c.status = 'open'))::int AS open_cycles,
    CASE
      WHEN (COUNT(*) FILTER (WHERE c.status IN ('won','lost'))) = 0 THEN 0
      ELSE ROUND(
        (COUNT(*) FILTER (WHERE c.status = 'won'))::numeric * 100.0
        / NULLIF((COUNT(*) FILTER (WHERE c.status IN ('won','lost')))::numeric, 0),
        1
      )
    END AS win_rate_pct
  FROM public.hospital_procurement_cycles_r1823 c
  GROUP BY c.equipment_category
  ORDER BY total_cycles DESC;
END;
$$;

-- 7) recent_decisions
DROP FUNCTION IF EXISTS public.recent_decisions_r1823();
CREATE OR REPLACE FUNCTION public.recent_decisions_r1823()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_category text,
  status text,
  our_pitch_status text,
  our_quote_rupees bigint,
  decided_at timestamptz
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
    c.hospital_user_id,
    p.email::text AS hospital_email,
    c.equipment_category,
    c.status,
    c.our_pitch_status,
    c.our_quote_rupees,
    c.decided_at
  FROM public.hospital_procurement_cycles_r1823 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.decided_at IS NOT NULL
  ORDER BY c.decided_at DESC
  LIMIT 50;
END;
$$;

-- ---------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_cycles_r1823()              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cycle_r1823(uuid, text, text[], date, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_activities_r1823(uuid)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_activity_r1823(uuid, text, text[], text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_decision_r1823(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.win_rate_by_category_r1823()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_decisions_r1823()         FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cycles_r1823()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cycle_r1823(uuid, text, text[], date, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_activities_r1823(uuid)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_activity_r1823(uuid, text, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_decision_r1823(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.win_rate_by_category_r1823()     TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_decisions_r1823()         TO authenticated;

COMMIT;