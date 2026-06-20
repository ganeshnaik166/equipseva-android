BEGIN;

-- =====================================================================
-- r1456 — Founder Partnerships Pipeline
-- Track strategic partnerships (OEMs, distributors, hospital chains,
-- financiers) through a 7-stage funnel with commercial terms,
-- expected revenue, and stalled-deal flags.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLE: founder_partnerships_v2
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_partnerships_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_name text NOT NULL,
  partner_type text NOT NULL CHECK (partner_type IN ('oem','distributor','hospital_chain','financier','insurer','government','other')),
  region text,
  primary_contact_name text,
  primary_contact_email text,
  primary_contact_phone text,
  stage text NOT NULL DEFAULT 'sourced' CHECK (stage IN (
    'sourced','qualified','discovery','proposal','negotiation','contract','live'
  )),
  expected_annual_revenue_rupees bigint NOT NULL DEFAULT 0,
  commercial_terms_summary text,
  revenue_share_pct numeric(5,2),
  exclusivity boolean NOT NULL DEFAULT false,
  contract_signed_at timestamptz,
  go_live_target_date date,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  stalled boolean NOT NULL DEFAULT false,
  stalled_reason text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_partnerships_stage ON public.founder_partnerships_v2(stage);
CREATE INDEX IF NOT EXISTS idx_founder_partnerships_type ON public.founder_partnerships_v2(partner_type);
CREATE INDEX IF NOT EXISTS idx_founder_partnerships_stalled ON public.founder_partnerships_v2(stalled) WHERE stalled = true;
CREATE INDEX IF NOT EXISTS idx_founder_partnerships_last_activity ON public.founder_partnerships_v2(last_activity_at DESC);

ALTER TABLE public.founder_partnerships_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_partnerships_no_direct ON public.founder_partnerships_v2;
CREATE POLICY founder_partnerships_no_direct
  ON public.founder_partnerships_v2
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- ---------------------------------------------------------------------
-- TABLE: founder_partnership_v2_events (stage transitions + activity log)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_partnership_v2_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_id uuid NOT NULL REFERENCES public.founder_partnerships_v2(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN (
    'created','stage_moved','terms_updated','stalled_flagged','stalled_cleared','note_added','contract_signed'
  )),
  from_stage text,
  to_stage text,
  note text,
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_partnership_v2_events_partnership ON public.founder_partnership_v2_events(partnership_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_partnership_v2_events_type ON public.founder_partnership_v2_events(event_type, created_at DESC);

ALTER TABLE public.founder_partnership_v2_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_partnership_v2_events_no_direct ON public.founder_partnership_v2_events;
CREATE POLICY founder_partnership_v2_events_no_direct
  ON public.founder_partnership_v2_events
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

-- 1) Pipeline funnel: count + expected revenue by stage
CREATE OR REPLACE FUNCTION public.founder_partnerships_funnel()
RETURNS TABLE (
  stage text,
  stage_order int,
  deal_count bigint,
  expected_revenue_rupees bigint,
  stalled_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH stages(stage, stage_order) AS (
    VALUES
      ('sourced', 1),
      ('qualified', 2),
      ('discovery', 3),
      ('proposal', 4),
      ('negotiation', 5),
      ('contract', 6),
      ('live', 7)
  )
  SELECT
    s.stage,
    s.stage_order,
    COALESCE(COUNT(p.id), 0)::bigint AS deal_count,
    COALESCE(SUM(p.expected_annual_revenue_rupees), 0)::bigint AS expected_revenue_rupees,
    COALESCE(SUM(CASE WHEN p.stalled THEN 1 ELSE 0 END), 0)::bigint AS stalled_count
  FROM stages s
  LEFT JOIN public.founder_partnerships_v2 p ON p.stage = s.stage
  GROUP BY s.stage, s.stage_order
  ORDER BY s.stage_order;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_funnel() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_funnel() TO authenticated;

-- 2) KPI summary
CREATE OR REPLACE FUNCTION public.founder_partnerships_kpis()
RETURNS TABLE (
  total_deals bigint,
  live_deals bigint,
  contract_deals bigint,
  negotiation_deals bigint,
  stalled_deals bigint,
  total_expected_revenue_rupees bigint,
  live_expected_revenue_rupees bigint,
  weighted_pipeline_rupees bigint,
  oem_deals bigint,
  distributor_deals bigint,
  hospital_chain_deals bigint,
  financier_deals bigint,
  exclusive_deals bigint,
  signed_last_30d bigint,
  avg_days_to_contract numeric,
  active_owners bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE stage = 'live')::bigint,
    COUNT(*) FILTER (WHERE stage = 'contract')::bigint,
    COUNT(*) FILTER (WHERE stage = 'negotiation')::bigint,
    COUNT(*) FILTER (WHERE stalled)::bigint,
    COALESCE(SUM(expected_annual_revenue_rupees), 0)::bigint,
    COALESCE(SUM(expected_annual_revenue_rupees) FILTER (WHERE stage = 'live'), 0)::bigint,
    COALESCE(SUM(
      expected_annual_revenue_rupees * CASE stage
        WHEN 'sourced' THEN 0.05
        WHEN 'qualified' THEN 0.15
        WHEN 'discovery' THEN 0.30
        WHEN 'proposal' THEN 0.50
        WHEN 'negotiation' THEN 0.70
        WHEN 'contract' THEN 0.90
        WHEN 'live' THEN 1.00
        ELSE 0 END
    ), 0)::bigint,
    COUNT(*) FILTER (WHERE partner_type = 'oem')::bigint,
    COUNT(*) FILTER (WHERE partner_type = 'distributor')::bigint,
    COUNT(*) FILTER (WHERE partner_type = 'hospital_chain')::bigint,
    COUNT(*) FILTER (WHERE partner_type = 'financier')::bigint,
    COUNT(*) FILTER (WHERE exclusivity)::bigint,
    COUNT(*) FILTER (WHERE contract_signed_at >= now() - interval '30 days')::bigint,
    COALESCE(
      AVG(EXTRACT(EPOCH FROM (contract_signed_at - created_at)) / 86400.0)
        FILTER (WHERE contract_signed_at IS NOT NULL),
      0
    )::numeric,
    COUNT(DISTINCT owner_user_id) FILTER (WHERE owner_user_id IS NOT NULL)::bigint
  FROM public.founder_partnerships_v2;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_kpis() TO authenticated;

