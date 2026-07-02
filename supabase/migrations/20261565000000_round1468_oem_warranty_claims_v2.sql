BEGIN;

-- =====================================================================
-- r1468 — OEM warranty claims tracker (v2 tables, no collisions)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.oem_warranty_claims_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oem_name text NOT NULL,
  equipment_serial text,
  organization_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  claim_reference text,
  failure_summary text NOT NULL,
  claimed_amount_rupees integer NOT NULL DEFAULT 0 CHECK (claimed_amount_rupees >= 0),
  recovered_amount_rupees integer NOT NULL DEFAULT 0 CHECK (recovered_amount_rupees >= 0),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','submitted','acknowledged','under_review','approved','partially_approved','rejected','recovered','closed')),
  submitted_at timestamptz,
  acknowledged_at timestamptz,
  approved_at timestamptz,
  recovered_at timestamptz,
  closed_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oem_warranty_claims_v2_oem ON public.oem_warranty_claims_v2(oem_name);
CREATE INDEX IF NOT EXISTS idx_oem_warranty_claims_v2_status ON public.oem_warranty_claims_v2(status);
CREATE INDEX IF NOT EXISTS idx_oem_warranty_claims_v2_created ON public.oem_warranty_claims_v2(created_at DESC);

ALTER TABLE public.oem_warranty_claims_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS oem_warranty_claims_v2_no_anon ON public.oem_warranty_claims_v2;
CREATE POLICY oem_warranty_claims_v2_no_anon ON public.oem_warranty_claims_v2 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.oem_warranty_claim_events_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.oem_warranty_claims_v2(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  from_status text,
  to_status text,
  amount_delta_rupees integer,
  note text,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oem_warranty_claim_events_v2_claim ON public.oem_warranty_claim_events_v2(claim_id, created_at DESC);

ALTER TABLE public.oem_warranty_claim_events_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS oem_warranty_claim_events_v2_no_anon ON public.oem_warranty_claim_events_v2;
CREATE POLICY oem_warranty_claim_events_v2_no_anon ON public.oem_warranty_claim_events_v2 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- READ RPCs (SECDEF STABLE, is_founder gated)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_overview_v2()
RETURNS TABLE (
  total_claims bigint,
  open_claims bigint,
  closed_claims bigint,
  total_claimed_rupees bigint,
  total_recovered_rupees bigint,
  recovery_pct numeric,
  approved_count bigint,
  rejected_count bigint,
  unique_oems bigint,
  avg_claim_rupees numeric,
  median_days_to_close numeric,
  pending_review bigint,
  recovered_last_30d bigint,
  recovered_amount_30d bigint,
  largest_open_claim bigint,
  oldest_open_age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.oem_warranty_claims_v2
  )
  SELECT
    COUNT(*)::bigint AS total_claims,
    COUNT(*) FILTER (WHERE status NOT IN ('closed','rejected'))::bigint AS open_claims,
    COUNT(*) FILTER (WHERE status IN ('closed','rejected'))::bigint AS closed_claims,
    COALESCE(SUM(claimed_amount_rupees),0)::bigint AS total_claimed_rupees,
    COALESCE(SUM(recovered_amount_rupees),0)::bigint AS total_recovered_rupees,
    CASE WHEN COALESCE(SUM(claimed_amount_rupees),0) > 0
         THEN ROUND(100.0 * SUM(recovered_amount_rupees)::numeric / SUM(claimed_amount_rupees)::numeric, 2)
         ELSE 0 END AS recovery_pct,
    COUNT(*) FILTER (WHERE status IN ('approved','partially_approved','recovered'))::bigint AS approved_count,
    COUNT(*) FILTER (WHERE status = 'rejected')::bigint AS rejected_count,
    COUNT(DISTINCT oem_name)::bigint AS unique_oems,
    ROUND(COALESCE(AVG(claimed_amount_rupees),0)::numeric, 2) AS avg_claim_rupees,
    ROUND(COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (closed_at - created_at))/86400.0) FILTER (WHERE closed_at IS NOT NULL),0)::numeric, 2) AS median_days_to_close,
    COUNT(*) FILTER (WHERE status IN ('submitted','acknowledged','under_review'))::bigint AS pending_review,
    COUNT(*) FILTER (WHERE recovered_at >= now() - interval '30 days')::bigint AS recovered_last_30d,
    COALESCE(SUM(recovered_amount_rupees) FILTER (WHERE recovered_at >= now() - interval '30 days'),0)::bigint AS recovered_amount_30d,
    COALESCE(MAX(claimed_amount_rupees) FILTER (WHERE status NOT IN ('closed','rejected')),0)::bigint AS largest_open_claim,
    COALESCE(ROUND(EXTRACT(EPOCH FROM (now() - MIN(created_at) FILTER (WHERE status NOT IN ('closed','rejected'))))/86400.0, 2),0)::numeric AS oldest_open_age_days
  FROM base;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_overview_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_overview_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_by_oem_v2()
