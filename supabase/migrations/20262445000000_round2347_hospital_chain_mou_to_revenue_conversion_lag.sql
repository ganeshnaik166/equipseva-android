BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_mou_revenue_lag_r2347 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_count int NOT NULL CHECK (hospital_count > 0),
  region text NOT NULL,
  mou_signed_at timestamptz NOT NULL,
  first_revenue_at timestamptz,
  first_revenue_amount_rupees bigint CHECK (first_revenue_amount_rupees >= 0),
  mou_value_rupees bigint NOT NULL CHECK (mou_value_rupees >= 0),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL CHECK (status IN ('signed_no_revenue','first_revenue_received','churned_pre_revenue')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_mou_lag_events_r2347 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lag_id uuid NOT NULL REFERENCES public.hospital_chain_mou_revenue_lag_r2347(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('kickoff_call','site_survey','equipment_audit','first_quote','first_po','first_invoice','first_payment','escalation','blocker')),
  event_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  note text
);

ALTER TABLE public.hospital_chain_mou_revenue_lag_r2347 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_mou_lag_events_r2347 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_mou_revenue_lag_r2347;
CREATE POLICY founder_all ON public.hospital_chain_mou_revenue_lag_r2347
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_mou_lag_events_r2347;
CREATE POLICY founder_all ON public.hospital_chain_mou_lag_events_r2347
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

INSERT INTO public.hospital_chain_mou_revenue_lag_r2347
  (chain_name, hospital_count, region, mou_signed_at, first_revenue_at, first_revenue_amount_rupees, mou_value_rupees, status, notes)
VALUES
  ('Apollo Hospitals', 14, 'South', now() - interval '95 days', now() - interval '74 days', 280000, 18000000, 'first_revenue_received', 'Fast onboarding — Chennai pilot site'),
  ('Manipal Hospitals', 9, 'South', now() - interval '120 days', now() - interval '88 days', 410000, 14500000, 'first_revenue_received', 'Whitefield first revenue'),
  ('Fortis Healthcare', 8, 'North', now() - interval '160 days', now() - interval '40 days', 195000, 22000000, 'first_revenue_received', 'Delay due to procurement re-org'),
  ('Yashoda Hospitals', 5, 'South', now() - interval '70 days', NULL, NULL, 9200000, 'signed_no_revenue', 'Stuck at site survey stage'),
  ('AIG Hospitals', 3, 'South', now() - interval '210 days', now() - interval '12 days', 87000, 11500000, 'first_revenue_received', 'Very slow — 198d lag; legal blocker'),
  ('Care Hospitals', 7, 'South', now() - interval '180 days', NULL, NULL, 13400000, 'signed_no_revenue', 'Awaiting equipment audit completion'),
  ('Rainbow Childrens', 4, 'South', now() - interval '240 days', NULL, NULL, 7900000, 'churned_pre_revenue', 'Lost to in-house biomed team'),
  ('KIMS', 6, 'South', now() - interval '55 days', now() - interval '21 days', 320000, 12800000, 'first_revenue_received', 'Kondapur ramped fast'),
  ('Continental Hospitals', 2, 'South', now() - interval '30 days', now() - interval '8 days', 240000, 8800000, 'first_revenue_received', 'Gachibowli onboarding smooth'),
  ('Max Healthcare', 11, 'North', now() - interval '140 days', now() - interval '95 days', 165000, 19500000, 'first_revenue_received', 'Saket and Patparganj live'),
  ('Sunshine Hospitals', 5, 'South', now() - interval '100 days', NULL, NULL, 6200000, 'signed_no_revenue', 'CMO transition delayed kickoff'),
  ('Narayana Health', 12, 'South', now() - interval '270 days', now() - interval '180 days', 520000, 24000000, 'first_revenue_received', 'Long onboarding; multi-site rollout');

INSERT INTO public.hospital_chain_mou_lag_events_r2347 (lag_id, event_type, event_at, note)
SELECT id, 'kickoff_call', mou_signed_at + interval '5 days', 'Initial kickoff call held'
FROM public.hospital_chain_mou_revenue_lag_r2347;

