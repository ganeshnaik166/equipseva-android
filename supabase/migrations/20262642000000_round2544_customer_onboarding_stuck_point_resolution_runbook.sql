-- Round 2544: customer-onboarding-stuck-point-resolution-runbook
-- Hospital × onboarding stuck point × kind × resolution playbook × outcome.

CREATE TABLE IF NOT EXISTS public.customer_onboarding_stuck_points_r2544 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  stuck_at_stage text NOT NULL CHECK (stuck_at_stage IN ('kyc','contract','installation','training','first_pm','handover_signoff')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  stuck_days int NOT NULL DEFAULT 0,
  stuck_kind text NOT NULL CHECK (stuck_kind IN ('legal','training','integration','equipment','finance','communication','people')),
  resolution_playbook_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  resolved_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stuck_point_resolution_outcomes_r2544 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stuck_id uuid NOT NULL REFERENCES public.customer_onboarding_stuck_points_r2544(id) ON DELETE CASCADE,
  resolution_at timestamptz NOT NULL DEFAULT now(),
  resolution_kind text NOT NULL CHECK (resolution_kind IN ('playbook','escalation','founder_intervention','refund','discount')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  lessons_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cospsp_r2544_hospital ON public.customer_onboarding_stuck_points_r2544(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cospsp_r2544_status ON public.customer_onboarding_stuck_points_r2544(status);
CREATE INDEX IF NOT EXISTS idx_cospsp_r2544_stage ON public.customer_onboarding_stuck_points_r2544(stuck_at_stage);
CREATE INDEX IF NOT EXISTS idx_spro_r2544_stuck ON public.stuck_point_resolution_outcomes_r2544(stuck_id);
CREATE INDEX IF NOT EXISTS idx_spro_r2544_at ON public.stuck_point_resolution_outcomes_r2544(resolution_at);

ALTER TABLE public.customer_onboarding_stuck_points_r2544 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stuck_point_resolution_outcomes_r2544 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_stuck_points_r2544;
CREATE POLICY founder_all ON public.customer_onboarding_stuck_points_r2544
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.stuck_point_resolution_outcomes_r2544;
CREATE POLICY founder_all ON public.stuck_point_resolution_outcomes_r2544
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_hospital uuid;
  v_s1 uuid;
  v_s2 uuid;
  v_s3 uuid;
  v_s4 uuid;
BEGIN
  SELECT id INTO v_hospital FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  IF v_hospital IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_onboarding_stuck_points_r2544
    (hospital_user_id, stuck_at_stage, detected_at, stuck_days, stuck_kind, resolution_playbook_md, owner_email, status, resolved_at, notes)
  VALUES (v_hospital, 'kyc', now() - interval '18 days', 18, 'legal',
    E'# KYC stuck playbook\n- Re-send Udyam cert\n- Founder call to hospital legal\n- Offer notarized affidavit option',
    'founder@equipseva.in', 'resolved', now() - interval '4 days', 'Hospital legal needed extra affidavit')
  RETURNING id INTO v_s1;

  INSERT INTO public.customer_onboarding_stuck_points_r2544
    (hospital_user_id, stuck_at_stage, detected_at, stuck_days, stuck_kind, resolution_playbook_md, owner_email, status, notes)
  VALUES (v_hospital, 'training', now() - interval '9 days', 9, 'training',
    E'# Training stuck playbook\n- Schedule on-site refresher\n- Send Hindi training video\n- Assign rapport-strong engineer',
    'ops@equipseva.in', 'in_progress', 'Hospital biomed team has rotating shifts')
  RETURNING id INTO v_s2;

  INSERT INTO public.customer_onboarding_stuck_points_r2544
    (hospital_user_id, stuck_at_stage, detected_at, stuck_days, stuck_kind, resolution_playbook_md, owner_email, status, resolved_at, notes)
  VALUES (v_hospital, 'installation', now() - interval '24 days', 24, 'equipment',
    E'# Install stuck playbook\n- Confirm power/network site survey\n- Coordinate logistics window',
    'logistics@equipseva.in', 'resolved', now() - interval '6 days', 'Mains power upgrade required')
  RETURNING id INTO v_s3;

  INSERT INTO public.customer_onboarding_stuck_points_r2544
    (hospital_user_id, stuck_at_stage, detected_at, stuck_days, stuck_kind, resolution_playbook_md, owner_email, status, notes)
  VALUES (v_hospital, 'contract', now() - interval '5 days', 5, 'finance',
    E'# Contract stuck playbook\n- Adjust payment terms\n- Offer staged AMC',
    'finance@equipseva.in', 'open', 'CFO requested net-60')
  RETURNING id INTO v_s4;

  INSERT INTO public.stuck_point_resolution_outcomes_r2544
    (stuck_id, resolution_at, resolution_kind, outcome, owner_email, lessons_md, notes)
  VALUES
    (v_s1, now() - interval '4 days', 'founder_intervention', 'positive', 'founder@equipseva.in',
      E'- Founder call beats legal email chain\n- Pre-stage affidavit template', 'Closed in 14 days'),
    (v_s2, now() - interval '2 days', 'playbook', 'pending', 'ops@equipseva.in',
      E'- Hindi material lifts engagement', 'Refresher scheduled'),
    (v_s3, now() - interval '6 days', 'escalation', 'neutral', 'logistics@equipseva.in',
      E'- Site survey checklist needs power audit', 'Logistics window booked'),
    (v_s4, now() - interval '1 day', 'discount', 'positive', 'finance@equipseva.in',
      E'- Staged AMC unlocks CFO sign-off', 'Pending contract signature');
END
$seed$;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_stuck_points_r2544()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  stuck_at_stage text,
  detected_at timestamptz,
  stuck_days int,
  stuck_kind text,
  owner_email text,
  status text,
  resolved_at timestamptz,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, p.email, s.stuck_at_stage, s.detected_at, s.stuck_days,
         s.stuck_kind, s.owner_email, s.status, s.resolved_at, s.notes
  FROM public.customer_onboarding_stuck_points_r2544 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.detected_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_stuck_points_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stuck_points_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_resolution_outcomes_r2544()
RETURNS TABLE (
  id uuid,
  stuck_id uuid,
  stuck_stage text,
  resolution_at timestamptz,
  resolution_kind text,
  outcome text,
  owner_email text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.stuck_id, s.stuck_at_stage, o.resolution_at, o.resolution_kind,
         o.outcome, o.owner_email, o.notes
  FROM public.stuck_point_resolution_outcomes_r2544 o
  LEFT JOIN public.customer_onboarding_stuck_points_r2544 s ON s.id = o.stuck_id
  ORDER BY o.resolution_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_resolution_outcomes_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_resolution_outcomes_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_stuck_focus_r2544()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  stuck_at_stage text,
  stuck_kind text,
  stuck_days int,
  status text,
  owner_email text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.stuck_at_stage, s.stuck_kind, s.stuck_days, s.status, s.owner_email
  FROM public.customer_onboarding_stuck_points_r2544 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.status IN ('open','in_progress')
  ORDER BY s.stuck_days DESC, s.detected_at ASC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_stuck_focus_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_stuck_focus_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.stage_breakdown_r2544()
RETURNS TABLE (
  stuck_at_stage text,
  total_count bigint,
  open_count bigint,
  resolved_count bigint,
  avg_stuck_days numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stuck_at_stage,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE s.status IN ('open','in_progress'))::bigint,
         COUNT(*) FILTER (WHERE s.status = 'resolved')::bigint,
         ROUND(AVG(s.stuck_days)::numeric, 1)
  FROM public.customer_onboarding_stuck_points_r2544 s
  GROUP BY s.stuck_at_stage
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.stage_breakdown_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_breakdown_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.kind_distribution_r2544()
RETURNS TABLE (
  stuck_kind text,
  total_count bigint,
  avg_stuck_days numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stuck_kind,
         COUNT(*)::bigint,
         ROUND(AVG(s.stuck_days)::numeric, 1)
  FROM public.customer_onboarding_stuck_points_r2544 s
  GROUP BY s.stuck_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.kind_distribution_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_distribution_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_resolution_trend_r2544()
RETURNS TABLE (
  month_start timestamptz,
  resolutions bigint,
  positive_count bigint,
  negative_count bigint,
  pending_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', o.resolution_at)::timestamptz,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE o.outcome = 'positive')::bigint,
         COUNT(*) FILTER (WHERE o.outcome = 'negative')::bigint,
         COUNT(*) FILTER (WHERE o.outcome = 'pending')::bigint
  FROM public.stuck_point_resolution_outcomes_r2544 o
  GROUP BY date_trunc('month', o.resolution_at)
  ORDER BY date_trunc('month', o.resolution_at) DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_resolution_trend_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_resolution_trend_r2544() TO authenticated;

CREATE OR REPLACE FUNCTION public.lessons_summary_r2544()
RETURNS TABLE (
  resolution_kind text,
  outcome text,
  total_count bigint,
  sample_lessons_md text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.resolution_kind,
         o.outcome,
         COUNT(*)::bigint,
         (ARRAY_AGG(o.lessons_md ORDER BY o.resolution_at DESC))[1]
  FROM public.stuck_point_resolution_outcomes_r2544 o
  WHERE o.lessons_md IS NOT NULL
  GROUP BY o.resolution_kind, o.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.lessons_summary_r2544() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lessons_summary_r2544() TO authenticated;
