BEGIN;
-- r1420 founder_sales_pipeline_v2 — multi-stage multi-decision-maker pipeline
-- Extends r1331 with deeper deal structure: deals + contacts + activities.

CREATE TABLE IF NOT EXISTS public.founder_sales_pipeline_v2_deals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_label text NOT NULL UNIQUE,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  target_amc_tier text CHECK (target_amc_tier IN ('basic','bronze','silver','gold')),
  deal_stage text NOT NULL DEFAULT 'discovery' CHECK (deal_stage IN (
    'discovery','demo_scheduled','demo_completed','proposal_sent',
    'negotiation','contracted','closed_won','closed_lost','on_hold'
  )),
  deal_size_rupees numeric,
  expected_close_date date,
  probability_pct int CHECK (probability_pct BETWEEN 0 AND 100),
  salesperson_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fspv2_deals_stage ON public.founder_sales_pipeline_v2_deals(deal_stage);
CREATE INDEX IF NOT EXISTS idx_fspv2_deals_org ON public.founder_sales_pipeline_v2_deals(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fspv2_deals_close ON public.founder_sales_pipeline_v2_deals(expected_close_date);
CREATE INDEX IF NOT EXISTS idx_fspv2_deals_sales ON public.founder_sales_pipeline_v2_deals(salesperson_user_id);

CREATE TABLE IF NOT EXISTS public.founder_sales_pipeline_v2_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES public.founder_sales_pipeline_v2_deals(id) ON DELETE CASCADE,
  contact_name text NOT NULL,
  contact_role text NOT NULL CHECK (contact_role IN (
    'decision_maker','influencer','user','sponsor','blocker','gatekeeper'
  )),
  contact_email text,
  contact_phone text,
  sentiment text NOT NULL DEFAULT 'neutral' CHECK (sentiment IN (
    'champion','supportive','neutral','skeptical','opposed'
  )),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fspv2_contacts_deal ON public.founder_sales_pipeline_v2_contacts(deal_id);
CREATE INDEX IF NOT EXISTS idx_fspv2_contacts_role ON public.founder_sales_pipeline_v2_contacts(contact_role);

CREATE TABLE IF NOT EXISTS public.founder_sales_pipeline_v2_activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES public.founder_sales_pipeline_v2_deals(id) ON DELETE CASCADE,
  activity_kind text NOT NULL CHECK (activity_kind IN (
    'email','call','meeting','demo','proposal_sent',
    'contract_sent','site_visit','stakeholder_intro'
  )),
  description text,
  happened_at timestamptz NOT NULL DEFAULT now(),
  performed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fspv2_acts_deal ON public.founder_sales_pipeline_v2_activities(deal_id);
CREATE INDEX IF NOT EXISTS idx_fspv2_acts_kind ON public.founder_sales_pipeline_v2_activities(activity_kind);
CREATE INDEX IF NOT EXISTS idx_fspv2_acts_when ON public.founder_sales_pipeline_v2_activities(happened_at DESC);

ALTER TABLE public.founder_sales_pipeline_v2_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_sales_pipeline_v2_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_sales_pipeline_v2_activities ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.founder_sales_pipeline_v2_summary()
RETURNS TABLE (
  total_deals int,
  discovery_count int,
  demo_scheduled_count int,
  demo_completed_count int,
  proposal_sent_count int,
  negotiation_count int,
  contracted_count int,
  closed_won_count int,
  closed_lost_count int,
  on_hold_count int,
  pipeline_value_rupees numeric,
  weighted_pipeline_rupees numeric,
  closed_won_value_rupees numeric,
  avg_deal_size_rupees numeric,
  total_contacts int,
  champion_contact_count int,
  total_activities int,
  activities_last_7d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH d AS (SELECT * FROM public.founder_sales_pipeline_v2_deals),
  c AS (SELECT * FROM public.founder_sales_pipeline_v2_contacts),
  a AS (SELECT * FROM public.founder_sales_pipeline_v2_activities)
  SELECT
    (SELECT count(*)::int FROM d),
    (SELECT count(*)::int FROM d WHERE deal_stage='discovery'),
    (SELECT count(*)::int FROM d WHERE deal_stage='demo_scheduled'),
    (SELECT count(*)::int FROM d WHERE deal_stage='demo_completed'),
    (SELECT count(*)::int FROM d WHERE deal_stage='proposal_sent'),
    (SELECT count(*)::int FROM d WHERE deal_stage='negotiation'),
    (SELECT count(*)::int FROM d WHERE deal_stage='contracted'),
    (SELECT count(*)::int FROM d WHERE deal_stage='closed_won'),
    (SELECT count(*)::int FROM d WHERE deal_stage='closed_lost'),
    (SELECT count(*)::int FROM d WHERE deal_stage='on_hold'),
    (SELECT COALESCE(SUM(deal_size_rupees),0) FROM d
       WHERE deal_stage NOT IN ('closed_won','closed_lost')),
    (SELECT COALESCE(SUM(deal_size_rupees * COALESCE(probability_pct,0) / 100.0),0) FROM d
       WHERE deal_stage NOT IN ('closed_won','closed_lost')),
    (SELECT COALESCE(SUM(deal_size_rupees),0) FROM d WHERE deal_stage='closed_won'),
    (SELECT CASE WHEN count(*)>0 THEN round(AVG(deal_size_rupees)::numeric, 2) ELSE 0 END FROM d
       WHERE deal_size_rupees IS NOT NULL),
    (SELECT count(*)::int FROM c),
    (SELECT count(*)::int FROM c WHERE sentiment='champion'),
    (SELECT count(*)::int FROM a),
    (SELECT count(*)::int FROM a WHERE happened_at >= now() - interval '7 days');
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_sales_pipeline_v2_deals_recent()
RETURNS SETOF public.founder_sales_pipeline_v2_deals
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_sales_pipeline_v2_deals
    ORDER BY
      CASE deal_stage
        WHEN 'negotiation' THEN 1
        WHEN 'proposal_sent' THEN 2
        WHEN 'demo_completed' THEN 3
        WHEN 'demo_scheduled' THEN 4
        WHEN 'discovery' THEN 5
        WHEN 'contracted' THEN 6
        WHEN 'on_hold' THEN 7
        WHEN 'closed_won' THEN 8
        WHEN 'closed_lost' THEN 9
        ELSE 99 END,
      expected_close_date NULLS LAST,
      created_at DESC
    LIMIT 30;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_sales_pipeline_v2_contacts_recent(p_deal_id uuid DEFAULT NULL)
RETURNS SETOF public.founder_sales_pipeline_v2_contacts
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_sales_pipeline_v2_contacts
    WHERE p_deal_id IS NULL OR deal_id = p_deal_id
    ORDER BY created_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.founder_sales_pipeline_v2_activities_recent(p_deal_id uuid DEFAULT NULL)
RETURNS SETOF public.founder_sales_pipeline_v2_activities
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_sales_pipeline_v2_activities
    WHERE p_deal_id IS NULL OR deal_id = p_deal_id
    ORDER BY happened_at DESC, created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sales_v2_register_deal(
  p_deal_label text,
  p_hospital_org_id uuid DEFAULT NULL,
  p_target_amc_tier text DEFAULT NULL,
  p_deal_size_rupees numeric DEFAULT NULL,
  p_expected_close_date date DEFAULT NULL,
  p_probability_pct int DEFAULT NULL,
  p_salesperson_user_id uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_target_amc_tier IS NOT NULL AND p_target_amc_tier NOT IN ('basic','bronze','silver','gold') THEN
    RAISE EXCEPTION 'invalid tier' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_sales_pipeline_v2_deals(
    deal_label, hospital_org_id, target_amc_tier,
    deal_size_rupees, expected_close_date, probability_pct, salesperson_user_id
  ) VALUES (
    p_deal_label, p_hospital_org_id, p_target_amc_tier,
    p_deal_size_rupees, p_expected_close_date, p_probability_pct, p_salesperson_user_id
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sales_v2_add_contact(
  p_deal_id uuid,
  p_contact_name text,
  p_contact_role text,
  p_contact_email text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL,
  p_sentiment text DEFAULT 'neutral'
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_contact_role NOT IN ('decision_maker','influencer','user','sponsor','blocker','gatekeeper') THEN
    RAISE EXCEPTION 'invalid role' USING ERRCODE='22023';
  END IF;
  IF p_sentiment NOT IN ('champion','supportive','neutral','skeptical','opposed') THEN
    RAISE EXCEPTION 'invalid sentiment' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_sales_pipeline_v2_contacts(
    deal_id, contact_name, contact_role, contact_email, contact_phone, sentiment
  ) VALUES (
    p_deal_id, p_contact_name, p_contact_role, p_contact_email, p_contact_phone, p_sentiment
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sales_v2_log_activity(
  p_deal_id uuid,
  p_activity_kind text,
  p_description text DEFAULT NULL,
  p_happened_at timestamptz DEFAULT NULL,
  p_performed_by uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_activity_kind NOT IN ('email','call','meeting','demo','proposal_sent','contract_sent','site_visit','stakeholder_intro') THEN
    RAISE EXCEPTION 'invalid activity kind' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_sales_pipeline_v2_activities(
    deal_id, activity_kind, description, happened_at, performed_by
  ) VALUES (
    p_deal_id, p_activity_kind, p_description, COALESCE(p_happened_at, now()), p_performed_by
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_founder_sales_v2_stage_change(
  p_deal_id uuid,
  p_new_stage text,
  p_new_probability_pct int DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_new_stage NOT IN ('discovery','demo_scheduled','demo_completed','proposal_sent','negotiation','contracted','closed_won','closed_lost','on_hold') THEN
    RAISE EXCEPTION 'invalid stage' USING ERRCODE='22023';
  END IF;
  IF p_new_probability_pct IS NOT NULL AND (p_new_probability_pct < 0 OR p_new_probability_pct > 100) THEN
    RAISE EXCEPTION 'invalid probability' USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_sales_pipeline_v2_deals
    SET deal_stage = p_new_stage,
        probability_pct = COALESCE(p_new_probability_pct, probability_pct),
        updated_at = now()
  WHERE id = p_deal_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_sales_pipeline_v2_summary() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_sales_pipeline_v2_deals_recent() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_sales_pipeline_v2_contacts_recent(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_sales_pipeline_v2_activities_recent(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_sales_v2_register_deal(text,uuid,text,numeric,date,int,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_sales_v2_add_contact(uuid,text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_sales_v2_log_activity(uuid,text,text,timestamptz,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_sales_v2_stage_change(uuid,text,int) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.founder_sales_pipeline_v2_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sales_pipeline_v2_deals_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sales_pipeline_v2_contacts_recent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_sales_pipeline_v2_activities_recent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sales_v2_register_deal(text,uuid,text,numeric,date,int,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sales_v2_add_contact(uuid,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sales_v2_log_activity(uuid,text,text,timestamptz,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_sales_v2_stage_change(uuid,text,int) TO authenticated;

COMMIT;