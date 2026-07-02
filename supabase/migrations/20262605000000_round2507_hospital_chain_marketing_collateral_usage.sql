-- Round 2507: Hospital chain marketing collateral usage
-- Tracks which collateral pieces drive engagement and deal influence across hospital chains.

CREATE TABLE IF NOT EXISTS public.chain_collateral_usage_r2507 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  collateral_kind text NOT NULL CHECK (collateral_kind IN ('case_study','whitepaper','roi_calculator','demo_video','pitch_deck','one_pager')),
  shared_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('email','in_person','webinar','portal','event')),
  engagement_score int NOT NULL DEFAULT 0 CHECK (engagement_score BETWEEN 0 AND 100),
  deal_influence text NOT NULL DEFAULT 'none' CHECK (deal_influence IN ('none','low','medium','high','critical')),
  influenced_revenue_rupees bigint NOT NULL DEFAULT 0,
  roi_per_piece numeric NOT NULL DEFAULT 0,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.collateral_engagement_log_r2507 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usage_id uuid NOT NULL REFERENCES public.chain_collateral_usage_r2507(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  viewer_email text,
  view_duration_seconds int NOT NULL DEFAULT 0,
  action_taken text NOT NULL DEFAULT 'none' CHECK (action_taken IN ('none','saved','shared','replied','booked_demo')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_collateral_usage_r2507 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collateral_engagement_log_r2507 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_collateral_usage_r2507;
CREATE POLICY founder_all ON public.chain_collateral_usage_r2507
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.collateral_engagement_log_r2507;
CREATE POLICY founder_all ON public.collateral_engagement_log_r2507
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.chain_collateral_usage_r2507 (chain_name, collateral_kind, channel, engagement_score, deal_influence, influenced_revenue_rupees, roi_per_piece, owner_email, notes) VALUES
  ('Apollo Hospitals', 'case_study', 'email', 82, 'high', 4500000, 18.5, 'sales1@equipseva.in', 'Cardiac monitor uptime case study'),
  ('Fortis Healthcare', 'roi_calculator', 'in_person', 91, 'critical', 7200000, 24.3, 'founder@equipseva.in', 'CFO presentation - 3yr TCO model'),
  ('Manipal Hospitals', 'pitch_deck', 'webinar', 65, 'medium', 1800000, 9.2, 'sales2@equipseva.in', 'Q2 chain expansion deck'),
  ('Max Healthcare', 'demo_video', 'portal', 48, 'low', 350000, 3.1, 'sales1@equipseva.in', 'AMC tier comparison video'),
  ('Narayana Health', 'whitepaper', 'event', 73, 'high', 2900000, 14.7, 'founder@equipseva.in', 'Spare-part provenance whitepaper at FICCI');

INSERT INTO public.collateral_engagement_log_r2507 (usage_id, viewer_email, view_duration_seconds, action_taken, notes)
SELECT id, 'cfo@apollohospitals.com', 240, 'replied', 'Asked for AMC pricing breakdown'
FROM public.chain_collateral_usage_r2507 WHERE chain_name='Apollo Hospitals' LIMIT 1;

INSERT INTO public.collateral_engagement_log_r2507 (usage_id, viewer_email, view_duration_seconds, action_taken, notes)
SELECT id, 'procurement@fortishealth.com', 612, 'booked_demo', 'Scheduled on-site demo'
FROM public.chain_collateral_usage_r2507 WHERE chain_name='Fortis Healthcare' LIMIT 1;

INSERT INTO public.collateral_engagement_log_r2507 (usage_id, viewer_email, view_duration_seconds, action_taken, notes)
SELECT id, 'biomed@manipalhospitals.com', 180, 'shared', 'Forwarded to 4 internal stakeholders'
FROM public.chain_collateral_usage_r2507 WHERE chain_name='Manipal Hospitals' LIMIT 1;

INSERT INTO public.collateral_engagement_log_r2507 (usage_id, viewer_email, view_duration_seconds, action_taken, notes)
SELECT id, 'ops@maxhealthcare.com', 95, 'saved', 'Bookmarked for Q3 review'
FROM public.chain_collateral_usage_r2507 WHERE chain_name='Max Healthcare' LIMIT 1;

INSERT INTO public.collateral_engagement_log_r2507 (usage_id, viewer_email, view_duration_seconds, action_taken, notes)
SELECT id, 'cmd@narayanahealth.org', 420, 'replied', 'Requested customized provenance audit'
FROM public.chain_collateral_usage_r2507 WHERE chain_name='Narayana Health' LIMIT 1;

-- RPC 1: list collateral usage
CREATE OR REPLACE FUNCTION public.list_collateral_usage_r2507()
RETURNS TABLE(id uuid, chain_name text, collateral_kind text, shared_at timestamptz, channel text, engagement_score int, deal_influence text, influenced_revenue_rupees bigint, roi_per_piece numeric, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.chain_name, u.collateral_kind, u.shared_at, u.channel, u.engagement_score, u.deal_influence, u.influenced_revenue_rupees, u.roi_per_piece, u.owner_email, u.notes
  FROM public.chain_collateral_usage_r2507 u
  ORDER BY u.shared_at DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.list_collateral_usage_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_collateral_usage_r2507() TO authenticated;

-- RPC 2: list engagement log
CREATE OR REPLACE FUNCTION public.list_engagement_log_r2507()
RETURNS TABLE(id uuid, usage_id uuid, chain_name text, collateral_kind text, viewed_at timestamptz, viewer_email text, view_duration_seconds int, action_taken text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.usage_id, u.chain_name, u.collateral_kind, l.viewed_at, l.viewer_email, l.view_duration_seconds, l.action_taken, l.notes
  FROM public.collateral_engagement_log_r2507 l
  JOIN public.chain_collateral_usage_r2507 u ON u.id = l.usage_id
  ORDER BY l.viewed_at DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.list_engagement_log_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagement_log_r2507() TO authenticated;

-- RPC 3: top ROI collateral
CREATE OR REPLACE FUNCTION public.top_roi_collateral_r2507()
RETURNS TABLE(collateral_kind text, total_pieces bigint, avg_roi numeric, total_influenced_revenue bigint, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.collateral_kind, COUNT(*)::bigint, ROUND(AVG(u.roi_per_piece)::numeric, 2), SUM(u.influenced_revenue_rupees)::bigint, ROUND(AVG(u.engagement_score)::numeric, 1)
  FROM public.chain_collateral_usage_r2507 u
  GROUP BY u.collateral_kind
  ORDER BY AVG(u.roi_per_piece) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.top_roi_collateral_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_roi_collateral_r2507() TO authenticated;

-- RPC 4: channel breakdown
CREATE OR REPLACE FUNCTION public.channel_breakdown_r2507()
RETURNS TABLE(channel text, total_pieces bigint, avg_engagement numeric, total_revenue bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.channel, COUNT(*)::bigint, ROUND(AVG(u.engagement_score)::numeric, 1), SUM(u.influenced_revenue_rupees)::bigint
  FROM public.chain_collateral_usage_r2507 u
  GROUP BY u.channel
  ORDER BY SUM(u.influenced_revenue_rupees) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.channel_breakdown_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_breakdown_r2507() TO authenticated;

-- RPC 5: engagement score distribution
CREATE OR REPLACE FUNCTION public.engagement_score_distribution_r2507()
RETURNS TABLE(bucket text, count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT CASE
    WHEN engagement_score >= 80 THEN '80-100 (hot)'
    WHEN engagement_score >= 60 THEN '60-79 (warm)'
    WHEN engagement_score >= 40 THEN '40-59 (lukewarm)'
    WHEN engagement_score >= 20 THEN '20-39 (cold)'
    ELSE '0-19 (ice)'
  END AS bucket,
  COUNT(*)::bigint
  FROM public.chain_collateral_usage_r2507
  GROUP BY bucket
  ORDER BY bucket DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.engagement_score_distribution_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engagement_score_distribution_r2507() TO authenticated;

-- RPC 6: monthly usage trend
CREATE OR REPLACE FUNCTION public.monthly_usage_trend_r2507()
RETURNS TABLE(month_label text, total_pieces bigint, avg_engagement numeric, total_influenced_revenue bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', u.shared_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint,
         ROUND(AVG(u.engagement_score)::numeric, 1),
         SUM(u.influenced_revenue_rupees)::bigint
  FROM public.chain_collateral_usage_r2507 u
  GROUP BY date_trunc('month', u.shared_at)
  ORDER BY date_trunc('month', u.shared_at) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.monthly_usage_trend_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_usage_trend_r2507() TO authenticated;

-- RPC 7: top influencing chains
CREATE OR REPLACE FUNCTION public.top_influencing_chains_r2507()
RETURNS TABLE(chain_name text, pieces_shared bigint, total_revenue bigint, avg_roi numeric, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.chain_name, COUNT(*)::bigint, SUM(u.influenced_revenue_rupees)::bigint, ROUND(AVG(u.roi_per_piece)::numeric, 2), ROUND(AVG(u.engagement_score)::numeric, 1)
  FROM public.chain_collateral_usage_r2507 u
  GROUP BY u.chain_name
  ORDER BY SUM(u.influenced_revenue_rupees) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.top_influencing_chains_r2507() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influencing_chains_r2507() TO authenticated;
