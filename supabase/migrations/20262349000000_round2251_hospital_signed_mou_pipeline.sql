BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_mou_pipeline_r2251 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_name text NOT NULL,
  city text NOT NULL,
  stage text NOT NULL CHECK (stage IN ('loi','mou','po','signed','lost')),
  deal_value_rupees bigint NOT NULL CHECK (deal_value_rupees >= 0),
  stage_entered_at timestamptz NOT NULL DEFAULT now(),
  close_confidence_pct int NOT NULL CHECK (close_confidence_pct BETWEEN 0 AND 100),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  expected_close_date date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_mou_stage_events_r2251 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.hospital_mou_pipeline_r2251(id) ON DELETE CASCADE,
  from_stage text CHECK (from_stage IN ('loi','mou','po','signed','lost')),
  to_stage text NOT NULL CHECK (to_stage IN ('loi','mou','po','signed','lost')),
  moved_at timestamptz NOT NULL DEFAULT now(),
  moved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  note text
);

ALTER TABLE public.hospital_mou_pipeline_r2251 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_mou_stage_events_r2251 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_mou_pipeline_r2251;
CREATE POLICY founder_all ON public.hospital_mou_pipeline_r2251
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_mou_stage_events_r2251;
CREATE POLICY founder_all ON public.hospital_mou_stage_events_r2251
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

INSERT INTO public.hospital_mou_pipeline_r2251 (hospital_name, city, stage, deal_value_rupees, stage_entered_at, close_confidence_pct, expected_close_date, notes)
VALUES
  ('Apollo Specialty Madurai','Madurai','po', 4800000, now() - interval '8 days', 85, (now() + interval '14 days')::date, 'PO drafted, awaiting hospital legal sign-off'),
  ('Yashoda Hospitals Secunderabad','Hyderabad','mou', 9200000, now() - interval '21 days', 65, (now() + interval '30 days')::date, 'MOU under finance review'),
  ('Manipal Hospital Whitefield','Bangalore','signed', 6700000, now() - interval '3 days', 100, (now() + interval '7 days')::date, 'Signed; awaiting first invoice'),
  ('Care Hospitals Banjara Hills','Hyderabad','loi', 3100000, now() - interval '40 days', 35, (now() + interval '60 days')::date, 'LOI stalling — procurement re-org'),
  ('Fortis Anandapur','Kolkata','mou', 5400000, now() - interval '12 days', 55, (now() + interval '21 days')::date, 'MOU drafted by Equipseva legal'),
  ('KIMS Kondapur','Hyderabad','po', 2800000, now() - interval '5 days', 80, (now() + interval '10 days')::date, 'PO release expected this week'),
  ('Rainbow Childrens Hospital','Hyderabad','lost', 1900000, now() - interval '15 days', 0, NULL, 'Lost to in-house biomed team'),
  ('AIG Hospitals Gachibowli','Hyderabad','mou', 11500000, now() - interval '55 days', 40, (now() + interval '45 days')::date, 'Stuck in legal — escalate'),
  ('Sunshine Hospital Paradise','Hyderabad','loi', 2200000, now() - interval '6 days', 50, (now() + interval '40 days')::date, 'Initial LOI floated'),
  ('Continental Hospitals','Hyderabad','signed', 8800000, now() - interval '1 days', 100, (now() + interval '3 days')::date, 'Signed yesterday — onboarding scheduled');

INSERT INTO public.hospital_mou_stage_events_r2251 (pipeline_id, from_stage, to_stage, moved_at, note)
SELECT id, 'loi', 'mou', stage_entered_at - interval '7 days', 'Moved LOI to MOU'
FROM public.hospital_mou_pipeline_r2251
WHERE stage IN ('mou','po','signed') LIMIT 5;

