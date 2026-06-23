-- Round 2471: Hospital Chain VIP Customer Tier Tracker
-- chain x tier (gold/platinum/diamond) x white-glove SLAs x dedicated rep x exec QBR cadence

BEGIN;

-- =========================================================================
-- TABLE: chain_vip_tiers_r2471
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.chain_vip_tiers_r2471 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  vip_tier text NOT NULL CHECK (vip_tier IN ('gold','platinum','diamond')),
  monthly_value_rupees bigint NOT NULL CHECK (monthly_value_rupees >= 0),
  white_glove_sla_minutes int NOT NULL CHECK (white_glove_sla_minutes > 0),
  dedicated_rep_email text,
  exec_qbr_cadence_days int NOT NULL CHECK (exec_qbr_cadence_days > 0),
  last_exec_qbr_at timestamptz,
  next_exec_qbr_due_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','at_risk','churned','upgraded')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_vip_tiers_r2471_tier
  ON public.chain_vip_tiers_r2471(vip_tier);
CREATE INDEX IF NOT EXISTS idx_chain_vip_tiers_r2471_status
  ON public.chain_vip_tiers_r2471(status);
CREATE INDEX IF NOT EXISTS idx_chain_vip_tiers_r2471_next_qbr
  ON public.chain_vip_tiers_r2471(next_exec_qbr_due_at);

ALTER TABLE public.chain_vip_tiers_r2471 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_vip_tiers_r2471;
CREATE POLICY founder_all ON public.chain_vip_tiers_r2471
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE: vip_white_glove_events_r2471
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.vip_white_glove_events_r2471 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES public.chain_vip_tiers_r2471(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('escalation','extra_visit','exec_call','gift','event_invite','exclusive_demo')),
  summary text NOT NULL,
  owner_email text,
  customer_satisfaction int CHECK (customer_satisfaction IS NULL OR (customer_satisfaction >= 0 AND customer_satisfaction <= 10)),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vip_wg_events_r2471_chain
  ON public.vip_white_glove_events_r2471(chain_id);
CREATE INDEX IF NOT EXISTS idx_vip_wg_events_r2471_kind
  ON public.vip_white_glove_events_r2471(event_kind);
CREATE INDEX IF NOT EXISTS idx_vip_wg_events_r2471_status
  ON public.vip_white_glove_events_r2471(status);

ALTER TABLE public.vip_white_glove_events_r2471 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.vip_white_glove_events_r2471;
CREATE POLICY founder_all ON public.vip_white_glove_events_r2471
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
DO $seed$
DECLARE
  v_chain1_id uuid;
  v_chain2_id uuid;
  v_chain3_id uuid;
  v_chain4_id uuid;
BEGIN
  INSERT INTO public.chain_vip_tiers_r2471
    (chain_name, vip_tier, monthly_value_rupees, white_glove_sla_minutes, dedicated_rep_email, exec_qbr_cadence_days, last_exec_qbr_at, next_exec_qbr_due_at, status, notes)
  VALUES ('Apollo Hospitals', 'diamond', 4500000, 30, 'rep.apollo@equipseva.in', 90, now() - interval '20 days', now() + interval '70 days', 'active', 'Largest national chain — strategic logo')
  RETURNING id INTO v_chain1_id;

  INSERT INTO public.chain_vip_tiers_r2471
    (chain_name, vip_tier, monthly_value_rupees, white_glove_sla_minutes, dedicated_rep_email, exec_qbr_cadence_days, last_exec_qbr_at, next_exec_qbr_due_at, status, notes)
  VALUES ('Manipal Hospitals', 'platinum', 2800000, 45, 'rep.manipal@equipseva.in', 120, now() - interval '60 days', now() + interval '60 days', 'active', 'Bangalore HQ — Karnataka stronghold')
  RETURNING id INTO v_chain2_id;

  INSERT INTO public.chain_vip_tiers_r2471
    (chain_name, vip_tier, monthly_value_rupees, white_glove_sla_minutes, dedicated_rep_email, exec_qbr_cadence_days, last_exec_qbr_at, next_exec_qbr_due_at, status, notes)
  VALUES ('Yashoda Hospitals', 'platinum', 2100000, 60, 'rep.yashoda@equipseva.in', 120, now() - interval '100 days', now() + interval '20 days', 'at_risk', 'QBR overdue — escalate to founder')
  RETURNING id INTO v_chain3_id;

  INSERT INTO public.chain_vip_tiers_r2471
    (chain_name, vip_tier, monthly_value_rupees, white_glove_sla_minutes, dedicated_rep_email, exec_qbr_cadence_days, last_exec_qbr_at, next_exec_qbr_due_at, status, notes)
  VALUES ('KIMS Hospitals', 'gold', 950000, 90, 'rep.kims@equipseva.in', 180, now() - interval '40 days', now() + interval '140 days', 'active', 'Upgrade candidate to platinum Q4')
  RETURNING id INTO v_chain4_id;

  -- White-glove events
  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain1_id, now() - interval '5 days', 'exec_call', 'Founder check-in with CMO', 'founder@equipseva.in', 9, 'done');

  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain1_id, now() + interval '15 days', 'exclusive_demo', 'AI triage early-access demo', 'product@equipseva.in', NULL, 'planned');

  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain2_id, now() - interval '10 days', 'extra_visit', 'Surprise on-site visit by VP', 'vp.cs@equipseva.in', 8, 'done');

  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain3_id, now() - interval '2 days', 'escalation', 'CT scanner down 6hrs — founder escalation', 'founder@equipseva.in', 4, 'done');

  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain3_id, now() + interval '7 days', 'exec_call', 'Recovery call with COO', 'founder@equipseva.in', NULL, 'planned');

  INSERT INTO public.vip_white_glove_events_r2471
    (chain_id, event_at, event_kind, summary, owner_email, customer_satisfaction, status)
  VALUES (v_chain4_id, now() + interval '30 days', 'event_invite', 'MedTech 2026 conference VIP table', 'events@equipseva.in', NULL, 'planned');
