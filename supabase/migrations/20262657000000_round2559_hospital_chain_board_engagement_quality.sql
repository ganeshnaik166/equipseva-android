-- Round 2559: hospital-chain-board-engagement-quality
-- Chain × board exposure × our board reach × engagement × deal advancement

CREATE TABLE IF NOT EXISTS public.chain_board_engagements_r2559 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  board_exposure_at timestamptz NOT NULL DEFAULT now(),
  engagement_kind text NOT NULL CHECK (engagement_kind IN ('presentation','board_dinner','quarterly_review','site_visit','exec_session')),
  our_attendees_md text,
  their_attendees_md text,
  engagement_score int NOT NULL DEFAULT 50 CHECK (engagement_score BETWEEN 0 AND 100),
  deal_advancement_kind text NOT NULL DEFAULT 'none' CHECK (deal_advancement_kind IN ('none','awareness','interest','commitment','close')),
  arr_advanced_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_board_engagements_r2559 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_board_engagements_r2559;
CREATE POLICY founder_all ON public.chain_board_engagements_r2559 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.board_engagement_follow_ups_r2559 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id uuid NOT NULL REFERENCES public.chain_board_engagements_r2559(id) ON DELETE CASCADE,
  follow_up_at timestamptz NOT NULL DEFAULT now(),
  follow_up_kind text NOT NULL CHECK (follow_up_kind IN ('call','email','proposal','meeting','intro')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_engagement_follow_ups_r2559 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.board_engagement_follow_ups_r2559;
CREATE POLICY founder_all ON public.board_engagement_follow_ups_r2559 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.chain_board_engagements_r2559 (chain_name, board_exposure_at, engagement_kind, our_attendees_md, their_attendees_md, engagement_score, deal_advancement_kind, arr_advanced_rupees, owner_email, status, notes)
VALUES
  ('Apollo Hospitals','2026-06-10 10:00:00+05:30'::timestamptz,'presentation','- Founder/CEO\n- Head of BD','- CIO\n- COO\n- VP Biomed',82,'interest',2400000,'founder@equipseva.in','done','Strong interest in AMC for cath labs'),
  ('Manipal Health','2026-06-15 18:00:00+05:30'::timestamptz,'board_dinner','- Founder/CEO\n- Sales Head','- Group MD\n- CFO\n- Board Chair',74,'awareness',0,'founder@equipseva.in','done','Intro dinner — board chair receptive'),
  ('Fortis Healthcare','2026-06-22 15:00:00+05:30'::timestamptz,'quarterly_review','- CEO\n- BD\n- CS Lead','- CIO\n- VP Operations',88,'commitment',5200000,'founder@equipseva.in','done','Verbal commitment for 12 sites'),
  ('Max Healthcare','2026-06-28 11:00:00+05:30'::timestamptz,'site_visit','- Founder\n- Field engineers','- Biomed head\n- Regional GM',61,'awareness',0,'founder@equipseva.in','planned','Site visit at Saket flagship'),
  ('Narayana Health','2026-06-30 16:00:00+05:30'::timestamptz,'exec_session','- Founder\n- Product','- Chairman office\n- CFO',77,'interest',1800000,'founder@equipseva.in','planned','Exec session — chairman attending');

INSERT INTO public.board_engagement_follow_ups_r2559 (engagement_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12 09:00:00+05:30'::timestamptz, 'proposal','positive','founder@equipseva.in','closed','Proposal sent + acknowledged'
FROM public.chain_board_engagements_r2559 WHERE chain_name='Apollo Hospitals' LIMIT 1;

INSERT INTO public.board_engagement_follow_ups_r2559 (engagement_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-17 11:00:00+05:30'::timestamptz, 'email','neutral','founder@equipseva.in','in_progress','Thank-you note + deck shared'
FROM public.chain_board_engagements_r2559 WHERE chain_name='Manipal Health' LIMIT 1;

INSERT INTO public.board_engagement_follow_ups_r2559 (engagement_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-25 14:00:00+05:30'::timestamptz, 'meeting','positive','founder@equipseva.in','in_progress','Contract draft scheduled'
FROM public.chain_board_engagements_r2559 WHERE chain_name='Fortis Healthcare' LIMIT 1;

INSERT INTO public.board_engagement_follow_ups_r2559 (engagement_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-02 10:00:00+05:30'::timestamptz, 'call','pending','founder@equipseva.in','open','Followup call after exec session'
FROM public.chain_board_engagements_r2559 WHERE chain_name='Narayana Health' LIMIT 1;

INSERT INTO public.board_engagement_follow_ups_r2559 (engagement_id, follow_up_at, follow_up_kind, outcome, owner_email, status, notes)
SELECT id, '2026-07-05 16:00:00+05:30'::timestamptz, 'intro','pending','founder@equipseva.in','open','Intro to chairman office requested'
FROM public.chain_board_engagements_r2559 WHERE chain_name='Max Healthcare' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_engagements_r2559()
RETURNS TABLE(id uuid, chain_name text, board_exposure_at timestamptz, engagement_kind text, engagement_score int, deal_advancement_kind text, arr_advanced_rupees bigint, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.chain_name, e.board_exposure_at, e.engagement_kind, e.engagement_score, e.deal_advancement_kind, e.arr_advanced_rupees, e.owner_email, e.status, e.notes
    FROM public.chain_board_engagements_r2559 e
    ORDER BY e.board_exposure_at DESC NULLS LAST
    LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_engagements_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagements_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_follow_ups_r2559()
RETURNS TABLE(id uuid, engagement_id uuid, chain_name text, follow_up_at timestamptz, follow_up_kind text, outcome text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.engagement_id, e.chain_name, f.follow_up_at, f.follow_up_kind, f.outcome, f.owner_email, f.status, f.notes
    FROM public.board_engagement_follow_ups_r2559 f
    JOIN public.chain_board_engagements_r2559 e ON e.id = f.engagement_id
    ORDER BY f.follow_up_at DESC NULLS LAST
    LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_follow_ups_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_follow_ups_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_deal_advancement_r2559()
RETURNS TABLE(chain_name text, engagement_count bigint, total_arr_rupees bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.chain_name, COUNT(*)::bigint, COALESCE(SUM(e.arr_advanced_rupees),0)::bigint, ROUND(AVG(e.engagement_score)::numeric, 2)
    FROM public.chain_board_engagements_r2559 e
    GROUP BY e.chain_name
    ORDER BY COALESCE(SUM(e.arr_advanced_rupees),0) DESC NULLS LAST
    LIMIT 20;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_deal_advancement_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_deal_advancement_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.engagement_kind_summary_r2559()
RETURNS TABLE(engagement_kind text, n bigint, avg_score numeric, total_arr_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.engagement_kind, COUNT(*)::bigint, ROUND(AVG(e.engagement_score)::numeric,2), COALESCE(SUM(e.arr_advanced_rupees),0)::bigint
    FROM public.chain_board_engagements_r2559 e
    GROUP BY e.engagement_kind
    ORDER BY COUNT(*) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.engagement_kind_summary_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engagement_kind_summary_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.deal_advancement_distribution_r2559()
RETURNS TABLE(deal_advancement_kind text, n bigint, total_arr_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.deal_advancement_kind, COUNT(*)::bigint, COALESCE(SUM(e.arr_advanced_rupees),0)::bigint
    FROM public.chain_board_engagements_r2559 e
    GROUP BY e.deal_advancement_kind
    ORDER BY COUNT(*) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.deal_advancement_distribution_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deal_advancement_distribution_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_engagement_trend_r2559()
RETURNS TABLE(month_start timestamptz, n bigint, avg_score numeric, total_arr_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', e.board_exposure_at)::timestamptz, COUNT(*)::bigint, ROUND(AVG(e.engagement_score)::numeric,2), COALESCE(SUM(e.arr_advanced_rupees),0)::bigint
    FROM public.chain_board_engagements_r2559 e
    GROUP BY date_trunc('month', e.board_exposure_at)
    ORDER BY date_trunc('month', e.board_exposure_at) DESC NULLS LAST
    LIMIT 24;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_engagement_trend_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_engagement_trend_r2559() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2559()
RETURNS TABLE(owner_email text, engagements bigint, follow_ups bigint, open_follow_ups bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(e.owner_email, f.owner_email) AS owner_email,
           COUNT(DISTINCT e.id)::bigint,
           COUNT(DISTINCT f.id)::bigint,
           COUNT(DISTINCT f.id) FILTER (WHERE f.status IN ('open','in_progress'))::bigint
    FROM public.chain_board_engagements_r2559 e
    FULL OUTER JOIN public.board_engagement_follow_ups_r2559 f
      ON f.engagement_id = e.id
    WHERE COALESCE(e.owner_email, f.owner_email) IS NOT NULL
    GROUP BY COALESCE(e.owner_email, f.owner_email)
    ORDER BY COUNT(DISTINCT e.id) DESC NULLS LAST
    LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2559() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2559() TO authenticated;
