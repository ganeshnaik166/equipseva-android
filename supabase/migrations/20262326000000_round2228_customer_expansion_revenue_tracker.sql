BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_expansion_events_r2228 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  customer_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  expansion_type text NOT NULL CHECK (expansion_type IN ('new_site','amc_tier_up','new_equipment_class','seat_add','volume_step_up','cross_sell_consumables','cross_sell_training')),
  prior_mrr_rupees integer NOT NULL DEFAULT 0,
  new_mrr_rupees integer NOT NULL DEFAULT 0,
  mrr_delta_rupees integer GENERATED ALWAYS AS (new_mrr_rupees - prior_mrr_rupees) STORED,
  one_time_revenue_rupees integer NOT NULL DEFAULT 0,
  equipment_class text,
  site_label text,
  amc_tier_from text,
  amc_tier_to text,
  triggered_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  expansion_source text NOT NULL DEFAULT 'organic' CHECK (expansion_source IN ('organic','csm_outbound','founder_outbound','referral','marketing','renewal_upsell')),
  confidence_score numeric(4,3) NOT NULL DEFAULT 1.000,
  notes text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cust_exp_r2228_occurred ON public.customer_expansion_events_r2228(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_cust_exp_r2228_org ON public.customer_expansion_events_r2228(customer_org_id);
CREATE INDEX IF NOT EXISTS idx_cust_exp_r2228_type ON public.customer_expansion_events_r2228(expansion_type);

ALTER TABLE public.customer_expansion_events_r2228 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_expansion_events_r2228;
CREATE POLICY founder_all ON public.customer_expansion_events_r2228 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_expansion_playbooks_r2228 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playbook_name text NOT NULL,
  target_segment text NOT NULL CHECK (target_segment IN ('hospital_chain','single_site','dental','diagnostic','tier1_urban','tier2_3','enterprise','startup')),
  trigger_signal text NOT NULL,
  expected_mrr_lift_rupees integer NOT NULL DEFAULT 0,
  conversion_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cust_exp_pb_r2228_active ON public.customer_expansion_playbooks_r2228(active);

ALTER TABLE public.customer_expansion_playbooks_r2228 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_expansion_playbooks_r2228;
CREATE POLICY founder_all ON public.customer_expansion_playbooks_r2228 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.cust_exp_summary_r2228()
RETURNS TABLE(total_events int, total_mrr_delta int, total_one_time int, organic_pct numeric, avg_mrr_lift int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    COALESCE(SUM(mrr_delta_rupees),0)::int,
    COALESCE(SUM(one_time_revenue_rupees),0)::int,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE expansion_source='organic'))::numeric / NULLIF(COUNT(*),0), 2),
    COALESCE(AVG(mrr_delta_rupees),0)::int
  FROM public.customer_expansion_events_r2228
  WHERE occurred_at >= now() - interval '90 days';
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_summary_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_summary_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_by_type_r2228()
RETURNS TABLE(expansion_type text, events int, mrr_delta int, avg_lift int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.expansion_type,
    (COUNT(*))::int,
    COALESCE(SUM(e.mrr_delta_rupees),0)::int,
    COALESCE(AVG(e.mrr_delta_rupees),0)::int
  FROM public.customer_expansion_events_r2228 e
  GROUP BY e.expansion_type
  ORDER BY SUM(e.mrr_delta_rupees) DESC NULLS LAST;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_by_type_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_by_type_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_top_accounts_r2228()
RETURNS TABLE(customer_org_id uuid, org_name text, events int, total_delta int, total_one_time int, last_event timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.customer_org_id,
    o.name,
    (COUNT(*))::int,
    COALESCE(SUM(e.mrr_delta_rupees),0)::int,
    COALESCE(SUM(e.one_time_revenue_rupees),0)::int,
    MAX(e.occurred_at)
  FROM public.customer_expansion_events_r2228 e
  LEFT JOIN public.organizations o ON o.id = e.customer_org_id
  GROUP BY e.customer_org_id, o.name
  ORDER BY SUM(e.mrr_delta_rupees) DESC NULLS LAST
  LIMIT 25;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_top_accounts_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_top_accounts_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_monthly_r2228()
RETURNS TABLE(month_label text, events int, mrr_delta int, one_time int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', e.occurred_at), 'YYYY-MM'),
    (COUNT(*))::int,
    COALESCE(SUM(e.mrr_delta_rupees),0)::int,
    COALESCE(SUM(e.one_time_revenue_rupees),0)::int
  FROM public.customer_expansion_events_r2228 e
  WHERE e.occurred_at >= now() - interval '12 months'
  GROUP BY date_trunc('month', e.occurred_at)
  ORDER BY date_trunc('month', e.occurred_at) DESC;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_monthly_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_monthly_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_recent_events_r2228()
RETURNS TABLE(id uuid, org_name text, expansion_type text, mrr_delta int, one_time int, source text, occurred_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    o.name,
    e.expansion_type,
    e.mrr_delta_rupees,
    e.one_time_revenue_rupees,
    e.expansion_source,
    e.occurred_at
  FROM public.customer_expansion_events_r2228 e
  LEFT JOIN public.organizations o ON o.id = e.customer_org_id
  ORDER BY e.occurred_at DESC
  LIMIT 100;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_recent_events_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_recent_events_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_playbooks_r2228()
RETURNS TABLE(id uuid, playbook_name text, target_segment text, trigger_signal text, expected_lift int, conv_rate numeric, active boolean, owner text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id, p.playbook_name, p.target_segment, p.trigger_signal,
    p.expected_mrr_lift_rupees, p.conversion_rate_pct, p.active, p.owner_email
  FROM public.customer_expansion_playbooks_r2228 p
  ORDER BY p.active DESC, p.expected_mrr_lift_rupees DESC NULLS LAST;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_playbooks_r2228() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_playbooks_r2228() TO authenticated;

CREATE OR REPLACE FUNCTION public.cust_exp_log_event_r2228(
  p_customer_org_id uuid,
  p_expansion_type text,
  p_prior_mrr int,
  p_new_mrr int,
  p_one_time int,
  p_source text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_expansion_events_r2228(
    customer_org_id, expansion_type, prior_mrr_rupees, new_mrr_rupees,
    one_time_revenue_rupees, expansion_source, notes
  ) VALUES (
    p_customer_org_id, p_expansion_type, COALESCE(p_prior_mrr,0), COALESCE(p_new_mrr,0),
    COALESCE(p_one_time,0), COALESCE(p_source,'organic'), p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.jwt()->>'email', 'cust_exp_log_event_r2228',
    jsonb_build_object('id', v_id, 'org', p_customer_org_id, 'type', p_expansion_type, 'delta', COALESCE(p_new_mrr,0)-COALESCE(p_prior_mrr,0)));
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.cust_exp_log_event_r2228(uuid,text,int,int,int,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cust_exp_log_event_r2228(uuid,text,int,int,int,text,text) TO authenticated;

COMMIT;