END;
$seed$;

-- =========================================================================
-- RPC: list_vip_tiers_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_vip_tiers_r2471()
RETURNS TABLE (
  id uuid,
  chain_name text,
  vip_tier text,
  monthly_value_rupees bigint,
  white_glove_sla_minutes int,
  dedicated_rep_email text,
  exec_qbr_cadence_days int,
  last_exec_qbr_at timestamptz,
  next_exec_qbr_due_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.chain_name, t.vip_tier, t.monthly_value_rupees, t.white_glove_sla_minutes,
         t.dedicated_rep_email, t.exec_qbr_cadence_days, t.last_exec_qbr_at,
         t.next_exec_qbr_due_at, t.status, t.notes, t.created_at
  FROM public.chain_vip_tiers_r2471 t
  ORDER BY t.monthly_value_rupees DESC, t.chain_name ASC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_vip_tiers_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_vip_tiers_r2471() TO authenticated;

-- =========================================================================
-- RPC: list_white_glove_events_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_white_glove_events_r2471()
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  vip_tier text,
  event_at timestamptz,
  event_kind text,
  summary text,
  owner_email text,
  customer_satisfaction int,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_id, t.chain_name, t.vip_tier, e.event_at, e.event_kind,
         e.summary, e.owner_email, e.customer_satisfaction, e.status, e.notes, e.created_at
  FROM public.vip_white_glove_events_r2471 e
  JOIN public.chain_vip_tiers_r2471 t ON t.id = e.chain_id
  ORDER BY e.event_at DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.list_white_glove_events_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_white_glove_events_r2471() TO authenticated;

-- =========================================================================
-- RPC: top_value_chains_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_value_chains_r2471()
RETURNS TABLE (
  chain_name text,
  vip_tier text,
  monthly_value_rupees bigint,
  status text,
  next_exec_qbr_due_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.vip_tier, t.monthly_value_rupees, t.status, t.next_exec_qbr_due_at
  FROM public.chain_vip_tiers_r2471 t
  ORDER BY t.monthly_value_rupees DESC
  LIMIT 10;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.top_value_chains_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_chains_r2471() TO authenticated;

-- =========================================================================
-- RPC: upcoming_exec_qbrs_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.upcoming_exec_qbrs_r2471()
RETURNS TABLE (
  chain_name text,
  vip_tier text,
  next_exec_qbr_due_at timestamptz,
  days_until int,
  dedicated_rep_email text,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name,
         t.vip_tier,
         t.next_exec_qbr_due_at,
         EXTRACT(DAY FROM (t.next_exec_qbr_due_at - now()))::int AS days_until,
         t.dedicated_rep_email,
         t.status
  FROM public.chain_vip_tiers_r2471 t
  WHERE t.next_exec_qbr_due_at IS NOT NULL
    AND t.status IN ('active','at_risk')
  ORDER BY t.next_exec_qbr_due_at ASC
  LIMIT 20;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.upcoming_exec_qbrs_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_exec_qbrs_r2471() TO authenticated;

-- =========================================================================
-- RPC: tier_distribution_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.tier_distribution_r2471()
RETURNS TABLE (
  vip_tier text,
  chain_count bigint,
  total_monthly_value_rupees bigint,
  avg_sla_minutes numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.vip_tier,
         COUNT(*)::bigint AS chain_count,
         COALESCE(SUM(t.monthly_value_rupees),0)::bigint AS total_monthly_value_rupees,
         ROUND(AVG(t.white_glove_sla_minutes)::numeric, 1) AS avg_sla_minutes
  FROM public.chain_vip_tiers_r2471 t
  GROUP BY t.vip_tier
  ORDER BY CASE t.vip_tier WHEN 'diamond' THEN 1 WHEN 'platinum' THEN 2 WHEN 'gold' THEN 3 ELSE 4 END;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r2471() TO authenticated;

-- =========================================================================
-- RPC: white_glove_satisfaction_summary_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.white_glove_satisfaction_summary_r2471()
RETURNS TABLE (
  event_kind text,
  event_count bigint,
  avg_satisfaction numeric,
  done_count bigint,
  planned_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_kind,
         COUNT(*)::bigint AS event_count,
         ROUND(AVG(e.customer_satisfaction)::numeric, 2) AS avg_satisfaction,
         COUNT(*) FILTER (WHERE e.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE e.status = 'planned')::bigint AS planned_count
  FROM public.vip_white_glove_events_r2471 e
  GROUP BY e.event_kind
  ORDER BY event_count DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.white_glove_satisfaction_summary_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.white_glove_satisfaction_summary_r2471() TO authenticated;

-- =========================================================================
-- RPC: status_breakdown_r2471
-- =========================================================================
CREATE OR REPLACE FUNCTION public.status_breakdown_r2471()
RETURNS TABLE (
  status text,
  chain_count bigint,
  total_monthly_value_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status,
         COUNT(*)::bigint AS chain_count,
         COALESCE(SUM(t.monthly_value_rupees),0)::bigint AS total_monthly_value_rupees
  FROM public.chain_vip_tiers_r2471 t
  GROUP BY t.status
  ORDER BY total_monthly_value_rupees DESC;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2471() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2471() TO authenticated;

