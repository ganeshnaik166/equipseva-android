-- Round 2487: hospital-chain-co-marketing-deals
-- chain × co-marketing campaign × spend split × leads generated × deals influenced × ROI

CREATE TABLE IF NOT EXISTS public.chain_co_marketing_deals_r2487 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  campaign_name text NOT NULL,
  campaign_kind text NOT NULL CHECK (campaign_kind IN ('joint_webinar','case_study','event_sponsorship','social','print_ad','conference_talk')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  our_spend_rupees bigint NOT NULL DEFAULT 0 CHECK (our_spend_rupees >= 0),
  their_spend_rupees bigint NOT NULL DEFAULT 0 CHECK (their_spend_rupees >= 0),
  leads_generated int NOT NULL DEFAULT 0 CHECK (leads_generated >= 0),
  deals_influenced_rupees bigint NOT NULL DEFAULT 0 CHECK (deals_influenced_rupees >= 0),
  roi_multiple numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_co_mkt_r2487_status ON public.chain_co_marketing_deals_r2487(status);
CREATE INDEX IF NOT EXISTS idx_chain_co_mkt_r2487_chain ON public.chain_co_marketing_deals_r2487(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_co_mkt_r2487_kind ON public.chain_co_marketing_deals_r2487(campaign_kind);

ALTER TABLE public.chain_co_marketing_deals_r2487 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_co_marketing_deals_r2487;
CREATE POLICY founder_all ON public.chain_co_marketing_deals_r2487 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.co_marketing_lead_attributions_r2487 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id uuid NOT NULL REFERENCES public.chain_co_marketing_deals_r2487(id) ON DELETE CASCADE,
  lead_at timestamptz NOT NULL DEFAULT now(),
  lead_kind text NOT NULL CHECK (lead_kind IN ('MQL','SQL','opportunity','closed_won','closed_lost')),
  lead_value_rupees bigint NOT NULL DEFAULT 0 CHECK (lead_value_rupees >= 0),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_co_mkt_leads_r2487_deal ON public.co_marketing_lead_attributions_r2487(deal_id);
CREATE INDEX IF NOT EXISTS idx_co_mkt_leads_r2487_kind ON public.co_marketing_lead_attributions_r2487(lead_kind);
CREATE INDEX IF NOT EXISTS idx_co_mkt_leads_r2487_at ON public.co_marketing_lead_attributions_r2487(lead_at);

ALTER TABLE public.co_marketing_lead_attributions_r2487 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.co_marketing_lead_attributions_r2487;
CREATE POLICY founder_all ON public.co_marketing_lead_attributions_r2487 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  d1 uuid;
  d2 uuid;
  d3 uuid;
  d4 uuid;
BEGIN
  INSERT INTO public.chain_co_marketing_deals_r2487 (chain_name, campaign_name, campaign_kind, started_at, ended_at, our_spend_rupees, their_spend_rupees, leads_generated, deals_influenced_rupees, roi_multiple, status, owner_email, notes)
  VALUES ('Apollo Hospitals', 'Cardiac Equipment Joint Webinar Q2', 'joint_webinar', '2026-04-10'::timestamptz, '2026-04-25'::timestamptz, 150000, 200000, 42, 8500000, 24.29, 'completed', 'founder@equipseva.com', 'Strong attendance, 8 hot leads')
  RETURNING id INTO d1;

  INSERT INTO public.chain_co_marketing_deals_r2487 (chain_name, campaign_name, campaign_kind, started_at, ended_at, our_spend_rupees, their_spend_rupees, leads_generated, deals_influenced_rupees, roi_multiple, status, owner_email, notes)
  VALUES ('Fortis Healthcare', 'Diagnostic Imaging Case Study Series', 'case_study', '2026-05-01'::timestamptz, NULL, 80000, 50000, 18, 3200000, 24.62, 'in_progress', 'mkt@equipseva.com', '3 case studies published')
  RETURNING id INTO d2;

  INSERT INTO public.chain_co_marketing_deals_r2487 (chain_name, campaign_name, campaign_kind, started_at, ended_at, our_spend_rupees, their_spend_rupees, leads_generated, deals_influenced_rupees, roi_multiple, status, owner_email, notes)
  VALUES ('Manipal Hospitals', 'HealthCare Summit 2026 Sponsorship', 'event_sponsorship', '2026-06-15'::timestamptz, '2026-06-17'::timestamptz, 500000, 300000, 65, 12000000, 15.00, 'completed', 'founder@equipseva.com', 'Booth + keynote slot')
  RETURNING id INTO d3;

  INSERT INTO public.chain_co_marketing_deals_r2487 (chain_name, campaign_name, campaign_kind, started_at, ended_at, our_spend_rupees, their_spend_rupees, leads_generated, deals_influenced_rupees, roi_multiple, status, owner_email, notes)
  VALUES ('Narayana Health', 'Service-First LinkedIn Campaign', 'social', '2026-06-01'::timestamptz, NULL, 40000, 30000, 12, 1500000, 21.43, 'planned', 'mkt@equipseva.com', 'Kickoff next week')
  RETURNING id INTO d4;

  INSERT INTO public.co_marketing_lead_attributions_r2487 (deal_id, lead_at, lead_kind, lead_value_rupees, owner_email, notes) VALUES (d1, '2026-04-15'::timestamptz, 'MQL', 800000, 'sales@equipseva.com', 'Apollo Bangalore - imaging');
  INSERT INTO public.co_marketing_lead_attributions_r2487 (deal_id, lead_at, lead_kind, lead_value_rupees, owner_email, notes) VALUES (d1, '2026-04-22'::timestamptz, 'closed_won', 2500000, 'sales@equipseva.com', 'AMC + retrofit deal');
  INSERT INTO public.co_marketing_lead_attributions_r2487 (deal_id, lead_at, lead_kind, lead_value_rupees, owner_email, notes) VALUES (d2, '2026-05-10'::timestamptz, 'SQL', 600000, 'sales@equipseva.com', 'Fortis Mulund qualified');
  INSERT INTO public.co_marketing_lead_attributions_r2487 (deal_id, lead_at, lead_kind, lead_value_rupees, owner_email, notes) VALUES (d3, '2026-06-16'::timestamptz, 'opportunity', 4500000, 'sales@equipseva.com', 'Manipal Yelahanka opp');
  INSERT INTO public.co_marketing_lead_attributions_r2487 (deal_id, lead_at, lead_kind, lead_value_rupees, owner_email, notes) VALUES (d3, '2026-06-18'::timestamptz, 'closed_lost', 1200000, 'sales@equipseva.com', 'Lost to incumbent');
END
$seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_co_marketing_deals_r2487()
RETURNS TABLE (
  id uuid,
  chain_name text,
  campaign_name text,
  campaign_kind text,
  started_at timestamptz,
  ended_at timestamptz,
  our_spend_rupees bigint,
  their_spend_rupees bigint,
  leads_generated int,
  deals_influenced_rupees bigint,
  roi_multiple numeric,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.campaign_name, d.campaign_kind, d.started_at, d.ended_at,
         d.our_spend_rupees, d.their_spend_rupees, d.leads_generated, d.deals_influenced_rupees,
         d.roi_multiple, d.status, d.owner_email, d.notes
  FROM public.chain_co_marketing_deals_r2487 d
  ORDER BY d.started_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_co_marketing_deals_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_co_marketing_deals_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_lead_attributions_r2487()
RETURNS TABLE (
  id uuid,
  deal_id uuid,
  campaign_name text,
  chain_name text,
  lead_at timestamptz,
  lead_kind text,
  lead_value_rupees bigint,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.deal_id, d.campaign_name, d.chain_name, l.lead_at, l.lead_kind,
         l.lead_value_rupees, l.owner_email, l.notes
  FROM public.co_marketing_lead_attributions_r2487 l
  JOIN public.chain_co_marketing_deals_r2487 d ON d.id = l.deal_id
  ORDER BY l.lead_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_lead_attributions_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_lead_attributions_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_roi_campaigns_r2487()
RETURNS TABLE (
  id uuid,
  chain_name text,
  campaign_name text,
  campaign_kind text,
  total_spend_rupees bigint,
  deals_influenced_rupees bigint,
  roi_multiple numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.campaign_name, d.campaign_kind,
         (d.our_spend_rupees + d.their_spend_rupees)::bigint AS total_spend_rupees,
         d.deals_influenced_rupees, d.roi_multiple, d.status
  FROM public.chain_co_marketing_deals_r2487 d
  ORDER BY d.roi_multiple DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_roi_campaigns_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_campaigns_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.campaign_kind_summary_r2487()
RETURNS TABLE (
  campaign_kind text,
  campaign_count bigint,
  total_our_spend bigint,
  total_their_spend bigint,
  total_leads bigint,
  total_influenced bigint,
  avg_roi numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.campaign_kind,
         COUNT(*)::bigint AS campaign_count,
         COALESCE(SUM(d.our_spend_rupees),0)::bigint AS total_our_spend,
         COALESCE(SUM(d.their_spend_rupees),0)::bigint AS total_their_spend,
         COALESCE(SUM(d.leads_generated),0)::bigint AS total_leads,
         COALESCE(SUM(d.deals_influenced_rupees),0)::bigint AS total_influenced,
         COALESCE(AVG(d.roi_multiple),0)::numeric AS avg_roi
  FROM public.chain_co_marketing_deals_r2487 d
  GROUP BY d.campaign_kind
  ORDER BY avg_roi DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.campaign_kind_summary_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.campaign_kind_summary_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_lead_trend_r2487()
RETURNS TABLE (
  month_start timestamptz,
  lead_count bigint,
  total_lead_value bigint,
  closed_won_count bigint,
  closed_won_value bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', l.lead_at)::timestamptz AS month_start,
         COUNT(*)::bigint AS lead_count,
         COALESCE(SUM(l.lead_value_rupees),0)::bigint AS total_lead_value,
         COUNT(*) FILTER (WHERE l.lead_kind = 'closed_won')::bigint AS closed_won_count,
         COALESCE(SUM(l.lead_value_rupees) FILTER (WHERE l.lead_kind = 'closed_won'),0)::bigint AS closed_won_value
  FROM public.co_marketing_lead_attributions_r2487 l
  GROUP BY date_trunc('month', l.lead_at)
  ORDER BY month_start DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_lead_trend_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_lead_trend_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_chains_by_roi_r2487()
RETURNS TABLE (
  chain_name text,
  campaign_count bigint,
  total_spend bigint,
  total_influenced bigint,
  avg_roi numeric,
  total_leads bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.chain_name,
         COUNT(*)::bigint AS campaign_count,
         COALESCE(SUM(d.our_spend_rupees + d.their_spend_rupees),0)::bigint AS total_spend,
         COALESCE(SUM(d.deals_influenced_rupees),0)::bigint AS total_influenced,
         COALESCE(AVG(d.roi_multiple),0)::numeric AS avg_roi,
         COALESCE(SUM(d.leads_generated),0)::bigint AS total_leads
  FROM public.chain_co_marketing_deals_r2487 d
  GROUP BY d.chain_name
  ORDER BY avg_roi DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_roi_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_chains_by_roi_r2487() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2487()
RETURNS TABLE (
  status text,
  campaign_count bigint,
  total_spend bigint,
  total_influenced bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.status,
         COUNT(*)::bigint AS campaign_count,
         COALESCE(SUM(d.our_spend_rupees + d.their_spend_rupees),0)::bigint AS total_spend,
         COALESCE(SUM(d.deals_influenced_rupees),0)::bigint AS total_influenced
  FROM public.chain_co_marketing_deals_r2487 d
  GROUP BY d.status
  ORDER BY campaign_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2487() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2487() TO authenticated;
