BEGIN;

-- =====================================================================
-- Round 1767: Hospital Renewal Win-Back Tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_renewal_winbacks_r1767 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  churned_at timestamptz NOT NULL DEFAULT now(),
  churn_reason text NOT NULL CHECK (churn_reason IN ('price','service_quality','competitor','closed','internal_team')),
  target_winback_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (target_winback_amount_rupees >= 0),
  status text NOT NULL DEFAULT 'in_outreach' CHECK (status IN ('in_outreach','in_negotiation','won_back','lost_permanently')),
  won_back_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrw_r1767_hospital ON public.hospital_renewal_winbacks_r1767(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hrw_r1767_status ON public.hospital_renewal_winbacks_r1767(status);
CREATE INDEX IF NOT EXISTS idx_hrw_r1767_churned ON public.hospital_renewal_winbacks_r1767(churned_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_winback_attempts_r1767 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  winback_id uuid NOT NULL REFERENCES public.hospital_renewal_winbacks_r1767(id) ON DELETE CASCADE,
  attempt_type text NOT NULL CHECK (attempt_type IN ('call','visit','discount_offer','founder_call','customer_event')),
  attempted_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hwa_r1767_winback ON public.hospital_winback_attempts_r1767(winback_id);
CREATE INDEX IF NOT EXISTS idx_hwa_r1767_attempted ON public.hospital_winback_attempts_r1767(attempted_at DESC);

ALTER TABLE public.hospital_renewal_winbacks_r1767 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_winback_attempts_r1767 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hrw_r1767_founder_all ON public.hospital_renewal_winbacks_r1767;
CREATE POLICY hrw_r1767_founder_all ON public.hospital_renewal_winbacks_r1767
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hwa_r1767_founder_all ON public.hospital_winback_attempts_r1767;
CREATE POLICY hwa_r1767_founder_all ON public.hospital_winback_attempts_r1767
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_winbacks
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_winbacks_r1767()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  hospital_org text,
  churned_at timestamptz,
  churn_reason text,
  target_winback_amount_rupees bigint,
  status text,
  won_back_at timestamptz,
  attempt_count int,
  last_attempt_at timestamptz
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
    w.id,
    w.hospital_user_id,
    p.email::text AS hospital_email,
    o.name::text AS hospital_org,
    w.churned_at,
    w.churn_reason,
    w.target_winback_amount_rupees,
    w.status,
    w.won_back_at,
    (SELECT COUNT(*) FROM public.hospital_winback_attempts_r1767 a WHERE a.winback_id = w.id)::int AS attempt_count,
    (SELECT MAX(a.attempted_at) FROM public.hospital_winback_attempts_r1767 a WHERE a.winback_id = w.id) AS last_attempt_at
  FROM public.hospital_renewal_winbacks_r1767 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY w.churned_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_winbacks_r1767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_winbacks_r1767() TO authenticated;

-- =====================================================================
-- RPC 2: log_winback
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_winback_r1767(
  p_hospital_user_id uuid,
  p_churn_reason text,
  p_target_amount_rupees bigint,
  p_notes text DEFAULT NULL
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

  INSERT INTO public.hospital_renewal_winbacks_r1767(hospital_user_id, churn_reason, target_winback_amount_rupees, notes)
  VALUES (p_hospital_user_id, p_churn_reason, COALESCE(p_target_amount_rupees, 0), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_winback_r1767',
    jsonb_build_object('winback_id', v_id, 'hospital_user_id', p_hospital_user_id, 'churn_reason', p_churn_reason, 'target_amount_rupees', p_target_amount_rupees));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_winback_r1767(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_winback_r1767(uuid, text, bigint, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_attempts
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_attempts_r1767(p_winback_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  winback_id uuid,
  hospital_email text,
  attempt_type text,
  attempted_at timestamptz,
  by_email text,
  response text
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
    a.id,
    a.winback_id,
    p.email::text AS hospital_email,
    a.attempt_type,
    a.attempted_at,
    a.by_email,
    a.response
  FROM public.hospital_winback_attempts_r1767 a
  JOIN public.hospital_renewal_winbacks_r1767 w ON w.id = a.winback_id
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  WHERE (p_winback_id IS NULL OR a.winback_id = p_winback_id)
  ORDER BY a.attempted_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_attempts_r1767(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attempts_r1767(uuid) TO authenticated;

-- =====================================================================
-- RPC 4: log_attempt
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_attempt_r1767(
  p_winback_id uuid,
  p_attempt_type text,
  p_response text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := COALESCE(auth.jwt()->>'email', 'unknown');

  INSERT INTO public.hospital_winback_attempts_r1767(winback_id, attempt_type, by_email, response)
  VALUES (p_winback_id, p_attempt_type, v_email, p_response)
  RETURNING id INTO v_id;

  -- Auto-advance to in_negotiation if currently in_outreach
  UPDATE public.hospital_renewal_winbacks_r1767
  SET status = 'in_negotiation', updated_at = now()
  WHERE id = p_winback_id AND status = 'in_outreach';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_attempt_r1767',
    jsonb_build_object('attempt_id', v_id, 'winback_id', p_winback_id, 'attempt_type', p_attempt_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_attempt_r1767(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_attempt_r1767(uuid, text, text) TO authenticated;

-- =====================================================================
-- RPC 5: mark_won_back
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_won_back_r1767(
  p_winback_id uuid,
  p_outcome text DEFAULT 'won_back'
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

  IF p_outcome NOT IN ('won_back','lost_permanently') THEN
    RAISE EXCEPTION 'invalid outcome';
  END IF;

  UPDATE public.hospital_renewal_winbacks_r1767
  SET status = p_outcome,
      won_back_at = CASE WHEN p_outcome = 'won_back' THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_winback_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_won_back_r1767',
    jsonb_build_object('winback_id', p_winback_id, 'outcome', p_outcome));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_won_back_r1767(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_won_back_r1767(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: top_winback_targets
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_winback_targets_r1767()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  hospital_org text,
  churned_at timestamptz,
  churn_reason text,
  target_winback_amount_rupees bigint,
  status text,
  days_since_churn int,
  attempt_count int
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
    w.id,
    w.hospital_user_id,
    p.email::text AS hospital_email,
    o.name::text AS hospital_org,
    w.churned_at,
    w.churn_reason,
    w.target_winback_amount_rupees,
    w.status,
    GREATEST(0, EXTRACT(DAY FROM (now() - w.churned_at))::int) AS days_since_churn,
    (SELECT COUNT(*) FROM public.hospital_winback_attempts_r1767 a WHERE a.winback_id = w.id)::int AS attempt_count
  FROM public.hospital_renewal_winbacks_r1767 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE w.status IN ('in_outreach','in_negotiation')
  ORDER BY w.target_winback_amount_rupees DESC, w.churned_at ASC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_winback_targets_r1767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_winback_targets_r1767() TO authenticated;

-- =====================================================================
-- RPC 7: winback_funnel_summary
-- =====================================================================
CREATE OR REPLACE FUNCTION public.winback_funnel_summary_r1767()
RETURNS TABLE (
  total_churned int,
  in_outreach int,
  in_negotiation int,
  won_back int,
  lost_permanently int,
  total_target_amount_rupees bigint,
  won_back_amount_rupees bigint,
  total_attempts int,
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
    (COUNT(*))::int AS total_churned,
    (COUNT(*) FILTER (WHERE w.status = 'in_outreach'))::int AS in_outreach,
    (COUNT(*) FILTER (WHERE w.status = 'in_negotiation'))::int AS in_negotiation,
    (COUNT(*) FILTER (WHERE w.status = 'won_back'))::int AS won_back,
    (COUNT(*) FILTER (WHERE w.status = 'lost_permanently'))::int AS lost_permanently,
    COALESCE(SUM(w.target_winback_amount_rupees), 0)::bigint AS total_target_amount_rupees,
    COALESCE(SUM(w.target_winback_amount_rupees) FILTER (WHERE w.status = 'won_back'), 0)::bigint AS won_back_amount_rupees,
    (SELECT COUNT(*) FROM public.hospital_winback_attempts_r1767)::int AS total_attempts,
    CASE
      WHEN COUNT(*) FILTER (WHERE w.status IN ('won_back','lost_permanently')) = 0 THEN 0::numeric
      ELSE ROUND(
        (COUNT(*) FILTER (WHERE w.status = 'won_back'))::numeric * 100.0
        / NULLIF((COUNT(*) FILTER (WHERE w.status IN ('won_back','lost_permanently'))), 0),
        2
      )
    END AS win_rate_pct
  FROM public.hospital_renewal_winbacks_r1767 w;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.winback_funnel_summary_r1767() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.winback_funnel_summary_r1767() TO authenticated;

COMMIT;