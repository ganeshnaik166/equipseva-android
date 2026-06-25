-- Round 2634: Engineer Customer Satisfaction Pulse Survey
-- Tracks short post-service pulse surveys + structured follow-up actions

-- =========================================================
-- Table 1: engineer_customer_pulse_surveys_r2634
-- =========================================================
CREATE TABLE IF NOT EXISTS public.engineer_customer_pulse_surveys_r2634 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  csat int CHECK (csat IS NULL OR (csat BETWEEN 0 AND 5)),
  nps int CHECK (nps IS NULL OR (nps BETWEEN 0 AND 10)),
  top_compliment text,
  top_complaint text,
  owner_email text,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','completed','expired','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_pulse_surveys_r2634 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_pulse_surveys_r2634;
CREATE POLICY founder_all ON public.engineer_customer_pulse_surveys_r2634
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================
-- Table 2: pulse_survey_followup_actions_r2634
-- =========================================================
CREATE TABLE IF NOT EXISTS public.pulse_survey_followup_actions_r2634 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.engineer_customer_pulse_surveys_r2634(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('thank_you','escalation','training','refund','feature_request')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pulse_survey_followup_actions_r2634 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pulse_survey_followup_actions_r2634;
CREATE POLICY founder_all ON public.pulse_survey_followup_actions_r2634
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================
-- Seed data
-- =========================================================
DO $seed$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_hosp_a uuid;
  v_hosp_b uuid;
  v_survey_1 uuid;
  v_survey_2 uuid;
  v_survey_3 uuid;
  v_survey_4 uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_b FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hosp_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_eng_a IS NULL OR v_hosp_a IS NULL THEN
    RETURN;
  END IF;

  IF v_eng_b IS NULL THEN v_eng_b := v_eng_a; END IF;
  IF v_hosp_b IS NULL THEN v_hosp_b := v_hosp_a; END IF;

  INSERT INTO public.engineer_customer_pulse_surveys_r2634
    (engineer_id, hospital_user_id, sent_at, csat, nps, top_compliment, top_complaint, owner_email, status, notes)
  VALUES
    (v_eng_a, v_hosp_a, (now() - interval '6 days')::timestamptz, 5, 9,
     'Fast response and clear communication', NULL, 'cx@equipseva.in', 'completed',
     'Hospital praised on-site speed')
  RETURNING id INTO v_survey_1;

  INSERT INTO public.engineer_customer_pulse_surveys_r2634
    (engineer_id, hospital_user_id, sent_at, csat, nps, top_compliment, top_complaint, owner_email, status, notes)
  VALUES
    (v_eng_b, v_hosp_b, (now() - interval '4 days')::timestamptz, 3, 6,
     NULL, 'Wait time for spare part too long', 'ops@equipseva.in', 'completed',
     'Spare part SLA breach flagged')
  RETURNING id INTO v_survey_2;

  INSERT INTO public.engineer_customer_pulse_surveys_r2634
    (engineer_id, hospital_user_id, sent_at, csat, nps, top_compliment, top_complaint, owner_email, status, notes)
  VALUES
    (v_eng_a, v_hosp_b, (now() - interval '2 days')::timestamptz, 4, 8,
     'Polite engineer', 'Invoice needs more detail', 'finance@equipseva.in', 'completed',
     'Mixed sentiment captured')
  RETURNING id INTO v_survey_3;

  INSERT INTO public.engineer_customer_pulse_surveys_r2634
    (engineer_id, hospital_user_id, sent_at, csat, nps, top_compliment, top_complaint, owner_email, status, notes)
  VALUES
    (v_eng_b, v_hosp_a, (now() - interval '1 day')::timestamptz, NULL, NULL,
     NULL, NULL, 'cx@equipseva.in', 'sent',
     'Awaiting response')
  RETURNING id INTO v_survey_4;

  INSERT INTO public.pulse_survey_followup_actions_r2634
    (survey_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES
    (v_survey_1, (now() - interval '5 days')::timestamptz, 'thank_you', 'positive', 'cx@equipseva.in', 'done',
     'Sent founder thank-you note'),
    (v_survey_2, (now() - interval '3 days')::timestamptz, 'escalation', 'neutral', 'ops@equipseva.in', 'open',
     'Routing to logistics lead'),
    (v_survey_2, (now() - interval '2 days')::timestamptz, 'training', 'pending', 'ops@equipseva.in', 'open',
     'Add ETA-setting playbook for engineer'),
    (v_survey_3, (now() - interval '1 day')::timestamptz, 'feature_request', 'pending', 'product@equipseva.in', 'open',
     'Invoice detail expansion roadmap');
END
$seed$;

-- =========================================================
-- RPC 1: list_surveys_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_surveys_r2634()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  hospital_user_id uuid,
  sent_at timestamptz,
  csat int,
  nps int,
  top_compliment text,
  top_complaint text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_id, s.hospital_user_id, s.sent_at, s.csat, s.nps,
         s.top_compliment, s.top_complaint, s.owner_email, s.status, s.notes, s.created_at
  FROM public.engineer_customer_pulse_surveys_r2634 s
  ORDER BY s.sent_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_surveys_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_surveys_r2634() TO authenticated;

-- =========================================================
-- RPC 2: list_followup_actions_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_followup_actions_r2634()
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.survey_id, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes, a.created_at
  FROM public.pulse_survey_followup_actions_r2634 a
  ORDER BY a.action_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followup_actions_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_actions_r2634() TO authenticated;

-- =========================================================
-- RPC 3: top_complaint_focus_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.top_complaint_focus_r2634()
RETURNS TABLE (
  complaint text,
  mentions bigint,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.top_complaint AS complaint,
         COUNT(*)::bigint AS mentions,
         ROUND(AVG(s.csat)::numeric, 2) AS avg_csat
  FROM public.engineer_customer_pulse_surveys_r2634 s
  WHERE s.top_complaint IS NOT NULL AND length(s.top_complaint) > 0
  GROUP BY s.top_complaint
  ORDER BY mentions DESC, avg_csat ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_complaint_focus_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_complaint_focus_r2634() TO authenticated;

-- =========================================================
-- RPC 4: csat_distribution_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.csat_distribution_r2634()
RETURNS TABLE (
  csat_bucket int,
  responses bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.csat AS csat_bucket,
         COUNT(*)::bigint AS responses
  FROM public.engineer_customer_pulse_surveys_r2634 s
  WHERE s.csat IS NOT NULL
  GROUP BY s.csat
  ORDER BY s.csat ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.csat_distribution_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.csat_distribution_r2634() TO authenticated;

-- =========================================================
-- RPC 5: nps_summary_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.nps_summary_r2634()
RETURNS TABLE (
  promoters bigint,
  passives bigint,
  detractors bigint,
  responses bigint,
  nps_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_promoters bigint;
  v_passives bigint;
  v_detractors bigint;
  v_total bigint;
  v_score numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) FILTER (WHERE nps >= 9),
         COUNT(*) FILTER (WHERE nps BETWEEN 7 AND 8),
         COUNT(*) FILTER (WHERE nps BETWEEN 0 AND 6),
         COUNT(*) FILTER (WHERE nps IS NOT NULL)
    INTO v_promoters, v_passives, v_detractors, v_total
  FROM public.engineer_customer_pulse_surveys_r2634;

  IF v_total > 0 THEN
    v_score := ROUND(((v_promoters - v_detractors)::numeric * 100.0) / v_total::numeric, 2);
  ELSE
    v_score := 0;
  END IF;

  RETURN QUERY SELECT v_promoters, v_passives, v_detractors, v_total, v_score;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_summary_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_summary_r2634() TO authenticated;

-- =========================================================
-- RPC 6: monthly_pulse_trend_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.monthly_pulse_trend_r2634()
RETURNS TABLE (
  month_start timestamptz,
  responses bigint,
  avg_csat numeric,
  avg_nps numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', s.sent_at) AS month_start,
         COUNT(*)::bigint AS responses,
         ROUND(AVG(s.csat)::numeric, 2) AS avg_csat,
         ROUND(AVG(s.nps)::numeric, 2) AS avg_nps
  FROM public.engineer_customer_pulse_surveys_r2634 s
  GROUP BY date_trunc('month', s.sent_at)
  ORDER BY month_start DESC
  LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pulse_trend_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pulse_trend_r2634() TO authenticated;

-- =========================================================
-- RPC 7: owner_load_r2634
-- =========================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2634()
RETURNS TABLE (
  owner_email text,
  open_actions bigint,
  done_actions bigint,
  dropped_actions bigint,
  total_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(a.owner_email, 'unassigned') AS owner_email,
         COUNT(*) FILTER (WHERE a.status = 'open')::bigint AS open_actions,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_actions,
         COUNT(*) FILTER (WHERE a.status = 'dropped')::bigint AS dropped_actions,
         COUNT(*)::bigint AS total_actions
  FROM public.pulse_survey_followup_actions_r2634 a
  GROUP BY COALESCE(a.owner_email, 'unassigned')
  ORDER BY open_actions DESC, total_actions DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2634() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2634() TO authenticated;
