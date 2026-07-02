-- Round 2438: Engineer Customer Praise Ledger
-- Captures unsolicited customer praise per engineer, breaks down by source/kind/CSAT, and
-- drives spot bonus + monthly/quarterly/annual award eligibility ledger.

BEGIN;

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_praise_events_r2438 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  praise_at timestamptz NOT NULL DEFAULT now(),
  praise_source text NOT NULL
    CHECK (praise_source IN ('call','email','inapp_review','whatsapp','sms','in_person','survey')),
  praise_kind text NOT NULL
    CHECK (praise_kind IN ('speed','expertise','professionalism','repair_quality','extra_mile','empathy')),
  praise_text text,
  csat_score numeric CHECK (csat_score IS NULL OR (csat_score >= 0 AND csat_score <= 10)),
  equipment_label text,
  repeated_praise_streak int NOT NULL DEFAULT 1 CHECK (repeated_praise_streak >= 1),
  award_eligibility text NOT NULL DEFAULT 'none'
    CHECK (award_eligibility IN ('none','spot_bonus','monthly_award','quarterly_award','annual_award')),
  bonus_rupees int NOT NULL DEFAULT 0 CHECK (bonus_rupees >= 0),
  bonus_paid_at timestamptz,
  bonus_paid_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_engineer    ON public.engineer_praise_events_r2438(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_hospital    ON public.engineer_praise_events_r2438(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_at          ON public.engineer_praise_events_r2438(praise_at);
CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_source      ON public.engineer_praise_events_r2438(praise_source);
CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_kind        ON public.engineer_praise_events_r2438(praise_kind);
CREATE INDEX IF NOT EXISTS idx_praise_evt_r2438_award       ON public.engineer_praise_events_r2438(award_eligibility);

CREATE TABLE IF NOT EXISTS public.praise_award_ledger_r2438 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  award_period_start date NOT NULL,
  award_period_end date NOT NULL,
  total_praise_count int NOT NULL DEFAULT 0 CHECK (total_praise_count >= 0),
  top_kind text,
  total_bonus_rupees bigint NOT NULL DEFAULT 0 CHECK (total_bonus_rupees >= 0),
  hospitals_count int NOT NULL DEFAULT 0 CHECK (hospitals_count >= 0),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','awarded','celebrated','dropped')),
  awarded_at timestamptz,
  awarded_by_email text,
  ceremony_at timestamptz,
  ceremony_notes_md text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (award_period_end >= award_period_start)
);

CREATE INDEX IF NOT EXISTS idx_praise_led_r2438_engineer    ON public.praise_award_ledger_r2438(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_praise_led_r2438_period      ON public.praise_award_ledger_r2438(award_period_start, award_period_end);
CREATE INDEX IF NOT EXISTS idx_praise_led_r2438_status      ON public.praise_award_ledger_r2438(status);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE public.engineer_praise_events_r2438 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.praise_award_ledger_r2438 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_praise_events_r2438;
CREATE POLICY founder_all ON public.engineer_praise_events_r2438
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.praise_award_ledger_r2438;
CREATE POLICY founder_all ON public.praise_award_ledger_r2438
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED
-- ============================================================================

DO $seed$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_eng_c uuid;
  v_hosp_a uuid;
  v_hosp_b uuid;
  v_hosp_c uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.engineers ORDER BY created_at ASC OFFSET 0 LIMIT 1;
  SELECT id INTO v_eng_b FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng_c FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  SELECT id INTO v_hosp_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 0 LIMIT 1;
  SELECT id INTO v_hosp_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp_c FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  IF v_eng_a IS NULL THEN
    RETURN;
  END IF;
  IF v_eng_b IS NULL THEN v_eng_b := v_eng_a; END IF;
  IF v_eng_c IS NULL THEN v_eng_c := v_eng_a; END IF;

  INSERT INTO public.engineer_praise_events_r2438
    (engineer_user_id, hospital_user_id, praise_at, praise_source, praise_kind, praise_text, csat_score, equipment_label, repeated_praise_streak, award_eligibility, bonus_rupees, bonus_paid_at, bonus_paid_by_email, notes)
  VALUES
    (v_eng_a, v_hosp_a, now() - interval '2 days',  'call',          'speed',           'Engineer reached ICU within 45 min for ventilator code-red. Saved a patient.', 9.8, 'Drager Evita V300 Ventilator', 3, 'spot_bonus',      2500, now() - interval '1 day',  'founder@equipseva.in', 'Third code-red call this quarter'),
    (v_eng_a, v_hosp_b, now() - interval '6 days',  'inapp_review',  'expertise',       'Diagnosed an obscure CT calibration drift no one else caught.',                   9.5, 'Siemens Somatom CT',          2, 'monthly_award',   1500, NULL,                       NULL,                   'Recommended for monthly award'),
    (v_eng_b, v_hosp_a, now() - interval '9 days',  'whatsapp',      'extra_mile',      'Stayed past 11pm to finish ICU monitor install before morning rounds.',           9.7, 'Philips IntelliVue MX450',    1, 'spot_bonus',      2000, now() - interval '3 days', 'founder@equipseva.in', NULL),
    (v_eng_b, v_hosp_c, now() - interval '20 days', 'email',         'professionalism', 'Sent daily status emails with photos and ETAs. Best vendor experience yet.',      9.2, 'GE LOGIQ E10 Ultrasound',     1, 'none',            0,    NULL,                       NULL,                   NULL),
    (v_eng_c, v_hosp_b, now() - interval '35 days', 'survey',        'repair_quality',  'AMC unit failure dropped from 4 a month to 1. Build quality of repair excellent.',9.4, 'Mindray BeneView T8 Monitor', 4, 'quarterly_award', 5000, NULL,                       NULL,                   'Q-award nomination filed'),
    (v_eng_a, v_hosp_c, now() - interval '70 days', 'in_person',     'empathy',         'Trained the entire biomed team for free after the repair.',                       9.6, 'Drager Babylog VN500',        2, 'annual_award',    10000,NULL,                       NULL,                   'Year-end award track');

  INSERT INTO public.praise_award_ledger_r2438
    (engineer_user_id, award_period_start, award_period_end, total_praise_count, top_kind, total_bonus_rupees, hospitals_count, status, awarded_at, awarded_by_email, ceremony_at, ceremony_notes_md, notes)
  VALUES
    (v_eng_a, (now() - interval '30 days')::date, now()::date,                 3, 'speed',          4000,  2, 'awarded',    now() - interval '2 days', 'founder@equipseva.in', NULL,                            NULL,                                                  'Monthly praise leader'),
    (v_eng_b, (now() - interval '30 days')::date, now()::date,                 2, 'extra_mile',     2000,  2, 'pending',    NULL,                       NULL,                   NULL,                            NULL,                                                  'Awaiting Q-end review'),
    (v_eng_c, (now() - interval '120 days')::date, (now() - interval '30 days')::date, 1, 'repair_quality', 5000, 1, 'celebrated', now() - interval '25 days', 'founder@equipseva.in', now() - interval '20 days',     '## Quarterly Award Ceremony' || E'\n' || '- Trophy + Rs 5000 spot bonus' || E'\n' || '- All-hands shoutout', 'Q3 quarterly award handed out'),
    (v_eng_a, (now() - interval '365 days')::date, (now() - interval '120 days')::date, 1, 'empathy',       10000, 1, 'pending',   NULL,                       NULL,                   NULL,                            NULL,                                                  'Annual award track');
END
$seed$;

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_praise_r2438()
RETURNS TABLE (
  id uuid,
  praise_at timestamptz,
  engineer_user_id uuid,
  engineer_tier text,
  hospital_user_id uuid,
  hospital_email text,
  praise_source text,
  praise_kind text,
  praise_text text,
  csat_score numeric,
  equipment_label text,
  repeated_praise_streak int,
  award_eligibility text,
  bonus_rupees int,
  bonus_paid_at timestamptz,
  bonus_paid_by_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.praise_at,
    e.engineer_user_id,
    eng.cached_highest_tier,
    e.hospital_user_id,
    hp.email,
    e.praise_source,
    e.praise_kind,
    e.praise_text,
    e.csat_score,
    e.equipment_label,
    e.repeated_praise_streak,
    e.award_eligibility,
    e.bonus_rupees,
    e.bonus_paid_at,
    e.bonus_paid_by_email,
    e.notes
  FROM public.engineer_praise_events_r2438 e
  LEFT JOIN public.engineers eng ON eng.id = e.engineer_user_id
  LEFT JOIN public.profiles hp ON hp.id = e.hospital_user_id
  ORDER BY e.praise_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_praise_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_praise_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_ledger_r2438()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_tier text,
  award_period_start date,
  award_period_end date,
  total_praise_count int,
  top_kind text,
  total_bonus_rupees bigint,
  hospitals_count int,
  status text,
  awarded_at timestamptz,
  awarded_by_email text,
  ceremony_at timestamptz,
  ceremony_notes_md text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    l.engineer_user_id,
    eng.cached_highest_tier,
    l.award_period_start,
    l.award_period_end,
    l.total_praise_count,
    l.top_kind,
    l.total_bonus_rupees,
    l.hospitals_count,
    l.status,
    l.awarded_at,
    l.awarded_by_email,
    l.ceremony_at,
    l.ceremony_notes_md,
    l.notes
  FROM public.praise_award_ledger_r2438 l
  LEFT JOIN public.engineers eng ON eng.id = l.engineer_user_id
  ORDER BY l.award_period_end DESC, l.status;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_ledger_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ledger_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_praise_engineers_r2438()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_tier text,
  praise_events bigint,
  avg_csat numeric,
  total_bonus_rupees bigint,
  distinct_hospitals bigint,
  last_praise_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    MAX(eng.cached_highest_tier) AS engineer_tier,
    COUNT(*)::bigint AS praise_events,
    ROUND(AVG(e.csat_score)::numeric, 2) AS avg_csat,
    SUM(e.bonus_rupees)::bigint AS total_bonus_rupees,
    COUNT(DISTINCT e.hospital_user_id)::bigint AS distinct_hospitals,
    MAX(e.praise_at) AS last_praise_at
  FROM public.engineer_praise_events_r2438 e
  LEFT JOIN public.engineers eng ON eng.id = e.engineer_user_id
  GROUP BY e.engineer_user_id
  ORDER BY praise_events DESC, avg_csat DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_praise_engineers_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_praise_engineers_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.kind_breakdown_r2438()
RETURNS TABLE (
  praise_kind text,
  praise_events bigint,
  avg_csat numeric,
  total_bonus_rupees bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.engineer_praise_events_r2438;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT
    e.praise_kind,
    COUNT(*)::bigint AS praise_events,
    ROUND(AVG(e.csat_score)::numeric, 2) AS avg_csat,
    SUM(e.bonus_rupees)::bigint AS total_bonus_rupees,
    ROUND((COUNT(*)::numeric / v_total::numeric) * 100.0, 1) AS pct
  FROM public.engineer_praise_events_r2438 e
  GROUP BY e.praise_kind
  ORDER BY praise_events DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.source_breakdown_r2438()
RETURNS TABLE (
  praise_source text,
  praise_events bigint,
  avg_csat numeric,
  total_bonus_rupees bigint,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.engineer_praise_events_r2438;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT
    e.praise_source,
    COUNT(*)::bigint AS praise_events,
    ROUND(AVG(e.csat_score)::numeric, 2) AS avg_csat,
    SUM(e.bonus_rupees)::bigint AS total_bonus_rupees,
    ROUND((COUNT(*)::numeric / v_total::numeric) * 100.0, 1) AS pct
  FROM public.engineer_praise_events_r2438 e
  GROUP BY e.praise_source
  ORDER BY praise_events DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.source_breakdown_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.source_breakdown_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_praise_trend_r2438()
RETURNS TABLE (
  month_start date,
  praise_events bigint,
  avg_csat numeric,
  total_bonus_rupees bigint,
  distinct_engineers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', e.praise_at)::date AS month_start,
    COUNT(*)::bigint AS praise_events,
    ROUND(AVG(e.csat_score)::numeric, 2) AS avg_csat,
    SUM(e.bonus_rupees)::bigint AS total_bonus_rupees,
    COUNT(DISTINCT e.engineer_user_id)::bigint AS distinct_engineers
  FROM public.engineer_praise_events_r2438 e
  GROUP BY date_trunc('month', e.praise_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_praise_trend_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_praise_trend_r2438() TO authenticated;

CREATE OR REPLACE FUNCTION public.eligible_awards_focus_r2438()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_tier text,
  award_eligibility text,
  praise_events bigint,
  unpaid_bonus_rupees bigint,
  last_praise_at timestamptz,
  example_text text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_user_id,
    MAX(eng.cached_highest_tier) AS engineer_tier,
    e.award_eligibility,
    COUNT(*)::bigint AS praise_events,
    SUM(CASE WHEN e.bonus_paid_at IS NULL THEN e.bonus_rupees ELSE 0 END)::bigint AS unpaid_bonus_rupees,
    MAX(e.praise_at) AS last_praise_at,
    (ARRAY_AGG(e.praise_text ORDER BY e.praise_at DESC))[1] AS example_text
  FROM public.engineer_praise_events_r2438 e
  LEFT JOIN public.engineers eng ON eng.id = e.engineer_user_id
  WHERE e.award_eligibility <> 'none'
  GROUP BY e.engineer_user_id, e.award_eligibility
  ORDER BY
    CASE e.award_eligibility
      WHEN 'annual_award' THEN 0
      WHEN 'quarterly_award' THEN 1
      WHEN 'monthly_award' THEN 2
      WHEN 'spot_bonus' THEN 3
      ELSE 4
    END,
    unpaid_bonus_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.eligible_awards_focus_r2438() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eligible_awards_focus_r2438() TO authenticated;

