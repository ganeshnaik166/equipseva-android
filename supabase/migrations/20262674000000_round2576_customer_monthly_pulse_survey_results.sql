-- Round 2576: customer-monthly-pulse-survey-results
-- Hospital monthly pulse surveys with NPS, CSAT, verbatims, top concerns + follow-up actions.

BEGIN;

-- ============================================================================
-- TABLE: customer_monthly_pulse_surveys_r2576
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_monthly_pulse_surveys_r2576 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  survey_wave_label text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  nps int CHECK (nps IS NULL OR (nps >= 0 AND nps <= 10)),
  csat int CHECK (csat IS NULL OR (csat >= 0 AND csat <= 5)),
  verbatim_md text,
  top_concern text,
  owner_email text,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','completed','expired','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pulse_surveys_r2576_hosp ON public.customer_monthly_pulse_surveys_r2576(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_pulse_surveys_r2576_wave ON public.customer_monthly_pulse_surveys_r2576(survey_wave_label);
CREATE INDEX IF NOT EXISTS idx_pulse_surveys_r2576_status ON public.customer_monthly_pulse_surveys_r2576(status);
CREATE INDEX IF NOT EXISTS idx_pulse_surveys_r2576_sent ON public.customer_monthly_pulse_surveys_r2576(sent_at DESC);

ALTER TABLE public.customer_monthly_pulse_surveys_r2576 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_monthly_pulse_surveys_r2576;
CREATE POLICY founder_all ON public.customer_monthly_pulse_surveys_r2576
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: pulse_followup_actions_r2576
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pulse_followup_actions_r2576 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.customer_monthly_pulse_surveys_r2576(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','training','refund','feature_request')),
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pulse_followups_r2576_survey ON public.pulse_followup_actions_r2576(survey_id);
CREATE INDEX IF NOT EXISTS idx_pulse_followups_r2576_status ON public.pulse_followup_actions_r2576(status);
CREATE INDEX IF NOT EXISTS idx_pulse_followups_r2576_action ON public.pulse_followup_actions_r2576(action_at DESC);

ALTER TABLE public.pulse_followup_actions_r2576 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pulse_followup_actions_r2576;
CREATE POLICY founder_all ON public.pulse_followup_actions_r2576
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_hosp uuid;
  v_s1 uuid;
  v_s2 uuid;
  v_s3 uuid;
  v_s4 uuid;
BEGIN
  SELECT id INTO v_hosp FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  IF v_hosp IS NULL THEN
    SELECT id INTO v_hosp FROM public.profiles ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_hosp IS NOT NULL THEN
    INSERT INTO public.customer_monthly_pulse_surveys_r2576
      (hospital_user_id, survey_wave_label, sent_at, completed_at, nps, csat, verbatim_md, top_concern, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-06', (now() - interval '20 days')::timestamptz, (now() - interval '18 days')::timestamptz, 9, 5,
        'Engineers super responsive. AMC value clear.', 'spare parts ETA', 'founder@equipseva.in', 'completed', 'promoter')
    RETURNING id INTO v_s1;

    INSERT INTO public.customer_monthly_pulse_surveys_r2576
      (hospital_user_id, survey_wave_label, sent_at, completed_at, nps, csat, verbatim_md, top_concern, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-05', (now() - interval '50 days')::timestamptz, (now() - interval '48 days')::timestamptz, 7, 4,
        'Mostly good. One delayed visit last month.', 'visit punctuality', 'founder@equipseva.in', 'completed', 'passive')
    RETURNING id INTO v_s2;

    INSERT INTO public.customer_monthly_pulse_surveys_r2576
      (hospital_user_id, survey_wave_label, sent_at, completed_at, nps, csat, verbatim_md, top_concern, owner_email, status, notes)
    VALUES
      (v_hosp, '2026-04', (now() - interval '80 days')::timestamptz, (now() - interval '79 days')::timestamptz, 5, 3,
        'Pricing on parts feels steep. Service okay.', 'parts pricing', 'founder@equipseva.in', 'completed', 'detractor')
    RETURNING id INTO v_s3;

    INSERT INTO public.customer_monthly_pulse_surveys_r2576
      (hospital_user_id, survey_wave_label, sent_at, status, notes)
    VALUES
      (v_hosp, '2026-06b', (now() - interval '5 days')::timestamptz, 'sent', 'awaiting response')
    RETURNING id INTO v_s4;

    INSERT INTO public.pulse_followup_actions_r2576
      (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, status, notes)
    VALUES
      (v_s1, 'call', (now() - interval '15 days')::timestamptz, 'founder@equipseva.in', 'positive', (now() + interval '15 days')::timestamptz, 'done', 'thank-you call'),
      (v_s2, 'visit', (now() - interval '40 days')::timestamptz, 'founder@equipseva.in', 'neutral', (now() + interval '10 days')::timestamptz, 'in_progress', 'punctuality review scheduled'),
      (v_s3, 'refund', (now() - interval '70 days')::timestamptz, 'founder@equipseva.in', 'positive', NULL, 'done', 'goodwill refund on overpriced part'),
      (v_s3, 'feature_request', (now() - interval '65 days')::timestamptz, 'founder@equipseva.in', 'pending', (now() + interval '5 days')::timestamptz, 'open', 'parts price transparency page');
  END IF;
END $seed$;

-- ============================================================================
-- RPC: list_surveys_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_surveys_r2576()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  survey_wave_label text,
  sent_at timestamptz,
  completed_at timestamptz,
  nps int,
  csat int,
  verbatim_md text,
  top_concern text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.hospital_user_id,
    p.email::text AS hospital_email,
    s.survey_wave_label,
    s.sent_at,
    s.completed_at,
    s.nps,
    s.csat,
    s.verbatim_md,
    s.top_concern,
    s.owner_email,
    s.status,
    s.notes,
    s.created_at
  FROM public.customer_monthly_pulse_surveys_r2576 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.sent_at DESC NULLS LAST, s.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_surveys_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_surveys_r2576() TO authenticated;

-- ============================================================================
-- RPC: list_followups_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_followups_r2576()
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  survey_wave_label text,
  hospital_email text,
  action_kind text,
  action_at timestamptz,
  owner_email text,
  outcome text,
  follow_up_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.survey_id,
    s.survey_wave_label,
    p.email::text AS hospital_email,
    f.action_kind,
    f.action_at,
    f.owner_email,
    f.outcome,
    f.follow_up_at,
    f.status,
    f.notes,
    f.created_at
  FROM public.pulse_followup_actions_r2576 f
  JOIN public.customer_monthly_pulse_surveys_r2576 s ON s.id = f.survey_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY f.action_at DESC NULLS LAST, f.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followups_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followups_r2576() TO authenticated;

-- ============================================================================
-- RPC: nps_distribution_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.nps_distribution_r2576()
RETURNS TABLE (
  bucket text,
  response_count bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total FROM public.customer_monthly_pulse_surveys_r2576 WHERE nps IS NOT NULL;
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    b.bucket,
    coalesce(c.cnt, 0)::bigint AS response_count,
    round((coalesce(c.cnt, 0)::numeric * 100.0) / v_total::numeric, 1) AS pct
  FROM (VALUES
    ('promoter (9-10)'::text, 1),
    ('passive (7-8)'::text, 2),
    ('detractor (0-6)'::text, 3)
  ) AS b(bucket, ord)
  LEFT JOIN (
    SELECT
      CASE
        WHEN nps >= 9 THEN 'promoter (9-10)'
        WHEN nps >= 7 THEN 'passive (7-8)'
        ELSE 'detractor (0-6)'
      END AS bucket,
      count(*)::bigint AS cnt
    FROM public.customer_monthly_pulse_surveys_r2576
    WHERE nps IS NOT NULL
    GROUP BY 1
  ) c ON c.bucket = b.bucket
  ORDER BY b.ord ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_distribution_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_distribution_r2576() TO authenticated;

-- ============================================================================
-- RPC: csat_distribution_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.csat_distribution_r2576()
RETURNS TABLE (
  csat_score int,
  response_count bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total FROM public.customer_monthly_pulse_surveys_r2576 WHERE csat IS NOT NULL;
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT
    g.score AS csat_score,
    coalesce(c.cnt, 0)::bigint AS response_count,
    round((coalesce(c.cnt, 0)::numeric * 100.0) / v_total::numeric, 1) AS pct
  FROM generate_series(0, 5) AS g(score)
  LEFT JOIN (
    SELECT csat, count(*)::bigint AS cnt
    FROM public.customer_monthly_pulse_surveys_r2576
    WHERE csat IS NOT NULL
    GROUP BY csat
  ) c ON c.csat = g.score
  ORDER BY g.score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.csat_distribution_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.csat_distribution_r2576() TO authenticated;

-- ============================================================================
-- RPC: top_concerns_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_concerns_r2576()
RETURNS TABLE (
  top_concern text,
  mention_count bigint,
  avg_nps numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.top_concern,
    count(*)::bigint AS mention_count,
    round(avg(s.nps)::numeric, 2) AS avg_nps,
    round(avg(s.csat)::numeric, 2) AS avg_csat
  FROM public.customer_monthly_pulse_surveys_r2576 s
  WHERE s.top_concern IS NOT NULL AND length(trim(s.top_concern)) > 0
  GROUP BY s.top_concern
  ORDER BY mention_count DESC, s.top_concern ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_concerns_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concerns_r2576() TO authenticated;

-- ============================================================================
-- RPC: monthly_completion_trend_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_completion_trend_r2576()
RETURNS TABLE (
  survey_wave_label text,
  sent_count bigint,
  completed_count bigint,
  completion_pct numeric,
  avg_nps numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.survey_wave_label,
    count(*)::bigint AS sent_count,
    count(*) FILTER (WHERE s.status = 'completed')::bigint AS completed_count,
    CASE
      WHEN count(*) > 0
      THEN round((count(*) FILTER (WHERE s.status = 'completed')::numeric * 100.0) / count(*)::numeric, 1)
      ELSE 0
    END AS completion_pct,
    round(avg(s.nps)::numeric, 2) AS avg_nps,
    round(avg(s.csat)::numeric, 2) AS avg_csat
  FROM public.customer_monthly_pulse_surveys_r2576 s
  GROUP BY s.survey_wave_label
  ORDER BY s.survey_wave_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_completion_trend_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_completion_trend_r2576() TO authenticated;

-- ============================================================================
-- RPC: top_hospitals_by_nps_r2576
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_hospitals_by_nps_r2576()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  survey_count bigint,
  avg_nps numeric,
  avg_csat numeric,
  last_wave text,
  last_completed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      s.hospital_user_id,
      count(*)::bigint AS survey_count,
      round(avg(s.nps)::numeric, 2) AS avg_nps,
      round(avg(s.csat)::numeric, 2) AS avg_csat,
      max(s.completed_at) AS last_completed_at
    FROM public.customer_monthly_pulse_surveys_r2576 s
    WHERE s.nps IS NOT NULL
    GROUP BY s.hospital_user_id
  ),
  latest AS (
    SELECT DISTINCT ON (s.hospital_user_id)
      s.hospital_user_id,
      s.survey_wave_label AS last_wave
    FROM public.customer_monthly_pulse_surveys_r2576 s
    WHERE s.nps IS NOT NULL
    ORDER BY s.hospital_user_id, s.completed_at DESC NULLS LAST, s.sent_at DESC NULLS LAST
  )
  SELECT
    a.hospital_user_id,
    p.email::text AS hospital_email,
    a.survey_count,
    a.avg_nps,
    a.avg_csat,
    l.last_wave,
    a.last_completed_at
  FROM agg a
  LEFT JOIN latest l ON l.hospital_user_id = a.hospital_user_id
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.avg_nps DESC NULLS LAST, a.survey_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_nps_r2576() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_nps_r2576() TO authenticated;

