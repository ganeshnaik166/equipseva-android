-- Round 2448: Customer Clinical Outcome Link
-- Hospital × equipment uptime × clinical incident × outcome story × value narrative

CREATE TABLE IF NOT EXISTS public.customer_clinical_outcomes_r2448 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  observation_period_start date NOT NULL,
  observation_period_end date NOT NULL,
  uptime_pct numeric(5,2) NOT NULL CHECK (uptime_pct >= 0 AND uptime_pct <= 100),
  clinical_incident_count int NOT NULL DEFAULT 0 CHECK (clinical_incident_count >= 0),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('life_saved','diagnosis_accelerated','treatment_completed','complication_avoided','training_completed')),
  outcome_story_md text,
  value_narrative_md text,
  dollar_value_estimate_rupees bigint NOT NULL DEFAULT 0 CHECK (dollar_value_estimate_rupees >= 0),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.outcome_story_publications_r2448 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outcome_id uuid NOT NULL REFERENCES public.customer_clinical_outcomes_r2448(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('website','case_study','conference','social','investor_pack')),
  published_at timestamptz NOT NULL DEFAULT now(),
  audience_size int NOT NULL DEFAULT 0 CHECK (audience_size >= 0),
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score >= 0 AND engagement_score <= 100),
  status text NOT NULL CHECK (status IN ('draft','scheduled','published','featured')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_clinical_outcomes_r2448 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outcome_story_publications_r2448 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_clinical_outcomes_r2448;
CREATE POLICY founder_all ON public.customer_clinical_outcomes_r2448
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.outcome_story_publications_r2448;
CREATE POLICY founder_all ON public.outcome_story_publications_r2448
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_o1 uuid;
  v_o2 uuid;
  v_o3 uuid;
  v_o4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, gen_random_uuid()) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, gen_random_uuid()), COALESCE(v_h2, gen_random_uuid())) ORDER BY created_at LIMIT 1;

  v_h1 := COALESCE(v_h1, (SELECT id FROM public.profiles ORDER BY created_at LIMIT 1));
  v_h2 := COALESCE(v_h2, v_h1);
  v_h3 := COALESCE(v_h3, v_h1);

  IF v_h1 IS NULL THEN RETURN; END IF;

  INSERT INTO public.customer_clinical_outcomes_r2448(
    hospital_user_id, equipment_label, equipment_kind, observation_period_start, observation_period_end,
    uptime_pct, clinical_incident_count, outcome_kind, outcome_story_md, value_narrative_md,
    dollar_value_estimate_rupees, owner_email, notes
  ) VALUES
    (v_h1, 'Phillips MRI 1.5T - Unit A', 'mri',
     '2026-05-01'::date, '2026-05-31'::date, 99.40, 0, 'life_saved',
     'Stroke patient scanned within 18 minutes of arrival; clot retrieval succeeded.',
     'Reliable MRI uptime enabled door-to-needle under 30 minutes; saved life.',
     2500000, 'cmo@apollo-hyd.in', 'Apollo Jubilee Hills'),
    (v_h2, 'GE CT Scanner 64-slice', 'ct',
     '2026-05-01'::date, '2026-05-31'::date, 98.10, 1, 'diagnosis_accelerated',
     'Polytrauma scan completed in 4 minutes vs 22-minute prior baseline.',
     'Faster CT throughput cut ED stays; 3 trauma cases diagnosed same-shift.',
     1200000, 'radiology@kims.in', 'KIMS Secunderabad'),
    (v_h3, 'Mindray Anesthesia Workstation', 'anesthesia',
     '2026-04-15'::date, '2026-05-15'::date, 99.95, 0, 'complication_avoided',
     'Zero ventilator alarms across 42 OT cases; no hypoxia events.',
     'High-availability anesthesia plant reduced OT cancellations to zero.',
     800000, 'ot@yashoda.in', 'Yashoda Somajiguda');

  SELECT id INTO v_o1 FROM public.customer_clinical_outcomes_r2448 WHERE equipment_label = 'Phillips MRI 1.5T - Unit A' LIMIT 1;
  SELECT id INTO v_o2 FROM public.customer_clinical_outcomes_r2448 WHERE equipment_label = 'GE CT Scanner 64-slice' LIMIT 1;
  SELECT id INTO v_o3 FROM public.customer_clinical_outcomes_r2448 WHERE equipment_label = 'Mindray Anesthesia Workstation' LIMIT 1;

  INSERT INTO public.outcome_story_publications_r2448(
    outcome_id, channel, published_at, audience_size, engagement_score, status, notes
  ) VALUES
    (v_o1, 'case_study', '2026-06-05T10:00:00+05:30'::timestamptz, 1200, 78, 'published', 'PDF download from website'),
    (v_o1, 'investor_pack', '2026-06-10T09:00:00+05:30'::timestamptz, 25, 92, 'featured', 'Q2 board deck slide 14'),
    (v_o2, 'social', '2026-06-08T14:00:00+05:30'::timestamptz, 5400, 64, 'published', 'LinkedIn carousel'),
    (v_o3, 'conference', '2026-06-15T11:00:00+05:30'::timestamptz, 320, 81, 'scheduled', 'AIIMS biomedical summit'),
    (v_o2, 'website', '2026-06-20T08:00:00+05:30'::timestamptz, 0, 0, 'draft', 'Awaiting CMO review');
