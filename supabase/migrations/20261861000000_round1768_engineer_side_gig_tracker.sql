BEGIN;

-- ============================================================
-- Round 1768 — Engineer Side-Gig Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_side_gig_disclosures_r1768 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  side_activity_name text NOT NULL,
  side_activity_type text NOT NULL CHECK (side_activity_type IN ('competitor','non_competitor','freelance','teaching','research','family_biz')),
  hours_per_week numeric(5,2) NOT NULL DEFAULT 0,
  disclosed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'disclosed' CHECK (status IN ('disclosed','approved','blocked','withdrawn')),
  founder_decision text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esgd_r1768_engineer ON public.engineer_side_gig_disclosures_r1768(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_esgd_r1768_status ON public.engineer_side_gig_disclosures_r1768(status);
CREATE INDEX IF NOT EXISTS idx_esgd_r1768_type ON public.engineer_side_gig_disclosures_r1768(side_activity_type);
CREATE INDEX IF NOT EXISTS idx_esgd_r1768_disclosed ON public.engineer_side_gig_disclosures_r1768(disclosed_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_side_gig_compliance_checks_r1768 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  disclosure_id uuid NOT NULL REFERENCES public.engineer_side_gig_disclosures_r1768(id) ON DELETE CASCADE,
  check_type text NOT NULL CHECK (check_type IN ('schedule_conflict','customer_overlap','equipment_use','code_overlap')),
  checked_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  finding text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esgcc_r1768_disclosure ON public.engineer_side_gig_compliance_checks_r1768(disclosure_id);
CREATE INDEX IF NOT EXISTS idx_esgcc_r1768_type ON public.engineer_side_gig_compliance_checks_r1768(check_type);
CREATE INDEX IF NOT EXISTS idx_esgcc_r1768_checked ON public.engineer_side_gig_compliance_checks_r1768(checked_at DESC);

ALTER TABLE public.engineer_side_gig_disclosures_r1768 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_side_gig_compliance_checks_r1768 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_esgd_r1768 ON public.engineer_side_gig_disclosures_r1768;
CREATE POLICY founder_all_esgd_r1768 ON public.engineer_side_gig_disclosures_r1768
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_esgcc_r1768 ON public.engineer_side_gig_compliance_checks_r1768;
CREATE POLICY founder_all_esgcc_r1768 ON public.engineer_side_gig_compliance_checks_r1768
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_disclosures_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.list_disclosures_r1768();
CREATE OR REPLACE FUNCTION public.list_disclosures_r1768()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  side_activity_name text,
  side_activity_type text,
  hours_per_week numeric,
  disclosed_at timestamptz,
  status text,
  founder_decision text,
  check_count int,
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
    d.engineer_user_id,
    ep.email::text AS engineer_email,
    d.side_activity_name,
    d.side_activity_type,
    d.hours_per_week,
    d.disclosed_at,
    d.status,
    d.founder_decision,
    (SELECT COUNT(*) FROM public.engineer_side_gig_compliance_checks_r1768 c WHERE c.disclosure_id = d.id)::int AS check_count,
    d.created_at
  FROM public.engineer_side_gig_disclosures_r1768 d
  LEFT JOIN public.profiles ep ON ep.id = d.engineer_user_id
  ORDER BY d.disclosed_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 2: log_disclosure_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.log_disclosure_r1768(uuid, text, text, numeric);
CREATE OR REPLACE FUNCTION public.log_disclosure_r1768(
  p_engineer_user_id uuid,
  p_side_activity_name text,
  p_side_activity_type text,
  p_hours_per_week numeric
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
  INSERT INTO public.engineer_side_gig_disclosures_r1768(
    engineer_user_id, side_activity_name, side_activity_type, hours_per_week
  ) VALUES (p_engineer_user_id, p_side_activity_name, p_side_activity_type, p_hours_per_week)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_disclosure_r1768',
    jsonb_build_object(
      'disclosure_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'side_activity_type', p_side_activity_type,
      'hours_per_week', p_hours_per_week
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_checks_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.list_checks_r1768(uuid);
CREATE OR REPLACE FUNCTION public.list_checks_r1768(p_disclosure_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  disclosure_id uuid,
  check_type text,
  checked_at timestamptz,
  by_email text,
  finding text,
  disclosure_status text,
  disclosure_activity_type text
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
    c.disclosure_id,
    c.check_type,
    c.checked_at,
    c.by_email,
    c.finding,
    d.status AS disclosure_status,
    d.side_activity_type AS disclosure_activity_type
  FROM public.engineer_side_gig_compliance_checks_r1768 c
  JOIN public.engineer_side_gig_disclosures_r1768 d ON d.id = c.disclosure_id
  WHERE p_disclosure_id IS NULL OR c.disclosure_id = p_disclosure_id
  ORDER BY c.checked_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================
-- RPC 4: log_check_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.log_check_r1768(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_check_r1768(
  p_disclosure_id uuid,
  p_check_type text,
  p_by_email text,
  p_finding text
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
  INSERT INTO public.engineer_side_gig_compliance_checks_r1768(
    disclosure_id, check_type, by_email, finding
  ) VALUES (p_disclosure_id, p_check_type, p_by_email, p_finding)
  RETURNING id INTO v_id;

  UPDATE public.engineer_side_gig_disclosures_r1768
  SET updated_at = now()
  WHERE id = p_disclosure_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_check_r1768',
    jsonb_build_object(
      'check_id', v_id,
      'disclosure_id', p_disclosure_id,
      'check_type', p_check_type,
      'by_email', p_by_email
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: decide_disclosure_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.decide_disclosure_r1768(uuid, text, text);
CREATE OR REPLACE FUNCTION public.decide_disclosure_r1768(
  p_disclosure_id uuid,
  p_new_status text,
  p_founder_decision text
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
  IF p_new_status NOT IN ('approved','blocked','withdrawn') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;

  UPDATE public.engineer_side_gig_disclosures_r1768
  SET status = p_new_status,
      founder_decision = p_founder_decision,
      updated_at = now()
  WHERE id = p_disclosure_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'decide_disclosure_r1768',
    jsonb_build_object(
      'disclosure_id', p_disclosure_id,
      'new_status', p_new_status,
      'founder_decision', p_founder_decision
    )
  );
END;
$$;

-- ============================================================
-- RPC 6: active_disclosures_summary_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.active_disclosures_summary_r1768();
CREATE OR REPLACE FUNCTION public.active_disclosures_summary_r1768()
RETURNS TABLE (
  total_disclosed int,
  total_approved int,
  total_blocked int,
  total_withdrawn int,
  competitor_open int,
  high_hours_open int,
  avg_hours_per_week numeric,
  disclosures_last_30d int,
  approvals_last_30d int
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
    (COUNT(*) FILTER (WHERE d.status = 'disclosed'))::int AS total_disclosed,
    (COUNT(*) FILTER (WHERE d.status = 'approved'))::int AS total_approved,
    (COUNT(*) FILTER (WHERE d.status = 'blocked'))::int AS total_blocked,
    (COUNT(*) FILTER (WHERE d.status = 'withdrawn'))::int AS total_withdrawn,
    (COUNT(*) FILTER (WHERE d.status IN ('disclosed','approved') AND d.side_activity_type = 'competitor'))::int AS competitor_open,
    (COUNT(*) FILTER (WHERE d.status IN ('disclosed','approved') AND d.hours_per_week > 10))::int AS high_hours_open,
    ROUND(AVG(d.hours_per_week)::numeric, 2) AS avg_hours_per_week,
    (COUNT(*) FILTER (WHERE d.disclosed_at >= now() - interval '30 days'))::int AS disclosures_last_30d,
    (COUNT(*) FILTER (WHERE d.status = 'approved' AND d.updated_at >= now() - interval '30 days'))::int AS approvals_last_30d
  FROM public.engineer_side_gig_disclosures_r1768 d;
END;
$$;

-- ============================================================
-- RPC 7: conflict_risks_r1768
-- ============================================================
DROP FUNCTION IF EXISTS public.conflict_risks_r1768();
CREATE OR REPLACE FUNCTION public.conflict_risks_r1768()
RETURNS TABLE (
  side_activity_type text,
  total_count int,
  disclosed_count int,
  approved_count int,
  blocked_count int,
  withdrawn_count int,
  total_hours numeric,
  flagged_check_count int
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
    d.side_activity_type,
    (COUNT(*))::int AS total_count,
    (COUNT(*) FILTER (WHERE d.status = 'disclosed'))::int AS disclosed_count,
    (COUNT(*) FILTER (WHERE d.status = 'approved'))::int AS approved_count,
    (COUNT(*) FILTER (WHERE d.status = 'blocked'))::int AS blocked_count,
    (COUNT(*) FILTER (WHERE d.status = 'withdrawn'))::int AS withdrawn_count,
    ROUND(SUM(d.hours_per_week)::numeric, 2) AS total_hours,
    (SELECT COUNT(*) FROM public.engineer_side_gig_compliance_checks_r1768 c
       JOIN public.engineer_side_gig_disclosures_r1768 d2 ON d2.id = c.disclosure_id
       WHERE d2.side_activity_type = d.side_activity_type
       AND c.finding IS NOT NULL
       AND c.finding <> '')::int AS flagged_check_count
  FROM public.engineer_side_gig_disclosures_r1768 d
  GROUP BY d.side_activity_type
  ORDER BY
    CASE d.side_activity_type
      WHEN 'competitor' THEN 1
      WHEN 'freelance' THEN 2
      WHEN 'research' THEN 3
      WHEN 'teaching' THEN 4
      WHEN 'family_biz' THEN 5
      WHEN 'non_competitor' THEN 6
      ELSE 7
    END;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_disclosures_r1768() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_disclosure_r1768(uuid, text, text, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_checks_r1768(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_check_r1768(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_disclosure_r1768(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_disclosures_summary_r1768() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.conflict_risks_r1768() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_disclosures_r1768() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_disclosure_r1768(uuid, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_checks_r1768(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_check_r1768(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_disclosure_r1768(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_disclosures_summary_r1768() TO authenticated;
GRANT EXECUTE ON FUNCTION public.conflict_risks_r1768() TO authenticated;

COMMIT;