CREATE OR REPLACE FUNCTION public.r2251_pipeline_summary()
RETURNS TABLE (total_deals int, total_value_rupees bigint, active_deals int, signed_deals int, lost_deals int, avg_confidence numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(deal_value_rupees),0)::bigint,
    (COUNT(*) FILTER (WHERE stage IN ('loi','mou','po')))::int,
    (COUNT(*) FILTER (WHERE stage = 'signed'))::int,
    (COUNT(*) FILTER (WHERE stage = 'lost'))::int,
    ROUND(AVG(close_confidence_pct)::numeric, 1)
  FROM public.hospital_mou_pipeline_r2251;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_pipeline_by_stage()
RETURNS TABLE (stage text, deal_count int, total_value_rupees bigint, avg_weeks_in_stage numeric, avg_confidence numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.stage,
    COUNT(*)::int,
    COALESCE(SUM(p.deal_value_rupees),0)::bigint,
    ROUND(AVG(EXTRACT(EPOCH FROM (now() - p.stage_entered_at)) / 604800.0)::numeric, 1),
    ROUND(AVG(p.close_confidence_pct)::numeric, 1)
  FROM public.hospital_mou_pipeline_r2251 p
  GROUP BY p.stage
  ORDER BY p.stage;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_all_deals()
RETURNS TABLE (id uuid, hospital_name text, city text, stage text, deal_value_rupees bigint, weeks_in_stage numeric, close_confidence_pct int, expected_close_date date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.hospital_name, p.city, p.stage, p.deal_value_rupees,
    ROUND((EXTRACT(EPOCH FROM (now() - p.stage_entered_at)) / 604800.0)::numeric, 1),
    p.close_confidence_pct, p.expected_close_date
  FROM public.hospital_mou_pipeline_r2251 p
  ORDER BY p.deal_value_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_stuck_deals()
RETURNS TABLE (id uuid, hospital_name text, stage text, weeks_in_stage numeric, deal_value_rupees bigint, close_confidence_pct int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.hospital_name, p.stage,
    ROUND((EXTRACT(EPOCH FROM (now() - p.stage_entered_at)) / 604800.0)::numeric, 1),
    p.deal_value_rupees, p.close_confidence_pct
  FROM public.hospital_mou_pipeline_r2251 p
  WHERE p.stage IN ('loi','mou','po')
    AND (now() - p.stage_entered_at) > interval '21 days'
  ORDER BY (now() - p.stage_entered_at) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_high_confidence()
RETURNS TABLE (id uuid, hospital_name text, stage text, deal_value_rupees bigint, close_confidence_pct int, expected_close_date date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.hospital_name, p.stage, p.deal_value_rupees, p.close_confidence_pct, p.expected_close_date
  FROM public.hospital_mou_pipeline_r2251 p
  WHERE p.close_confidence_pct >= 70
    AND p.stage IN ('loi','mou','po')
  ORDER BY p.close_confidence_pct DESC, p.deal_value_rupees DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_by_city()
RETURNS TABLE (city text, deal_count int, total_value_rupees bigint, signed_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.city,
    COUNT(*)::int,
    COALESCE(SUM(p.deal_value_rupees),0)::bigint,
    (COUNT(*) FILTER (WHERE p.stage = 'signed'))::int
  FROM public.hospital_mou_pipeline_r2251 p
  GROUP BY p.city
  ORDER BY COALESCE(SUM(p.deal_value_rupees),0) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2251_weighted_pipeline()
RETURNS TABLE (stage text, weighted_value_rupees bigint, raw_value_rupees bigint, deal_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.stage,
    COALESCE(SUM((p.deal_value_rupees * p.close_confidence_pct) / 100),0)::bigint,
    COALESCE(SUM(p.deal_value_rupees),0)::bigint,
    COUNT(*)::int
  FROM public.hospital_mou_pipeline_r2251 p
  WHERE p.stage IN ('loi','mou','po')
  GROUP BY p.stage
  ORDER BY p.stage;
END $$;

REVOKE ALL ON FUNCTION public.r2251_pipeline_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_pipeline_by_stage() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_all_deals() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_stuck_deals() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_high_confidence() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_by_city() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2251_weighted_pipeline() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2251_pipeline_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_pipeline_by_stage() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_all_deals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_stuck_deals() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_high_confidence() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_by_city() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2251_weighted_pipeline() TO authenticated;

COMMIT;
