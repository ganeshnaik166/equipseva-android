-- r2628: customer quarterly net promoter conversion tracker

CREATE TABLE IF NOT EXISTS public.customer_nps_conversion_r2628 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  nps int NOT NULL CHECK (nps BETWEEN -100 AND 100),
  promoter_to_referral_pct numeric(6,2) NOT NULL DEFAULT 0,
  detractor_to_churn_pct numeric(6,2) NOT NULL DEFAULT 0,
  converted_referrals_count int NOT NULL DEFAULT 0,
  churn_count int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','converted','churned','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.nps_conversion_actions_r2628 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversion_id uuid NOT NULL REFERENCES public.customer_nps_conversion_r2628(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('referral_ask','promoter_bonus','detractor_save','win_back','escalation')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_nps_conversion_r2628 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nps_conversion_actions_r2628 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_nps_conversion_r2628;
CREATE POLICY founder_all ON public.customer_nps_conversion_r2628
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.nps_conversion_actions_r2628;
CREATE POLICY founder_all ON public.nps_conversion_actions_r2628
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed conversions
INSERT INTO public.customer_nps_conversion_r2628 (quarter_label, nps, promoter_to_referral_pct, detractor_to_churn_pct, converted_referrals_count, churn_count, owner_email, status, notes)
VALUES
  ('Q1-FY26', 62, 38.50, 12.40, 18, 3, 'cs.lead@equipseva.in', 'converted', 'Strong promoter base; 18 referral conversions closed'),
  ('Q2-FY26', 58, 34.20, 14.80, 14, 5, 'cs.lead@equipseva.in', 'monitoring', 'Mid quarter dip; detractor saves in progress'),
  ('Q3-FY26', 71, 42.10, 9.30, 22, 2, 'founder@equipseva.in', 'converted', 'Best quarter; promoter bonus program scaled'),
  ('Q4-FY26', 49, 26.50, 19.20, 9, 7, 'cs.lead@equipseva.in', 'churned', 'Detractor cluster from Chennai chain; escalation needed'),
  ('Q1-FY27', 65, 39.80, 11.60, 17, 4, 'founder@equipseva.in', 'monitoring', 'Recovering; referral ask cadence increased');

-- Seed actions
INSERT INTO public.nps_conversion_actions_r2628 (conversion_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'referral_ask', 'positive', 'cs.lead@equipseva.in', 'done', 'Asked top 12 promoters; 8 referred'
FROM public.customer_nps_conversion_r2628 WHERE quarter_label = 'Q1-FY26' LIMIT 1;

INSERT INTO public.nps_conversion_actions_r2628 (conversion_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'promoter_bonus', 'positive', 'founder@equipseva.in', 'done', 'Quarterly bonus credit issued to promoter cohort'
FROM public.customer_nps_conversion_r2628 WHERE quarter_label = 'Q3-FY26' LIMIT 1;

INSERT INTO public.nps_conversion_actions_r2628 (conversion_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'detractor_save', 'neutral', 'cs.lead@equipseva.in', 'open', 'Reaching out to 5 detractor hospitals this week'
FROM public.customer_nps_conversion_r2628 WHERE quarter_label = 'Q2-FY26' LIMIT 1;

INSERT INTO public.nps_conversion_actions_r2628 (conversion_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'escalation', 'pending', 'founder@equipseva.in', 'open', 'Founder call scheduled with Chennai chain ops head'
FROM public.customer_nps_conversion_r2628 WHERE quarter_label = 'Q4-FY26' LIMIT 1;

INSERT INTO public.nps_conversion_actions_r2628 (conversion_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'win_back', 'pending', 'cs.lead@equipseva.in', 'open', 'Custom AMC pricing draft sent to lost accounts'
FROM public.customer_nps_conversion_r2628 WHERE quarter_label = 'Q1-FY27' LIMIT 1;

-- RPCs
CREATE OR REPLACE FUNCTION public.list_conversions_r2628()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  nps int,
  promoter_to_referral_pct numeric,
  detractor_to_churn_pct numeric,
  converted_referrals_count int,
  churn_count int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.quarter_label, c.nps, c.promoter_to_referral_pct, c.detractor_to_churn_pct,
         c.converted_referrals_count, c.churn_count, c.owner_email, c.status, c.notes, c.created_at
  FROM public.customer_nps_conversion_r2628 c
  ORDER BY c.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_conversions_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_conversions_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2628()
RETURNS TABLE (
  id uuid,
  conversion_id uuid,
  quarter_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.conversion_id, c.quarter_label, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.nps_conversion_actions_r2628 a
  JOIN public.customer_nps_conversion_r2628 c ON c.id = a.conversion_id
  ORDER BY a.action_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_promoter_focus_r2628()
RETURNS TABLE (
  quarter_label text,
  nps int,
  promoter_to_referral_pct numeric,
  converted_referrals_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.quarter_label, c.nps, c.promoter_to_referral_pct, c.converted_referrals_count
  FROM public.customer_nps_conversion_r2628 c
  ORDER BY c.converted_referrals_count DESC, c.promoter_to_referral_pct DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_promoter_focus_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_promoter_focus_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.conversion_kind_distribution_r2628()
RETURNS TABLE (
  action_kind text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind, count(*)::bigint
  FROM public.nps_conversion_actions_r2628 a
  GROUP BY a.action_kind
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.conversion_kind_distribution_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conversion_kind_distribution_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2628()
RETURNS TABLE (
  status text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status, count(*)::bigint
  FROM public.customer_nps_conversion_r2628 c
  GROUP BY c.status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_conversion_trend_r2628()
RETURNS TABLE (
  quarter_label text,
  nps int,
  converted_referrals_count int,
  churn_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.quarter_label, c.nps, c.converted_referrals_count, c.churn_count
  FROM public.customer_nps_conversion_r2628 c
  ORDER BY c.created_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_conversion_trend_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_conversion_trend_r2628() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2628()
RETURNS TABLE (
  owner_email text,
  open_actions bigint,
  done_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(a.owner_email, 'unassigned') AS owner_email,
         count(*) FILTER (WHERE a.status = 'open')::bigint AS open_actions,
         count(*) FILTER (WHERE a.status = 'done')::bigint AS done_actions
  FROM public.nps_conversion_actions_r2628 a
  GROUP BY coalesce(a.owner_email, 'unassigned')
  ORDER BY count(*) FILTER (WHERE a.status = 'open') DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2628() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2628() TO authenticated;