END
$seed$;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_outcomes_r2448()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  equipment_label text,
  equipment_kind text,
  observation_period_start date,
  observation_period_end date,
  uptime_pct numeric,
  clinical_incident_count int,
  outcome_kind text,
  dollar_value_estimate_rupees bigint,
  owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, p.email, o.equipment_label, o.equipment_kind,
         o.observation_period_start, o.observation_period_end,
         o.uptime_pct, o.clinical_incident_count, o.outcome_kind,
         o.dollar_value_estimate_rupees, o.owner_email, o.created_at
  FROM public.customer_clinical_outcomes_r2448 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  ORDER BY o.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_publications_r2448()
RETURNS TABLE(
  id uuid,
  outcome_id uuid,
  equipment_label text,
  channel text,
  published_at timestamptz,
  audience_size int,
  engagement_score int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pub.id, pub.outcome_id, o.equipment_label, pub.channel,
         pub.published_at, pub.audience_size, pub.engagement_score,
         pub.status, pub.notes
  FROM public.outcome_story_publications_r2448 pub
  LEFT JOIN public.customer_clinical_outcomes_r2448 o ON o.id = pub.outcome_id
  ORDER BY pub.published_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_publications_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_publications_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_outcome_stories_r2448()
RETURNS TABLE(
  outcome_id uuid,
  equipment_label text,
  outcome_kind text,
  dollar_value_estimate_rupees bigint,
  publication_count bigint,
  total_audience bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.equipment_label, o.outcome_kind, o.dollar_value_estimate_rupees,
         COUNT(pub.id)::bigint,
         COALESCE(SUM(pub.audience_size),0)::bigint,
         COALESCE(AVG(NULLIF(pub.engagement_score,0)),0)::numeric
  FROM public.customer_clinical_outcomes_r2448 o
  LEFT JOIN public.outcome_story_publications_r2448 pub ON pub.outcome_id = o.id
  GROUP BY o.id, o.equipment_label, o.outcome_kind, o.dollar_value_estimate_rupees
  ORDER BY o.dollar_value_estimate_rupees DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_outcome_stories_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_outcome_stories_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.channel_breakdown_r2448()
RETURNS TABLE(
  channel text,
  publication_count bigint,
  total_audience bigint,
  avg_engagement numeric,
  featured_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT pub.channel,
         COUNT(*)::bigint,
         COALESCE(SUM(pub.audience_size),0)::bigint,
         COALESCE(AVG(NULLIF(pub.engagement_score,0)),0)::numeric,
         COUNT(*) FILTER (WHERE pub.status = 'featured')::bigint
  FROM public.outcome_story_publications_r2448 pub
  GROUP BY pub.channel
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.channel_breakdown_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_breakdown_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_publication_trend_r2448()
RETURNS TABLE(
  month_start date,
  publication_count bigint,
  total_audience bigint,
  avg_engagement numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', pub.published_at)::date,
         COUNT(*)::bigint,
         COALESCE(SUM(pub.audience_size),0)::bigint,
         COALESCE(AVG(NULLIF(pub.engagement_score,0)),0)::numeric
  FROM public.outcome_story_publications_r2448 pub
  GROUP BY date_trunc('month', pub.published_at)
  ORDER BY date_trunc('month', pub.published_at) DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_publication_trend_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_publication_trend_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_hospitals_by_outcomes_r2448()
RETURNS TABLE(
  hospital_email text,
  outcome_count bigint,
  total_value_rupees bigint,
  avg_uptime numeric,
  total_incidents bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email,
         COUNT(o.id)::bigint,
         COALESCE(SUM(o.dollar_value_estimate_rupees),0)::bigint,
         COALESCE(AVG(o.uptime_pct),0)::numeric,
         COALESCE(SUM(o.clinical_incident_count),0)::bigint
  FROM public.customer_clinical_outcomes_r2448 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  GROUP BY p.email
  ORDER BY COALESCE(SUM(o.dollar_value_estimate_rupees),0) DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_outcomes_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_outcomes_r2448() TO authenticated;

CREATE OR REPLACE FUNCTION public.outcome_kind_distribution_r2448()
RETURNS TABLE(
  outcome_kind text,
  outcome_count bigint,
  total_value_rupees bigint,
  avg_uptime numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.outcome_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(o.dollar_value_estimate_rupees),0)::bigint,
         COALESCE(AVG(o.uptime_pct),0)::numeric
  FROM public.customer_clinical_outcomes_r2448 o
  GROUP BY o.outcome_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.outcome_kind_distribution_r2448() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_kind_distribution_r2448() TO authenticated;