-- 3) Active deals list (excludes stalled)
CREATE OR REPLACE FUNCTION public.founder_partnerships_active()
RETURNS TABLE (
  id uuid,
  partner_name text,
  partner_type text,
  stage text,
  expected_annual_revenue_rupees bigint,
  revenue_share_pct numeric,
  exclusivity boolean,
  region text,
  last_activity_at timestamptz,
  days_since_activity int,
  go_live_target_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.partner_name,
    p.partner_type,
    p.stage,
    p.expected_annual_revenue_rupees,
    p.revenue_share_pct,
    p.exclusivity,
    p.region,
    p.last_activity_at,
    EXTRACT(DAY FROM (now() - p.last_activity_at))::int,
    p.go_live_target_date
  FROM public.founder_partnerships_v2 p
  WHERE NOT p.stalled
  ORDER BY p.expected_annual_revenue_rupees DESC NULLS LAST, p.last_activity_at DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_active() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_active() TO authenticated;

-- 4) Stalled deals
CREATE OR REPLACE FUNCTION public.founder_partnerships_stalled()
RETURNS TABLE (
  id uuid,
  partner_name text,
  partner_type text,
  stage text,
  stalled_reason text,
  expected_annual_revenue_rupees bigint,
  last_activity_at timestamptz,
  days_since_activity int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.partner_name,
    p.partner_type,
    p.stage,
    p.stalled_reason,
    p.expected_annual_revenue_rupees,
    p.last_activity_at,
    EXTRACT(DAY FROM (now() - p.last_activity_at))::int
  FROM public.founder_partnerships_v2 p
  WHERE p.stalled
  ORDER BY p.expected_annual_revenue_rupees DESC NULLS LAST, p.last_activity_at ASC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_stalled() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_stalled() TO authenticated;

-- 5) By partner type rollup
CREATE OR REPLACE FUNCTION public.founder_partnerships_by_type()
RETURNS TABLE (
  partner_type text,
  deal_count bigint,
  live_count bigint,
  stalled_count bigint,
  expected_revenue_rupees bigint,
  avg_revenue_share_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.partner_type,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE p.stage = 'live')::bigint,
    COUNT(*) FILTER (WHERE p.stalled)::bigint,
    COALESCE(SUM(p.expected_annual_revenue_rupees), 0)::bigint,
    COALESCE(AVG(p.revenue_share_pct), 0)::numeric
  FROM public.founder_partnerships_v2 p
  GROUP BY p.partner_type
  ORDER BY COALESCE(SUM(p.expected_annual_revenue_rupees), 0) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_by_type() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_by_type() TO authenticated;