INSERT INTO public.hospital_chain_mou_lag_events_r2347 (lag_id, event_type, event_at, note)
SELECT id, 'site_survey', mou_signed_at + interval '14 days', 'Site survey scheduled'
FROM public.hospital_chain_mou_revenue_lag_r2347 WHERE status != 'churned_pre_revenue';

INSERT INTO public.hospital_chain_mou_lag_events_r2347 (lag_id, event_type, event_at, note)
SELECT id, 'first_invoice', first_revenue_at - interval '4 days', 'First invoice issued'
FROM public.hospital_chain_mou_revenue_lag_r2347 WHERE first_revenue_at IS NOT NULL;

INSERT INTO public.hospital_chain_mou_lag_events_r2347 (lag_id, event_type, event_at, note)
SELECT id, 'escalation', now() - interval '7 days', 'Founder escalation — lag exceeds 90 days'
FROM public.hospital_chain_mou_revenue_lag_r2347
WHERE status = 'signed_no_revenue' AND (now() - mou_signed_at) > interval '90 days';

CREATE OR REPLACE FUNCTION public.r2347_lag_summary()
RETURNS TABLE (
  total_chains int,
  chains_with_revenue int,
  chains_no_revenue int,
  chains_churned int,
  avg_lag_days numeric,
  median_lag_days numeric,
  p90_lag_days numeric,
  total_mou_value_rupees bigint,
  total_first_revenue_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH lags AS (
    SELECT EXTRACT(EPOCH FROM (first_revenue_at - mou_signed_at)) / 86400.0 AS lag_days
    FROM public.hospital_chain_mou_revenue_lag_r2347
    WHERE first_revenue_at IS NOT NULL
  )
  SELECT
    (SELECT COUNT(*) FROM public.hospital_chain_mou_revenue_lag_r2347)::int,
    (SELECT COUNT(*) FROM public.hospital_chain_mou_revenue_lag_r2347 WHERE status = 'first_revenue_received')::int,
    (SELECT COUNT(*) FROM public.hospital_chain_mou_revenue_lag_r2347 WHERE status = 'signed_no_revenue')::int,
    (SELECT COUNT(*) FROM public.hospital_chain_mou_revenue_lag_r2347 WHERE status = 'churned_pre_revenue')::int,
    COALESCE(ROUND(AVG(lag_days)::numeric, 1), 0),
    COALESCE(ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lag_days))::numeric, 1), 0),
    COALESCE(ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY lag_days))::numeric, 1), 0),
    (SELECT COALESCE(SUM(mou_value_rupees), 0)::bigint FROM public.hospital_chain_mou_revenue_lag_r2347),
    (SELECT COALESCE(SUM(first_revenue_amount_rupees), 0)::bigint FROM public.hospital_chain_mou_revenue_lag_r2347)
  FROM lags;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_by_chain()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_count int,
  region text,
  mou_signed_at timestamptz,
  lag_days numeric,
  mou_value_rupees bigint,
  first_revenue_amount_rupees bigint,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.chain_name, p.hospital_count, p.region, p.mou_signed_at,
    CASE WHEN p.first_revenue_at IS NOT NULL
         THEN ROUND((EXTRACT(EPOCH FROM (p.first_revenue_at - p.mou_signed_at)) / 86400.0)::numeric, 1)
         ELSE ROUND((EXTRACT(EPOCH FROM (now() - p.mou_signed_at)) / 86400.0)::numeric, 1)
    END,
    p.mou_value_rupees,
    COALESCE(p.first_revenue_amount_rupees, 0),
    p.status
  FROM public.hospital_chain_mou_revenue_lag_r2347 p
  ORDER BY
    CASE WHEN p.first_revenue_at IS NOT NULL
         THEN EXTRACT(EPOCH FROM (p.first_revenue_at - p.mou_signed_at))
         ELSE EXTRACT(EPOCH FROM (now() - p.mou_signed_at))
    END DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_distribution()
