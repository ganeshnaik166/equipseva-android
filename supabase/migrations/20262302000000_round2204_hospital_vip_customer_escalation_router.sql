BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_vip_accounts_r2204 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  tier text NOT NULL CHECK (tier IN ('platinum','gold','silver')),
  annual_revenue_rupees numeric(14,2) NOT NULL DEFAULT 0,
  dedicated_csm_user_id uuid REFERENCES public.profiles(id),
  dedicated_csm_email text,
  response_sla_minutes int NOT NULL DEFAULT 30,
  resolution_sla_hours int NOT NULL DEFAULT 4,
  fast_track_enabled boolean NOT NULL DEFAULT true,
  escalation_chain jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_vip_escalations_r2204 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vip_account_id uuid NOT NULL REFERENCES public.hospital_vip_accounts_r2204(id),
  hospital_org_id uuid NOT NULL,
  hospital_name text NOT NULL,
  tier text NOT NULL,
  subject text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','in_progress','resolved','breached')),
  routed_to_csm_email text,
  first_response_at timestamptz,
  resolved_at timestamptz,
  response_sla_minutes int NOT NULL DEFAULT 30,
  resolution_sla_hours int NOT NULL DEFAULT 4,
  breached_response boolean NOT NULL DEFAULT false,
  breached_resolution boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_vip_accounts_r2204 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_vip_escalations_r2204 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_vip_accounts_r2204;