-- 6) Recent activity feed
CREATE OR REPLACE FUNCTION public.founder_partnerships_recent_activity()
RETURNS TABLE (
  id uuid,
  partnership_id uuid,
  partner_name text,
  event_type text,
  from_stage text,
  to_stage text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.partnership_id,
    p.partner_name,
    e.event_type,
    e.from_stage,
    e.to_stage,
    e.note,
    e.created_at
  FROM public.founder_partnership_v2_events e
  JOIN public.founder_partnerships_v2 p ON p.id = e.partnership_id
  ORDER BY e.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_recent_activity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_recent_activity() TO authenticated;

-- 7) Top deals weighted
CREATE OR REPLACE FUNCTION public.founder_partnerships_top_weighted()
RETURNS TABLE (
  id uuid,
  partner_name text,
  partner_type text,
  stage text,
  expected_annual_revenue_rupees bigint,
  weighted_revenue_rupees bigint,
  exclusivity boolean,
  go_live_target_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.partner_name,
    p.partner_type,
    p.stage,
    p.expected_annual_revenue_rupees,
    (p.expected_annual_revenue_rupees * CASE p.stage
      WHEN 'sourced' THEN 0.05
      WHEN 'qualified' THEN 0.15
      WHEN 'discovery' THEN 0.30
      WHEN 'proposal' THEN 0.50
      WHEN 'negotiation' THEN 0.70
      WHEN 'contract' THEN 0.90
      WHEN 'live' THEN 1.00
      ELSE 0 END)::bigint,
    p.exclusivity,
    p.go_live_target_date
  FROM public.founder_partnerships_v2 p
  WHERE NOT p.stalled
  ORDER BY (p.expected_annual_revenue_rupees * CASE p.stage
      WHEN 'sourced' THEN 0.05
      WHEN 'qualified' THEN 0.15
      WHEN 'discovery' THEN 0.30
      WHEN 'proposal' THEN 0.50
      WHEN 'negotiation' THEN 0.70
      WHEN 'contract' THEN 0.90
      WHEN 'live' THEN 1.00
      ELSE 0 END) DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_partnerships_top_weighted() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_partnerships_top_weighted() TO authenticated;

-- =====================================================================
-- WRITE / LOG HELPERS (VOLATILE)
-- =====================================================================

-- log_founder_partnership_created
CREATE OR REPLACE FUNCTION public.log_founder_partnership_created(
  p_partner_name text,
  p_partner_type text,
  p_expected_annual_revenue_rupees bigint,
  p_region text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_partnerships_v2(
    partner_name, partner_type, expected_annual_revenue_rupees, region, notes, owner_user_id
  ) VALUES (
    p_partner_name, p_partner_type, COALESCE(p_expected_annual_revenue_rupees,0), p_region, p_notes, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_partnership_v2_events(partnership_id, event_type, to_stage, note, actor_user_id)
  VALUES (v_id, 'created', 'sourced', p_notes, auth.uid());

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_partnership_created(text,text,bigint,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_created(text,text,bigint,text,text) TO authenticated;

-- log_founder_partnership_stage_moved
CREATE OR REPLACE FUNCTION public.log_founder_partnership_stage_moved(
  p_partnership_id uuid,
  p_to_stage text,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT stage INTO v_from FROM public.founder_partnerships_v2 WHERE id = p_partnership_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'partnership not found'; END IF;

  UPDATE public.founder_partnerships_v2
     SET stage = p_to_stage,
         last_activity_at = now(),
         updated_at = now(),
         contract_signed_at = CASE WHEN p_to_stage IN ('contract','live') AND contract_signed_at IS NULL THEN now() ELSE contract_signed_at END,
         stalled = false,
         stalled_reason = NULL
   WHERE id = p_partnership_id;

  INSERT INTO public.founder_partnership_v2_events(partnership_id, event_type, from_stage, to_stage, note, actor_user_id)
  VALUES (p_partnership_id, 'stage_moved', v_from, p_to_stage, p_note, auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_partnership_stage_moved(uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_stage_moved(uuid,text,text) TO authenticated;

-- log_founder_partnership_stalled
CREATE OR REPLACE FUNCTION public.log_founder_partnership_stalled(
  p_partnership_id uuid,
  p_stalled boolean,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_partnerships_v2
     SET stalled = p_stalled,
         stalled_reason = CASE WHEN p_stalled THEN p_reason ELSE NULL END,
         last_activity_at = now(),
         updated_at = now()
   WHERE id = p_partnership_id;

  INSERT INTO public.founder_partnership_v2_events(partnership_id, event_type, note, actor_user_id)
  VALUES (
    p_partnership_id,
    CASE WHEN p_stalled THEN 'stalled_flagged' ELSE 'stalled_cleared' END,
    p_reason,
    auth.uid()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_partnership_stalled(uuid,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_stalled(uuid,boolean,text) TO authenticated;

-- log_founder_partnership_terms_updated
CREATE OR REPLACE FUNCTION public.log_founder_partnership_terms_updated(
  p_partnership_id uuid,
  p_expected_annual_revenue_rupees bigint,
  p_revenue_share_pct numeric,
  p_exclusivity boolean,
  p_terms_summary text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_partnerships_v2
     SET expected_annual_revenue_rupees = COALESCE(p_expected_annual_revenue_rupees, expected_annual_revenue_rupees),
         revenue_share_pct = COALESCE(p_revenue_share_pct, revenue_share_pct),
         exclusivity = COALESCE(p_exclusivity, exclusivity),
         commercial_terms_summary = COALESCE(p_terms_summary, commercial_terms_summary),
         last_activity_at = now(),
         updated_at = now()
   WHERE id = p_partnership_id;

  INSERT INTO public.founder_partnership_v2_events(partnership_id, event_type, note, actor_user_id)
  VALUES (p_partnership_id, 'terms_updated', p_terms_summary, auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_partnership_terms_updated(uuid,bigint,numeric,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_partnership_terms_updated(uuid,bigint,numeric,boolean,text) TO authenticated;

COMMIT;