BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_disputes_r2363 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL,
  chain_name text NOT NULL,
  hospital_branch text NOT NULL,
  dispute_ref text NOT NULL,
  dispute_type text NOT NULL CHECK (dispute_type IN ('billing','sla','quality','warranty','parts','scope','other')),
  job_ref text,
  amount_disputed_rupees numeric(14,2) NOT NULL DEFAULT 0,
  opened_at timestamptz NOT NULL DEFAULT now(),
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_review','escalated','resolved','withdrawn')),
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  assigned_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_dispute_events_r2363 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES public.hospital_chain_disputes_r2363(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('opened','note','escalated','assigned','resolved','withdrawn','reminder')),
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcd_r2363_chain ON public.hospital_chain_disputes_r2363(chain_id);
CREATE INDEX IF NOT EXISTS idx_hcd_r2363_status ON public.hospital_chain_disputes_r2363(status);
CREATE INDEX IF NOT EXISTS idx_hcd_r2363_opened ON public.hospital_chain_disputes_r2363(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_hcde_r2363_dispute ON public.hospital_chain_dispute_events_r2363(dispute_id);
CREATE INDEX IF NOT EXISTS idx_hcde_r2363_occurred ON public.hospital_chain_dispute_events_r2363(occurred_at DESC);

ALTER TABLE public.hospital_chain_disputes_r2363 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_dispute_events_r2363 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_disputes_r2363;
CREATE POLICY founder_all ON public.hospital_chain_disputes_r2363
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_chain_dispute_events_r2363;
CREATE POLICY founder_all ON public.hospital_chain_dispute_events_r2363
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: per-chain rollup with age buckets
CREATE OR REPLACE FUNCTION public.r2363_chain_rollup()
RETURNS TABLE(
  chain_id uuid,
  chain_name text,
  open_count bigint,
  in_review_count bigint,
  escalated_count bigint,
  total_amount_rupees numeric,
  bucket_0_7 bigint,
  bucket_8_30 bigint,
  bucket_31_60 bigint,
  bucket_61_plus bigint,
  oldest_open_days numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.chain_id,
    d.chain_name,
    count(*) FILTER (WHERE d.status = 'open')::bigint,
    count(*) FILTER (WHERE d.status = 'in_review')::bigint,
    count(*) FILTER (WHERE d.status = 'escalated')::bigint,
    coalesce(sum(d.amount_disputed_rupees) FILTER (WHERE d.status IN ('open','in_review','escalated')),0)::numeric,
    count(*) FILTER (WHERE d.status IN ('open','in_review','escalated') AND extract(epoch FROM (now() - d.opened_at))/86400 <= 7)::bigint,
    count(*) FILTER (WHERE d.status IN ('open','in_review','escalated') AND extract(epoch FROM (now() - d.opened_at))/86400 > 7 AND extract(epoch FROM (now() - d.opened_at))/86400 <= 30)::bigint,
    count(*) FILTER (WHERE d.status IN ('open','in_review','escalated') AND extract(epoch FROM (now() - d.opened_at))/86400 > 30 AND extract(epoch FROM (now() - d.opened_at))/86400 <= 60)::bigint,
    count(*) FILTER (WHERE d.status IN ('open','in_review','escalated') AND extract(epoch FROM (now() - d.opened_at))/86400 > 60)::bigint,
    coalesce(max(extract(epoch FROM (now() - d.opened_at))/86400) FILTER (WHERE d.status IN ('open','in_review','escalated')),0)::numeric
  FROM public.hospital_chain_disputes_r2363 d
  GROUP BY d.chain_id, d.chain_name
  ORDER BY count(*) FILTER (WHERE d.status IN ('open','in_review','escalated')) DESC;
END$$;

-- RPC 2: age bucket summary across all chains
CREATE OR REPLACE FUNCTION public.r2363_age_buckets()
RETURNS TABLE(bucket text, dispute_count bigint, total_amount_rupees numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH b AS (
    SELECT
      CASE
        WHEN extract(epoch FROM (now() - opened_at))/86400 <= 7 THEN '0-7 days'
        WHEN extract(epoch FROM (now() - opened_at))/86400 <= 30 THEN '8-30 days'
        WHEN extract(epoch FROM (now() - opened_at))/86400 <= 60 THEN '31-60 days'
        ELSE '61+ days'
      END AS b,
      amount_disputed_rupees
    FROM public.hospital_chain_disputes_r2363
    WHERE status IN ('open','in_review','escalated')
  )
  SELECT b.b, count(*)::bigint, coalesce(sum(b.amount_disputed_rupees),0)::numeric
  FROM b GROUP BY b.b ORDER BY b.b;
END$$;

-- RPC 3: escalation hot list
CREATE OR REPLACE FUNCTION public.r2363_escalation_hot_list()
RETURNS TABLE(
  id uuid,
  chain_name text,
  hospital_branch text,
  dispute_ref text,
  dispute_type text,
  amount_disputed_rupees numeric,
  age_days numeric,
  severity text,
  status text,
  last_activity_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id, d.chain_name, d.hospital_branch, d.dispute_ref, d.dispute_type,
    d.amount_disputed_rupees,
    (extract(epoch FROM (now() - d.opened_at))/86400)::numeric AS age_days,
    d.severity, d.status, d.last_activity_at
  FROM public.hospital_chain_disputes_r2363 d
  WHERE d.status IN ('open','in_review','escalated')
    AND (d.severity IN ('p0','p1')
         OR extract(epoch FROM (now() - d.opened_at))/86400 > 30)
  ORDER BY
    CASE d.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    d.opened_at ASC
  LIMIT 50;
END$$;

-- RPC 4: resolution timeline (last 90d resolutions)
CREATE OR REPLACE FUNCTION public.r2363_resolution_timeline()
RETURNS TABLE(
  resolved_date date,
  resolved_count bigint,
  avg_age_days numeric,
  total_amount_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH res AS (
    SELECT
      (e.occurred_at AT TIME ZONE 'Asia/Kolkata')::date AS resolved_date,
      extract(epoch FROM (e.occurred_at - d.opened_at))/86400 AS age_days,
      d.amount_disputed_rupees
    FROM public.hospital_chain_dispute_events_r2363 e
    JOIN public.hospital_chain_disputes_r2363 d ON d.id = e.dispute_id
    WHERE e.event_type = 'resolved'
      AND e.occurred_at >= now() - interval '90 days'
  )
  SELECT res.resolved_date,
         count(*)::bigint,
         coalesce(avg(res.age_days),0)::numeric,
         coalesce(sum(res.amount_disputed_rupees),0)::numeric
  FROM res
  GROUP BY res.resolved_date
  ORDER BY res.resolved_date DESC;
END$$;

-- RPC 5: dispute type mix
CREATE OR REPLACE FUNCTION public.r2363_type_mix()
RETURNS TABLE(dispute_type text, open_count bigint, total_amount_rupees numeric, avg_age_days numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.dispute_type,
         count(*)::bigint,
         coalesce(sum(d.amount_disputed_rupees),0)::numeric,
         coalesce(avg(extract(epoch FROM (now() - d.opened_at))/86400),0)::numeric
  FROM public.hospital_chain_disputes_r2363 d
  WHERE d.status IN ('open','in_review','escalated')
  GROUP BY d.dispute_type
  ORDER BY count(*) DESC;
END$$;

-- RPC 6: recent activity feed
CREATE OR REPLACE FUNCTION public.r2363_recent_activity()
RETURNS TABLE(
  event_id uuid,
  dispute_id uuid,
  chain_name text,
  dispute_ref text,
  event_type text,
  actor_email text,
  occurred_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.dispute_id, d.chain_name, d.dispute_ref, e.event_type, e.actor_email, e.occurred_at
  FROM public.hospital_chain_dispute_events_r2363 e
  JOIN public.hospital_chain_disputes_r2363 d ON d.id = e.dispute_id
  ORDER BY e.occurred_at DESC
  LIMIT 50;
END$$;

-- RPC 7: dashboard KPIs
CREATE OR REPLACE FUNCTION public.r2363_dashboard_kpis()
RETURNS TABLE(
  total_open bigint,
  total_escalated bigint,
  total_amount_open_rupees numeric,
  avg_open_age_days numeric,
  resolved_last_30d bigint,
  avg_resolution_days_30d numeric,
  chains_with_open bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH open_d AS (
    SELECT * FROM public.hospital_chain_disputes_r2363
    WHERE status IN ('open','in_review','escalated')
  ),
  res_d AS (
    SELECT extract(epoch FROM (e.occurred_at - d.opened_at))/86400 AS age_days
    FROM public.hospital_chain_dispute_events_r2363 e
    JOIN public.hospital_chain_disputes_r2363 d ON d.id = e.dispute_id
    WHERE e.event_type = 'resolved'
      AND e.occurred_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*) FROM open_d)::bigint,
    (SELECT count(*) FROM open_d WHERE status = 'escalated')::bigint,
    (SELECT coalesce(sum(amount_disputed_rupees),0) FROM open_d)::numeric,
    (SELECT coalesce(avg(extract(epoch FROM (now() - opened_at))/86400),0) FROM open_d)::numeric,
    (SELECT count(*) FROM res_d)::bigint,
    (SELECT coalesce(avg(age_days),0) FROM res_d)::numeric,
    (SELECT count(DISTINCT chain_id) FROM open_d)::bigint;
END$$;

REVOKE ALL ON FUNCTION public.r2363_chain_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_age_buckets() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_escalation_hot_list() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_resolution_timeline() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_type_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_recent_activity() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2363_dashboard_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2363_chain_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_age_buckets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_escalation_hot_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_resolution_timeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_type_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_recent_activity() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2363_dashboard_kpis() TO authenticated;

COMMIT;