CREATE POLICY founder_all ON public.hospital_vip_accounts_r2204
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_vip_escalations_r2204;
CREATE POLICY founder_all ON public.hospital_vip_escalations_r2204
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list VIP accounts
DROP FUNCTION IF EXISTS public.list_vip_accounts_r2204();
CREATE OR REPLACE FUNCTION public.list_vip_accounts_r2204()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  tier text,
  annual_revenue_rupees numeric,
  dedicated_csm_email text,
  response_sla_minutes int,
  resolution_sla_hours int,
  fast_track_enabled boolean,
  open_escalations int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_name, a.tier, a.annual_revenue_rupees,
         a.dedicated_csm_email, a.response_sla_minutes, a.resolution_sla_hours,
         a.fast_track_enabled,
         (SELECT COUNT(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')) FROM public.hospital_vip_escalations_r2204 e WHERE e.vip_account_id = a.id)::int,
         a.created_at
  FROM public.hospital_vip_accounts_r2204 a
  ORDER BY a.annual_revenue_rupees DESC, a.created_at DESC
  LIMIT 200;
END $$;

-- recent escalations
DROP FUNCTION IF EXISTS public.recent_actions_r2204();
CREATE OR REPLACE FUNCTION public.recent_actions_r2204()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  tier text,
  subject text,
  severity text,
  status text,
  routed_to_csm_email text,
  breached_response boolean,
  breached_resolution boolean,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_name, e.tier, e.subject, e.severity, e.status,
         e.routed_to_csm_email, e.breached_response, e.breached_resolution, e.created_at
  FROM public.hospital_vip_escalations_r2204 e
  ORDER BY e.created_at DESC
  LIMIT 100;
END $$;

-- top by tier
DROP FUNCTION IF EXISTS public.top_tier_r2204();
CREATE OR REPLACE FUNCTION public.top_tier_r2204()
RETURNS TABLE (
  tier text,
  account_count int,
  open_escalations int,
  breached_total int,
  total_revenue_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.tier,
         (COUNT(*) )::int AS account_count,
         (SELECT (COUNT(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')))::int FROM public.hospital_vip_escalations_r2204 e WHERE e.tier = a.tier) AS open_escalations,
         (SELECT (COUNT(*) FILTER (WHERE e.breached_response OR e.breached_resolution))::int FROM public.hospital_vip_escalations_r2204 e WHERE e.tier = a.tier) AS breached_total,
         (SUM(a.annual_revenue_rupees))::numeric AS total_revenue_rupees
  FROM public.hospital_vip_accounts_r2204 a
  GROUP BY a.tier
  ORDER BY total_revenue_rupees DESC;
END $$;

-- log new VIP account
DROP FUNCTION IF EXISTS public.log_vip_accounts_r2204(uuid, text, text, numeric, text, int, int, boolean);
CREATE OR REPLACE FUNCTION public.log_vip_accounts_r2204(
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_tier text,
  p_annual_revenue_rupees numeric,
  p_csm_email text,
  p_response_sla_minutes int,
  p_resolution_sla_hours int,
  p_fast_track_enabled boolean
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_vip_accounts_r2204(
    hospital_org_id, hospital_name, tier, annual_revenue_rupees,
    dedicated_csm_email, response_sla_minutes, resolution_sla_hours, fast_track_enabled)
  VALUES (p_hospital_org_id, p_hospital_name, p_tier, p_annual_revenue_rupees,
    p_csm_email, p_response_sla_minutes, p_resolution_sla_hours, p_fast_track_enabled)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2204_log_vip_account',
    jsonb_build_object('id', v_id, 'hospital_name', p_hospital_name, 'tier', p_tier));
  RETURN v_id;
END $$;

-- log escalation
DROP FUNCTION IF EXISTS public.log_action_r2204(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2204(
  p_vip_account_id uuid,
  p_subject text,
  p_severity text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_a public.hospital_vip_accounts_r2204%ROWTYPE;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT * INTO v_a FROM public.hospital_vip_accounts_r2204 WHERE id = p_vip_account_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'vip account not found'; END IF;
  INSERT INTO public.hospital_vip_escalations_r2204(
    vip_account_id, hospital_org_id, hospital_name, tier,
    subject, severity, status, routed_to_csm_email,
    response_sla_minutes, resolution_sla_hours)
  VALUES (p_vip_account_id, v_a.hospital_org_id, v_a.hospital_name, v_a.tier,
    p_subject, p_severity, 'open', v_a.dedicated_csm_email,
    v_a.response_sla_minutes, v_a.resolution_sla_hours)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2204_log_escalation',
    jsonb_build_object('id', v_id, 'vip_account_id', p_vip_account_id, 'severity', p_severity));
  RETURN v_id;
END $$;

-- mark escalation status
DROP FUNCTION IF EXISTS public.mark_status_r2204(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2204(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','acknowledged','in_progress','resolved','breached') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_vip_escalations_r2204
  SET status = p_status,
      first_response_at = CASE WHEN first_response_at IS NULL AND p_status IN ('acknowledged','in_progress') THEN now() ELSE first_response_at END,
      resolved_at = CASE WHEN p_status = 'resolved' THEN now() ELSE resolved_at END
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2204_mark_status',
    jsonb_build_object('id', p_id, 'status', p_status));
END $$;

-- aggregate SLA health
DROP FUNCTION IF EXISTS public.aggregate_sla_health_r2204();
CREATE OR REPLACE FUNCTION public.aggregate_sla_health_r2204()
RETURNS TABLE (
  total_vip_accounts int,
  platinum_accounts int,
  open_escalations int,
  response_breaches int,
  resolution_breaches int,
  total_vip_revenue_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_vip_accounts_r2204),
    (SELECT (COUNT(*) FILTER (WHERE tier = 'platinum'))::int FROM public.hospital_vip_accounts_r2204),
    (SELECT (COUNT(*) FILTER (WHERE status IN ('open','acknowledged','in_progress')))::int FROM public.hospital_vip_escalations_r2204),
    (SELECT (COUNT(*) FILTER (WHERE breached_response))::int FROM public.hospital_vip_escalations_r2204),
    (SELECT (COUNT(*) FILTER (WHERE breached_resolution))::int FROM public.hospital_vip_escalations_r2204),
    (SELECT COALESCE(SUM(annual_revenue_rupees),0)::numeric FROM public.hospital_vip_accounts_r2204);
END $$;

REVOKE ALL ON FUNCTION public.list_vip_accounts_r2204() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2204() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_tier_r2204() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_vip_accounts_r2204(uuid, text, text, numeric, text, int, int, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2204(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2204(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_sla_health_r2204() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vip_accounts_r2204() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2204() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tier_r2204() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_vip_accounts_r2204(uuid, text, text, numeric, text, int, int, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2204(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2204(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_sla_health_r2204() TO authenticated;

COMMIT;