RETURNS TABLE (
  id text,
  oem_name text,
  total_claims bigint,
  open_claims bigint,
  approved bigint,
  rejected bigint,
  claimed_rupees bigint,
  recovered_rupees bigint,
  recovery_pct numeric,
  score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.oem_name AS id,
    c.oem_name,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.status NOT IN ('closed','rejected'))::bigint,
    COUNT(*) FILTER (WHERE c.status IN ('approved','partially_approved','recovered'))::bigint,
    COUNT(*) FILTER (WHERE c.status = 'rejected')::bigint,
    COALESCE(SUM(c.claimed_amount_rupees),0)::bigint,
    COALESCE(SUM(c.recovered_amount_rupees),0)::bigint,
    CASE WHEN COALESCE(SUM(c.claimed_amount_rupees),0) > 0
         THEN ROUND(100.0 * SUM(c.recovered_amount_rupees)::numeric / SUM(c.claimed_amount_rupees)::numeric, 2)
         ELSE 0 END,
    ROUND(
      (CASE WHEN COALESCE(SUM(c.claimed_amount_rupees),0) > 0
            THEN 100.0 * SUM(c.recovered_amount_rupees)::numeric / SUM(c.claimed_amount_rupees)::numeric
            ELSE 0 END) * 0.7
      + (COUNT(*) FILTER (WHERE c.status IN ('approved','partially_approved','recovered'))::numeric / NULLIF(COUNT(*),0) * 100) * 0.3
    , 2)
  FROM public.oem_warranty_claims_v2 c
  GROUP BY c.oem_name
  ORDER BY 10 DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_by_oem_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_by_oem_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_by_status_v2()