RETURNS TABLE (
  bucket text,
  chain_count int,
  pct_of_revenue_chains numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total
  FROM public.hospital_chain_mou_revenue_lag_r2347
  WHERE first_revenue_at IS NOT NULL;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  WITH lags AS (
    SELECT EXTRACT(EPOCH FROM (first_revenue_at - mou_signed_at)) / 86400.0 AS d
    FROM public.hospital_chain_mou_revenue_lag_r2347
    WHERE first_revenue_at IS NOT NULL
  ),
  buckets AS (
    SELECT
      CASE
        WHEN d <= 30 THEN '0-30d'
        WHEN d <= 60 THEN '31-60d'
        WHEN d <= 90 THEN '61-90d'
        WHEN d <= 180 THEN '91-180d'
        ELSE '180d+'
      END AS bk
    FROM lags
  )
  SELECT
    b.bk,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric * 100.0 / v_total), 1)
  FROM buckets b
  GROUP BY b.bk
  ORDER BY
    CASE b.bk
      WHEN '0-30d' THEN 1
      WHEN '31-60d' THEN 2
      WHEN '61-90d' THEN 3
      WHEN '91-180d' THEN 4
      ELSE 5
    END;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_outliers()
RETURNS TABLE (
  id uuid,
  chain_name text,
  region text,
  lag_days numeric,
  mou_value_rupees bigint,
  status text,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.chain_name, p.region,
    CASE WHEN p.first_revenue_at IS NOT NULL
         THEN ROUND((EXTRACT(EPOCH FROM (p.first_revenue_at - p.mou_signed_at)) / 86400.0)::numeric, 1)
         ELSE ROUND((EXTRACT(EPOCH FROM (now() - p.mou_signed_at)) / 86400.0)::numeric, 1)
    END AS lag,
    p.mou_value_rupees, p.status, p.notes
  FROM public.hospital_chain_mou_revenue_lag_r2347 p
  WHERE (p.first_revenue_at IS NOT NULL AND (p.first_revenue_at - p.mou_signed_at) > interval '120 days')
     OR (p.first_revenue_at IS NULL AND (now() - p.mou_signed_at) > interval '60 days')
  ORDER BY lag DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_by_region()
RETURNS TABLE (
  region text,
  chain_count int,
  avg_lag_days numeric,
  signed_no_revenue int,
  total_mou_value_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.region,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(
      CASE WHEN p.first_revenue_at IS NOT NULL
           THEN EXTRACT(EPOCH FROM (p.first_revenue_at - p.mou_signed_at)) / 86400.0
      END
    )::numeric, 1), 0),
    (COUNT(*) FILTER (WHERE p.status = 'signed_no_revenue'))::int,
    COALESCE(SUM(p.mou_value_rupees), 0)::bigint
  FROM public.hospital_chain_mou_revenue_lag_r2347 p
  GROUP BY p.region
  ORDER BY COALESCE(SUM(p.mou_value_rupees), 0) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_stalled()
RETURNS TABLE (
  id uuid,
  chain_name text,
  region text,
  days_since_mou numeric,
  mou_value_rupees bigint,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.chain_name, p.region,
    ROUND((EXTRACT(EPOCH FROM (now() - p.mou_signed_at)) / 86400.0)::numeric, 1),
    p.mou_value_rupees, p.notes
  FROM public.hospital_chain_mou_revenue_lag_r2347 p
  WHERE p.status = 'signed_no_revenue'
  ORDER BY p.mou_signed_at ASC;
END $$;

CREATE OR REPLACE FUNCTION public.r2347_recent_events()
RETURNS TABLE (
  event_id uuid,
  chain_name text,
  event_type text,
  event_at timestamptz,
  note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id, p.chain_name, e.event_type, e.event_at, e.note
  FROM public.hospital_chain_mou_lag_events_r2347 e
  JOIN public.hospital_chain_mou_revenue_lag_r2347 p ON p.id = e.lag_id
  ORDER BY e.event_at DESC
  LIMIT 30;
END $$;

REVOKE ALL ON FUNCTION public.r2347_lag_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_by_chain() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_distribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_outliers() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_by_region() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_stalled() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2347_recent_events() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2347_lag_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_by_chain() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_outliers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_by_region() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_stalled() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2347_recent_events() TO authenticated;

COMMIT;
