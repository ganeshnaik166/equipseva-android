BEGIN;

-- ============================================================
-- Round 1748 — Engineer Job Decline Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_job_declines_r1748 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid,
  declined_at timestamptz NOT NULL DEFAULT now(),
  decline_reason text NOT NULL CHECK (decline_reason IN (
    'too_far','already_busy','equipment_unfamiliar','personal_emergency','dispute_with_hospital','other'
  )),
  would_take_if text,
  follow_up_required boolean NOT NULL DEFAULT false,
  escalated_to_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ejd_r1748_engineer ON public.engineer_job_declines_r1748(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ejd_r1748_declined_at ON public.engineer_job_declines_r1748(declined_at DESC);
CREATE INDEX IF NOT EXISTS idx_ejd_r1748_reason ON public.engineer_job_declines_r1748(decline_reason);

CREATE TABLE IF NOT EXISTS public.engineer_decline_patterns_r1748 (
  engineer_user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_declines int NOT NULL DEFAULT 0,
  decline_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  most_common_reason text,
  last_decline_at timestamptz,
  recomputed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edp_r1748_total ON public.engineer_decline_patterns_r1748(total_declines DESC);

ALTER TABLE public.engineer_job_declines_r1748 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_decline_patterns_r1748 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ejd_r1748_founder ON public.engineer_job_declines_r1748;
CREATE POLICY p_ejd_r1748_founder ON public.engineer_job_declines_r1748
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_edp_r1748_founder ON public.engineer_decline_patterns_r1748;
CREATE POLICY p_edp_r1748_founder ON public.engineer_decline_patterns_r1748
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_declines_r1748(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  repair_job_id uuid,
  declined_at timestamptz,
  decline_reason text,
  would_take_if text,
  follow_up_required boolean,
  escalated_to_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, p.email, d.repair_job_id, d.declined_at,
         d.decline_reason, d.would_take_if, d.follow_up_required, d.escalated_to_email
  FROM public.engineer_job_declines_r1748 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  ORDER BY d.declined_at DESC
  LIMIT p_limit;
END$$;

CREATE OR REPLACE FUNCTION public.log_decline_r1748(
  p_engineer uuid,
  p_repair_job uuid,
  p_reason text,
  p_would_take_if text,
  p_follow_up boolean,
  p_escalated_to text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_job_declines_r1748(
    engineer_user_id, repair_job_id, decline_reason, would_take_if, follow_up_required, escalated_to_email
  ) VALUES (p_engineer, p_repair_job, p_reason, p_would_take_if, COALESCE(p_follow_up,false), p_escalated_to)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decline_r1748',
          jsonb_build_object('decline_id', v_id, 'engineer', p_engineer, 'reason', p_reason));
  RETURN v_id;
END$$;

CREATE OR REPLACE FUNCTION public.list_patterns_r1748(p_limit int DEFAULT 100)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  total_declines int,
  decline_rate_pct numeric,
  most_common_reason text,
  last_decline_at timestamptz,
  recomputed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pt.engineer_user_id, p.email, pt.total_declines, pt.decline_rate_pct,
         pt.most_common_reason, pt.last_decline_at, pt.recomputed_at
  FROM public.engineer_decline_patterns_r1748 pt
  LEFT JOIN public.profiles p ON p.id = pt.engineer_user_id
  ORDER BY pt.total_declines DESC
  LIMIT p_limit;
END$$;

CREATE OR REPLACE FUNCTION public.recompute_patterns_r1748()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_count int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH agg AS (
    SELECT engineer_user_id,
           COUNT(*)::int AS total,
           MAX(declined_at) AS last_at,
           MODE() WITHIN GROUP (ORDER BY decline_reason) AS top_reason
    FROM public.engineer_job_declines_r1748
    GROUP BY engineer_user_id
  )
  INSERT INTO public.engineer_decline_patterns_r1748(
    engineer_user_id, total_declines, decline_rate_pct, most_common_reason, last_decline_at, recomputed_at
  )
  SELECT engineer_user_id, total, 0, top_reason, last_at, now()
  FROM agg
  ON CONFLICT (engineer_user_id) DO UPDATE
    SET total_declines = EXCLUDED.total_declines,
        most_common_reason = EXCLUDED.most_common_reason,
        last_decline_at = EXCLUDED.last_decline_at,
        recomputed_at = now(),
        updated_at = now();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'recompute_patterns_r1748',
          jsonb_build_object('rows', v_count));
  RETURN v_count;
END$$;

CREATE OR REPLACE FUNCTION public.top_decliners_r1748(p_limit int DEFAULT 20)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  total_declines int,
  most_common_reason text,
  last_decline_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pt.engineer_user_id, p.email, pt.total_declines, pt.most_common_reason, pt.last_decline_at
  FROM public.engineer_decline_patterns_r1748 pt
  LEFT JOIN public.profiles p ON p.id = pt.engineer_user_id
  ORDER BY pt.total_declines DESC
  LIMIT p_limit;
END$$;

CREATE OR REPLACE FUNCTION public.decline_reason_distribution_r1748()
RETURNS TABLE(decline_reason text, total int, pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_grand int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::int INTO v_grand FROM public.engineer_job_declines_r1748;
  IF v_grand = 0 THEN v_grand := 1; END IF;
  RETURN QUERY
  SELECT d.decline_reason,
         COUNT(*)::int AS total,
         ROUND((COUNT(*)::numeric / v_grand) * 100.0, 2) AS pct
  FROM public.engineer_job_declines_r1748 d
  GROUP BY d.decline_reason
  ORDER BY total DESC;
END$$;

CREATE OR REPLACE FUNCTION public.recent_escalations_r1748(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  decline_reason text,
  declined_at timestamptz,
  escalated_to_email text,
  would_take_if text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, p.email, d.decline_reason, d.declined_at,
         d.escalated_to_email, d.would_take_if
  FROM public.engineer_job_declines_r1748 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  WHERE d.follow_up_required = true OR d.escalated_to_email IS NOT NULL
  ORDER BY d.declined_at DESC
  LIMIT p_limit;
END$$;

REVOKE EXECUTE ON FUNCTION public.list_declines_r1748(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decline_r1748(uuid,uuid,text,text,boolean,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_patterns_r1748(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recompute_patterns_r1748() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_decliners_r1748(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decline_reason_distribution_r1748() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_escalations_r1748(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_declines_r1748(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decline_r1748(uuid,uuid,text,text,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_patterns_r1748(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_patterns_r1748() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_decliners_r1748(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decline_reason_distribution_r1748() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_escalations_r1748(int) TO authenticated;

COMMIT;