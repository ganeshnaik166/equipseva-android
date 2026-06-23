BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_onboarding_surveys_r2500 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  survey_wave_label text NOT NULL DEFAULT '',
  sent_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  nps int CHECK (nps IS NULL OR (nps >= 0 AND nps <= 10)),
  csat int CHECK (csat IS NULL OR (csat >= 0 AND csat <= 5)),
  verbatim_themes_md text NOT NULL DEFAULT '',
  top_compliment text NOT NULL DEFAULT '',
  top_complaint text NOT NULL DEFAULT '',
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','completed','expired','skipped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.onboarding_survey_followups_r2500 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid REFERENCES public.customer_onboarding_surveys_r2500(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','refund','training','feature_request')),
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text NOT NULL DEFAULT '',
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_onboarding_surveys_r2500 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_survey_followups_r2500 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_surveys_r2500;
CREATE POLICY founder_all ON public.customer_onboarding_surveys_r2500
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.onboarding_survey_followups_r2500;
CREATE POLICY founder_all ON public.onboarding_survey_followups_r2500
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed surveys
INSERT INTO public.customer_onboarding_surveys_r2500 (survey_wave_label, sent_at, completed_at, nps, csat, verbatim_themes_md, top_compliment, top_complaint, owner_email, status, notes) VALUES
('Wave-A May 2026', '2026-05-15'::timestamptz, '2026-05-18'::timestamptz, 9, 5, '- love engineer responsiveness\n- AMC value clear\n- portal easy', 'Engineer arrived within 4 hours', 'Wish for Telugu UI', 'founder@equipseva.in', 'completed', 'Tier-1 hospital, advocate'),
('Wave-A May 2026', '2026-05-15'::timestamptz, '2026-05-20'::timestamptz, 7, 4, '- happy with uptime\n- pricing fair\n- want more spare parts', 'Uptime improved 30%', 'Spare parts ETA too long', 'founder@equipseva.in', 'completed', 'Tier-2 city'),
('Wave-A May 2026', '2026-05-15'::timestamptz, NULL, NULL, NULL, '', '', '', 'founder@equipseva.in', 'expired', 'No response after 3 reminders'),
('Wave-B June 2026', '2026-06-05'::timestamptz, '2026-06-08'::timestamptz, 3, 2, '- frustrated with bench billing\n- engineer rotation broke trust', 'CEO call resolved billing', 'Same engineer changed 3 times', 'founder@equipseva.in', 'completed', 'Detractor — needs save call'),
('Wave-B June 2026', '2026-06-05'::timestamptz, '2026-06-10'::timestamptz, 10, 5, '- best vendor ever\n- founder cares\n- AMC tier upgrades worth it', 'Founder personally called', '', 'founder@equipseva.in', 'completed', 'Promoter — case study candidate');

-- Seed followups
INSERT INTO public.onboarding_survey_followups_r2500 (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, notes)
SELECT id, 'call', '2026-05-19'::timestamptz, 'founder@equipseva.in', 'positive', '2026-06-19'::timestamptz, 'Thank-you call + referral ask'
FROM public.customer_onboarding_surveys_r2500 WHERE notes = 'Tier-1 hospital, advocate' LIMIT 1;

INSERT INTO public.onboarding_survey_followups_r2500 (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, notes)
SELECT id, 'feature_request', '2026-05-21'::timestamptz, 'founder@equipseva.in', 'neutral', '2026-07-21'::timestamptz, 'Spare parts ETA dashboard queued'
FROM public.customer_onboarding_surveys_r2500 WHERE notes = 'Tier-2 city' LIMIT 1;

INSERT INTO public.onboarding_survey_followups_r2500 (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, notes)
SELECT id, 'visit', '2026-06-09'::timestamptz, 'founder@equipseva.in', 'negative', '2026-06-30'::timestamptz, 'Onsite visit booked — save attempt'
FROM public.customer_onboarding_surveys_r2500 WHERE notes = 'Detractor — needs save call' LIMIT 1;

INSERT INTO public.onboarding_survey_followups_r2500 (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, notes)
SELECT id, 'training', '2026-06-11'::timestamptz, 'founder@equipseva.in', 'positive', NULL, 'Free training session as goodwill'
FROM public.customer_onboarding_surveys_r2500 WHERE notes = 'Promoter — case study candidate' LIMIT 1;

INSERT INTO public.onboarding_survey_followups_r2500 (survey_id, action_kind, action_at, owner_email, outcome, follow_up_at, notes)
SELECT id, 'refund', '2026-06-12'::timestamptz, 'founder@equipseva.in', 'pending', '2026-06-25'::timestamptz, 'Pro-rata refund for engineer rotation pain'
FROM public.customer_onboarding_surveys_r2500 WHERE notes = 'Detractor — needs save call' LIMIT 1;

-- RPC 1: list surveys
CREATE OR REPLACE FUNCTION public.list_surveys_r2500()
RETURNS TABLE(id uuid, survey_wave_label text, sent_at timestamptz, completed_at timestamptz, nps int, csat int, top_compliment text, top_complaint text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.survey_wave_label, s.sent_at, s.completed_at, s.nps, s.csat, s.top_compliment, s.top_complaint, s.owner_email, s.status, s.notes
  FROM public.customer_onboarding_surveys_r2500 s
  ORDER BY s.sent_at DESC NULLS LAST, s.id DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_surveys_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_surveys_r2500() TO authenticated;

-- RPC 2: list followups
CREATE OR REPLACE FUNCTION public.list_followups_r2500()
RETURNS TABLE(id uuid, survey_id uuid, action_kind text, action_at timestamptz, owner_email text, outcome text, follow_up_at timestamptz, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.survey_id, f.action_kind, f.action_at, f.owner_email, f.outcome, f.follow_up_at, f.notes
  FROM public.onboarding_survey_followups_r2500 f
  ORDER BY f.action_at DESC NULLS LAST, f.id DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followups_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followups_r2500() TO authenticated;

-- RPC 3: top complaint themes
CREATE OR REPLACE FUNCTION public.top_complaint_themes_r2500()
RETURNS TABLE(top_complaint text, mention_count bigint, avg_nps numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.top_complaint, COUNT(*)::bigint AS mention_count, ROUND(AVG(s.nps)::numeric, 2) AS avg_nps
  FROM public.customer_onboarding_surveys_r2500 s
  WHERE s.top_complaint <> '' AND s.status = 'completed'
  GROUP BY s.top_complaint
  ORDER BY mention_count DESC, avg_nps ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_complaint_themes_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_complaint_themes_r2500() TO authenticated;

-- RPC 4: NPS distribution
CREATE OR REPLACE FUNCTION public.nps_distribution_r2500()
RETURNS TABLE(bucket text, response_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN s.nps >= 9 THEN 'promoter'
      WHEN s.nps >= 7 THEN 'passive'
      ELSE 'detractor'
    END AS bucket,
    COUNT(*)::bigint AS response_count
  FROM public.customer_onboarding_surveys_r2500 s
  WHERE s.nps IS NOT NULL
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.nps_distribution_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nps_distribution_r2500() TO authenticated;

-- RPC 5: CSAT distribution
CREATE OR REPLACE FUNCTION public.csat_distribution_r2500()
RETURNS TABLE(csat_score int, response_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.csat, COUNT(*)::bigint
  FROM public.customer_onboarding_surveys_r2500 s
  WHERE s.csat IS NOT NULL
  GROUP BY s.csat
  ORDER BY s.csat DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.csat_distribution_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.csat_distribution_r2500() TO authenticated;

-- RPC 6: top hospitals by NPS
CREATE OR REPLACE FUNCTION public.top_hospitals_by_nps_r2500()
RETURNS TABLE(hospital_user_id uuid, hospital_email text, avg_nps numeric, response_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.hospital_user_id, COALESCE(p.email, 'unknown'), ROUND(AVG(s.nps)::numeric, 2), COUNT(*)::bigint
  FROM public.customer_onboarding_surveys_r2500 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.nps IS NOT NULL
  GROUP BY s.hospital_user_id, p.email
  ORDER BY 3 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_nps_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_nps_r2500() TO authenticated;

-- RPC 7: weekly completion trend
CREATE OR REPLACE FUNCTION public.weekly_completion_trend_r2500()
RETURNS TABLE(week_start date, sent_count bigint, completed_count bigint, completion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', s.sent_at)::date AS week_start,
    COUNT(*)::bigint AS sent_count,
    COUNT(*) FILTER (WHERE s.status = 'completed')::bigint AS completed_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'completed') / NULLIF(COUNT(*),0), 1) AS completion_pct
  FROM public.customer_onboarding_surveys_r2500 s
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_completion_trend_r2500() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_completion_trend_r2500() TO authenticated;