RETURNS TABLE (
  id text,
  status text,
  claim_count bigint,
  claimed_rupees bigint,
  recovered_rupees bigint,
  avg_age_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.status AS id,
    c.status,
    COUNT(*)::bigint,
    COALESCE(SUM(c.claimed_amount_rupees),0)::bigint,
    COALESCE(SUM(c.recovered_amount_rupees),0)::bigint,
    ROUND(COALESCE(AVG(EXTRACT(EPOCH FROM (now() - c.created_at))/86400.0),0)::numeric, 2)
  FROM public.oem_warranty_claims_v2 c
  GROUP BY c.status
  ORDER BY 3 DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_by_status_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_by_status_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_recent_claims_v2()
RETURNS TABLE (
  id uuid,
  oem_name text,
  status text,
  claimed_amount_rupees integer,
  recovered_amount_rupees integer,
  failure_summary text,
  claim_reference text,
  age_days numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.oem_name,
    c.status,
    c.claimed_amount_rupees,
    c.recovered_amount_rupees,
    c.failure_summary,
    c.claim_reference,
    ROUND(EXTRACT(EPOCH FROM (now() - c.created_at))/86400.0, 2)::numeric,
    c.created_at
  FROM public.oem_warranty_claims_v2 c
  ORDER BY c.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_recent_claims_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_recent_claims_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_stale_open_v2()
RETURNS TABLE (
  id uuid,
  oem_name text,
  status text,
  claimed_amount_rupees integer,
  age_days numeric,
  last_event text,
  claim_reference text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.oem_name,
    c.status,
    c.claimed_amount_rupees,
    ROUND(EXTRACT(EPOCH FROM (now() - c.created_at))/86400.0, 2)::numeric,
    (SELECT e.event_type FROM public.oem_warranty_claim_events_v2 e WHERE e.claim_id = c.id ORDER BY e.created_at DESC LIMIT 1),
    c.claim_reference
  FROM public.oem_warranty_claims_v2 c
  WHERE c.status NOT IN ('closed','rejected')
    AND c.created_at < now() - interval '14 days'
  ORDER BY c.created_at ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_stale_open_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_stale_open_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_recovery_trend_v2()
RETURNS TABLE (
  id text,
  week_start date,
  claim_count bigint,
  claimed_rupees bigint,
  recovered_rupees bigint,
  recovery_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('week', c.created_at), 'YYYY-MM-DD') AS id,
    date_trunc('week', c.created_at)::date,
    COUNT(*)::bigint,
    COALESCE(SUM(c.claimed_amount_rupees),0)::bigint,
    COALESCE(SUM(c.recovered_amount_rupees),0)::bigint,
    CASE WHEN COALESCE(SUM(c.claimed_amount_rupees),0) > 0
         THEN ROUND(100.0 * SUM(c.recovered_amount_rupees)::numeric / SUM(c.claimed_amount_rupees)::numeric, 2)
         ELSE 0 END
  FROM public.oem_warranty_claims_v2 c
  WHERE c.created_at >= now() - interval '12 weeks'
  GROUP BY date_trunc('week', c.created_at)
  ORDER BY 2 DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_recovery_trend_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_recovery_trend_v2() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_oem_warranty_top_recoveries_v2()
RETURNS TABLE (
  id uuid,
  oem_name text,
  recovered_amount_rupees integer,
  claimed_amount_rupees integer,
  recovery_pct numeric,
  recovered_at timestamptz,
  failure_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.oem_name,
    c.recovered_amount_rupees,
    c.claimed_amount_rupees,
    CASE WHEN c.claimed_amount_rupees > 0
         THEN ROUND(100.0 * c.recovered_amount_rupees::numeric / c.claimed_amount_rupees::numeric, 2)
         ELSE 0 END,
    c.recovered_at,
    c.failure_summary
  FROM public.oem_warranty_claims_v2 c
  WHERE c.recovered_amount_rupees > 0
  ORDER BY c.recovered_amount_rupees DESC
  LIMIT 25;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_oem_warranty_top_recoveries_v2() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_oem_warranty_top_recoveries_v2() TO authenticated;

-- =====================================================================
-- WRITE / LOG helpers (VOLATILE SECDEF, is_founder gated)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.log_founder_oem_warranty_claim_create_v2(
  p_oem_name text,
  p_failure_summary text,
  p_claimed_amount_rupees integer,
  p_claim_reference text DEFAULT NULL,
  p_organization_id uuid DEFAULT NULL,
  p_repair_job_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.oem_warranty_claims_v2(oem_name, failure_summary, claimed_amount_rupees, claim_reference, organization_id, repair_job_id, notes, created_by)
  VALUES (p_oem_name, p_failure_summary, COALESCE(p_claimed_amount_rupees,0), p_claim_reference, p_organization_id, p_repair_job_id, p_notes, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.oem_warranty_claim_events_v2(claim_id, event_type, to_status, note, actor_id)
  VALUES (v_id, 'created', 'draft', p_notes, auth.uid());
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_oem_warranty_claim_create_v2(text,text,integer,text,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_oem_warranty_claim_create_v2(text,text,integer,text,uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_oem_warranty_advance_status_v2(
  p_claim_id uuid,
  p_to_status text,
  p_note text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_to_status NOT IN ('draft','submitted','acknowledged','under_review','approved','partially_approved','rejected','recovered','closed') THEN
    RAISE EXCEPTION 'invalid status: %', p_to_status;
  END IF;
  SELECT status INTO v_from FROM public.oem_warranty_claims_v2 WHERE id = p_claim_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'claim not found'; END IF;
  UPDATE public.oem_warranty_claims_v2
  SET status = p_to_status,
      submitted_at    = CASE WHEN p_to_status = 'submitted'     AND submitted_at    IS NULL THEN now() ELSE submitted_at END,
      acknowledged_at = CASE WHEN p_to_status = 'acknowledged'  AND acknowledged_at IS NULL THEN now() ELSE acknowledged_at END,
      approved_at     = CASE WHEN p_to_status IN ('approved','partially_approved') AND approved_at IS NULL THEN now() ELSE approved_at END,
      closed_at       = CASE WHEN p_to_status IN ('closed','rejected') AND closed_at IS NULL THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_claim_id;
  INSERT INTO public.oem_warranty_claim_events_v2(claim_id, event_type, from_status, to_status, note, actor_id)
  VALUES (p_claim_id, 'status_change', v_from, p_to_status, p_note, auth.uid());
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_oem_warranty_advance_status_v2(uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_oem_warranty_advance_status_v2(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_oem_warranty_record_recovery_v2(
  p_claim_id uuid,
  p_recovered_amount_rupees integer,
  p_note text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_recovered_amount_rupees < 0 THEN RAISE EXCEPTION 'negative recovery'; END IF;
  UPDATE public.oem_warranty_claims_v2
  SET recovered_amount_rupees = recovered_amount_rupees + p_recovered_amount_rupees,
      recovered_at = now(),
      status = CASE WHEN recovered_amount_rupees + p_recovered_amount_rupees >= claimed_amount_rupees THEN 'recovered' ELSE status END,
      updated_at = now()
  WHERE id = p_claim_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'claim not found'; END IF;
  INSERT INTO public.oem_warranty_claim_events_v2(claim_id, event_type, amount_delta_rupees, note, actor_id)
  VALUES (p_claim_id, 'recovery_recorded', p_recovered_amount_rupees, p_note, auth.uid());
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_oem_warranty_record_recovery_v2(uuid,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_oem_warranty_record_recovery_v2(uuid,integer,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_oem_warranty_add_note_v2(
  p_claim_id uuid,
  p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_note IS NULL OR length(trim(p_note)) = 0 THEN RAISE EXCEPTION 'note required'; END IF;
  INSERT INTO public.oem_warranty_claim_events_v2(claim_id, event_type, note, actor_id)
  VALUES (p_claim_id, 'note_added', p_note, auth.uid());
  UPDATE public.oem_warranty_claims_v2 SET updated_at = now() WHERE id = p_claim_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_oem_warranty_add_note_v2(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_oem_warranty_add_note_v2(uuid,text) TO authenticated;

COMMIT;