BEGIN;

-- ============================================================================
-- Round 1851 — Hospital Account-Based Marketing
-- Per-hospital ABM campaign tracking + activity log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_abm_campaigns_r1851 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  campaign_name text NOT NULL,
  campaign_type text NOT NULL CHECK (campaign_type IN ('direct_mail','event_invite','conference_meet','co_branded_content','exec_dinner')),
  started_at timestamptz NOT NULL DEFAULT now(),
  expected_close_date date,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','won','lost','paused')),
  value_at_stake_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_abm_campaigns_r1851_hospital
  ON public.hospital_abm_campaigns_r1851(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_abm_campaigns_r1851_status
  ON public.hospital_abm_campaigns_r1851(status);
CREATE INDEX IF NOT EXISTS idx_abm_campaigns_r1851_started
  ON public.hospital_abm_campaigns_r1851(started_at DESC);

ALTER TABLE public.hospital_abm_campaigns_r1851 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS abm_campaigns_r1851_founder ON public.hospital_abm_campaigns_r1851;
CREATE POLICY abm_campaigns_r1851_founder
  ON public.hospital_abm_campaigns_r1851
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.hospital_abm_activities_r1851 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.hospital_abm_campaigns_r1851(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('email','call','visit','event','gift')),
  activity_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_abm_activities_r1851_campaign
  ON public.hospital_abm_activities_r1851(campaign_id);
CREATE INDEX IF NOT EXISTS idx_abm_activities_r1851_at
  ON public.hospital_abm_activities_r1851(activity_at DESC);

ALTER TABLE public.hospital_abm_activities_r1851 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS abm_activities_r1851_founder ON public.hospital_abm_activities_r1851;
CREATE POLICY abm_activities_r1851_founder
  ON public.hospital_abm_activities_r1851
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: list_campaigns
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_list_campaigns();
CREATE OR REPLACE FUNCTION public.r1851_list_campaigns()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  org_name text,
  campaign_name text,
  campaign_type text,
  started_at timestamptz,
  expected_close_date date,
  status text,
  value_at_stake_rupees bigint,
  activity_count int
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
    p.email,
    o.name,
    c.campaign_name,
    c.campaign_type,
    c.started_at,
    c.expected_close_date,
    c.status,
    c.value_at_stake_rupees,
    (SELECT COUNT(*)::int FROM public.hospital_abm_activities_r1851 a WHERE a.campaign_id = c.id)
  FROM public.hospital_abm_campaigns_r1851 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY c.started_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_list_campaigns() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_list_campaigns() TO authenticated;


-- ============================================================================
-- RPC 2: plan_campaign
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_plan_campaign(uuid, text, text, date, bigint);
CREATE OR REPLACE FUNCTION public.r1851_plan_campaign(
  p_hospital_user_id uuid,
  p_campaign_name text,
  p_campaign_type text,
  p_expected_close_date date,
  p_value_at_stake_rupees bigint
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

  INSERT INTO public.hospital_abm_campaigns_r1851(
    hospital_user_id, campaign_name, campaign_type, expected_close_date, value_at_stake_rupees
  ) VALUES (
    p_hospital_user_id, p_campaign_name, p_campaign_type, p_expected_close_date, COALESCE(p_value_at_stake_rupees, 0)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1851_plan_campaign',
    jsonb_build_object(
      'campaign_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'campaign_name', p_campaign_name,
      'campaign_type', p_campaign_type,
      'value_at_stake_rupees', p_value_at_stake_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_plan_campaign(uuid, text, text, date, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_plan_campaign(uuid, text, text, date, bigint) TO authenticated;


-- ============================================================================
-- RPC 3: list_activities
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_list_activities(uuid);
CREATE OR REPLACE FUNCTION public.r1851_list_activities(p_campaign_id uuid)
RETURNS TABLE (
  id uuid,
  campaign_id uuid,
  activity_type text,
  activity_at timestamptz,
  by_email text,
  outcome text
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
  SELECT a.id, a.campaign_id, a.activity_type, a.activity_at, a.by_email, a.outcome
  FROM public.hospital_abm_activities_r1851 a
  WHERE p_campaign_id IS NULL OR a.campaign_id = p_campaign_id
  ORDER BY a.activity_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_list_activities(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_list_activities(uuid) TO authenticated;


-- ============================================================================
-- RPC 4: log_activity
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_log_activity(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r1851_log_activity(
  p_campaign_id uuid,
  p_activity_type text,
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

  INSERT INTO public.hospital_abm_activities_r1851(
    campaign_id, activity_type, by_email, outcome
  ) VALUES (
    p_campaign_id, p_activity_type, p_by_email, p_outcome
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1851_log_activity',
    jsonb_build_object(
      'activity_id', v_id,
      'campaign_id', p_campaign_id,
      'activity_type', p_activity_type,
      'by_email', p_by_email
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_log_activity(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_log_activity(uuid, text, text, text) TO authenticated;


-- ============================================================================
-- RPC 5: mark_outcome
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_mark_outcome(uuid, text);
CREATE OR REPLACE FUNCTION public.r1851_mark_outcome(
  p_campaign_id uuid,
  p_status text
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

  IF p_status NOT IN ('planned','active','won','lost','paused') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.hospital_abm_campaigns_r1851
  SET status = p_status, updated_at = now()
  WHERE id = p_campaign_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1851_mark_outcome',
    jsonb_build_object('campaign_id', p_campaign_id, 'status', p_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_mark_outcome(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_mark_outcome(uuid, text) TO authenticated;


-- ============================================================================
-- RPC 6: active_campaigns_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_active_campaigns_summary();
CREATE OR REPLACE FUNCTION public.r1851_active_campaigns_summary()
RETURNS TABLE (
  total_active int,
  total_planned int,
  total_won int,
  total_lost int,
  total_paused int,
  pipeline_value_rupees bigint,
  won_value_rupees bigint
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
    (COUNT(*) FILTER (WHERE c.status = 'active'))::int,
    (COUNT(*) FILTER (WHERE c.status = 'planned'))::int,
    (COUNT(*) FILTER (WHERE c.status = 'won'))::int,
    (COUNT(*) FILTER (WHERE c.status = 'lost'))::int,
    (COUNT(*) FILTER (WHERE c.status = 'paused'))::int,
    COALESCE(SUM(c.value_at_stake_rupees) FILTER (WHERE c.status IN ('planned','active')), 0)::bigint,
    COALESCE(SUM(c.value_at_stake_rupees) FILTER (WHERE c.status = 'won'), 0)::bigint
  FROM public.hospital_abm_campaigns_r1851 c;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_active_campaigns_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_active_campaigns_summary() TO authenticated;


-- ============================================================================
-- RPC 7: recent_won
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1851_recent_won();
CREATE OR REPLACE FUNCTION public.r1851_recent_won()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  org_name text,
  campaign_name text,
  campaign_type text,
  value_at_stake_rupees bigint,
  updated_at timestamptz
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
    p.email,
    o.name,
    c.campaign_name,
    c.campaign_type,
    c.value_at_stake_rupees,
    c.updated_at
  FROM public.hospital_abm_campaigns_r1851 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE c.status = 'won'
  ORDER BY c.updated_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1851_recent_won() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1851_recent_won() TO authenticated;

COMMIT;