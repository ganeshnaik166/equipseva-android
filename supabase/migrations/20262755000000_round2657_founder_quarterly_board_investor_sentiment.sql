-- Round 2657: Founder Quarterly Board Investor Sentiment
-- Track investor sentiment per quarter plus recovery actions for concerned investors.

BEGIN;

-- =========================================================================
-- TABLE 1: founder_board_investor_sentiment_r2657
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_board_investor_sentiment_r2657 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  investor_name text NOT NULL,
  sentiment_kind text NOT NULL CHECK (sentiment_kind IN ('strongly_positive','positive','neutral','concerned','very_concerned')),
  top_concern_md text,
  top_endorsement_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','escalated','recovered','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbis_r2657_quarter ON public.founder_board_investor_sentiment_r2657(quarter_label);
CREATE INDEX IF NOT EXISTS idx_fbis_r2657_status ON public.founder_board_investor_sentiment_r2657(status);
CREATE INDEX IF NOT EXISTS idx_fbis_r2657_sentiment ON public.founder_board_investor_sentiment_r2657(sentiment_kind);

ALTER TABLE public.founder_board_investor_sentiment_r2657 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_board_investor_sentiment_r2657;
CREATE POLICY founder_all ON public.founder_board_investor_sentiment_r2657
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: sentiment_recovery_actions_r2657
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.sentiment_recovery_actions_r2657 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sentiment_id uuid NOT NULL REFERENCES public.founder_board_investor_sentiment_r2657(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('call','visit','data_share','founder_dinner','board_pack_revision')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sra_r2657_sentiment ON public.sentiment_recovery_actions_r2657(sentiment_id);
CREATE INDEX IF NOT EXISTS idx_sra_r2657_status ON public.sentiment_recovery_actions_r2657(status);
CREATE INDEX IF NOT EXISTS idx_sra_r2657_action_at ON public.sentiment_recovery_actions_r2657(action_at);

ALTER TABLE public.sentiment_recovery_actions_r2657 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.sentiment_recovery_actions_r2657;
CREATE POLICY founder_all ON public.sentiment_recovery_actions_r2657
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
INSERT INTO public.founder_board_investor_sentiment_r2657
  (quarter_label, investor_name, sentiment_kind, top_concern_md, top_endorsement_md, owner_email, status, notes)
VALUES
  ('Q1 FY27', 'Sequoia India Partner A', 'positive', 'Wants faster Tier-2 city expansion plan', 'Strong unit economics on AMC pool', 'founder@equipseva.in', 'monitoring', 'Met during Mar board meet'),
  ('Q1 FY27', 'Accel Growth Partner B', 'concerned', 'Engineer churn in South region trending up', 'NPS from hospitals at 62 is encouraging', 'founder@equipseva.in', 'escalated', 'Wants monthly cohort retention email'),
  ('Q1 FY27', 'Matrix Partners Principal', 'very_concerned', 'Cashfree KYC delay blocking payout scale', 'Founder transparency on weekly digest', 'founder@equipseva.in', 'escalated', 'Threatened pro-rata pull if not resolved by Q2'),
  ('Q4 FY26', 'Blume Ventures Partner', 'strongly_positive', NULL, 'Best execution speed of any Series A in portfolio', 'founder@equipseva.in', 'recovered', 'Doubled down with bridge cheque'),
  ('Q4 FY26', 'Lightspeed Director', 'neutral', 'Wants more competitive moat color', 'Likes bonded parts provenance launch', 'founder@equipseva.in', 'monitoring', 'Quarterly check-in cadence');

INSERT INTO public.sentiment_recovery_actions_r2657
  (sentiment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '14 days', 'founder_dinner', 'positive', 'founder@equipseva.in', 'done', 'Closed loop on Tier-2 plan'
FROM public.founder_board_investor_sentiment_r2657 WHERE investor_name = 'Sequoia India Partner A' LIMIT 1;

INSERT INTO public.sentiment_recovery_actions_r2657
  (sentiment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '7 days', 'data_share', 'neutral', 'founder@equipseva.in', 'done', 'Shared cohort retention deck'
FROM public.founder_board_investor_sentiment_r2657 WHERE investor_name = 'Accel Growth Partner B' LIMIT 1;

INSERT INTO public.sentiment_recovery_actions_r2657
  (sentiment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '3 days', 'call', 'pending', 'founder@equipseva.in', 'open', 'Cashfree weekly status update call'
FROM public.founder_board_investor_sentiment_r2657 WHERE investor_name = 'Matrix Partners Principal' LIMIT 1;

INSERT INTO public.sentiment_recovery_actions_r2657
  (sentiment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '21 days', 'board_pack_revision', 'positive', 'founder@equipseva.in', 'done', 'Added moat appendix per request'
FROM public.founder_board_investor_sentiment_r2657 WHERE investor_name = 'Lightspeed Director' LIMIT 1;

-- =========================================================================
-- RPC 1: list_sentiment_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_sentiment_r2657();
CREATE FUNCTION public.list_sentiment_r2657()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  investor_name text,
  sentiment_kind text,
  top_concern_md text,
  top_endorsement_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.investor_name, s.sentiment_kind,
         s.top_concern_md, s.top_endorsement_md, s.owner_email,
         s.status, s.notes, s.created_at
  FROM public.founder_board_investor_sentiment_r2657 s
  ORDER BY s.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_sentiment_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_sentiment_r2657() TO authenticated;

-- =========================================================================
-- RPC 2: list_recovery_actions_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_recovery_actions_r2657();
CREATE FUNCTION public.list_recovery_actions_r2657()
RETURNS TABLE (
  id uuid,
  sentiment_id uuid,
  investor_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.sentiment_id, s.investor_name,
         a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.sentiment_recovery_actions_r2657 a
  JOIN public.founder_board_investor_sentiment_r2657 s ON s.id = a.sentiment_id
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2657() TO authenticated;

-- =========================================================================
-- RPC 3: top_concerned_focus_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_concerned_focus_r2657();
CREATE FUNCTION public.top_concerned_focus_r2657()
RETURNS TABLE (
  id uuid,
  investor_name text,
  quarter_label text,
  sentiment_kind text,
  top_concern_md text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.quarter_label, s.sentiment_kind,
         s.top_concern_md, s.owner_email, s.status
  FROM public.founder_board_investor_sentiment_r2657 s
  WHERE s.sentiment_kind IN ('concerned','very_concerned')
    AND s.status IN ('monitoring','escalated')
  ORDER BY
    CASE s.sentiment_kind WHEN 'very_concerned' THEN 0 ELSE 1 END,
    s.created_at DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_concerned_focus_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concerned_focus_r2657() TO authenticated;

-- =========================================================================
-- RPC 4: sentiment_distribution_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.sentiment_distribution_r2657();
CREATE FUNCTION public.sentiment_distribution_r2657()
RETURNS TABLE (
  sentiment_kind text,
  investor_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.sentiment_kind, COUNT(*)::bigint
  FROM public.founder_board_investor_sentiment_r2657 s
  GROUP BY s.sentiment_kind
  ORDER BY
    CASE s.sentiment_kind
      WHEN 'strongly_positive' THEN 0
      WHEN 'positive' THEN 1
      WHEN 'neutral' THEN 2
      WHEN 'concerned' THEN 3
      WHEN 'very_concerned' THEN 4
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.sentiment_distribution_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sentiment_distribution_r2657() TO authenticated;

-- =========================================================================
-- RPC 5: status_funnel_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_funnel_r2657();
CREATE FUNCTION public.status_funnel_r2657()
RETURNS TABLE (
  status text,
  investor_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.status, COUNT(*)::bigint
  FROM public.founder_board_investor_sentiment_r2657 s
  GROUP BY s.status
  ORDER BY
    CASE s.status
      WHEN 'monitoring' THEN 0
      WHEN 'escalated' THEN 1
      WHEN 'recovered' THEN 2
      WHEN 'closed' THEN 3
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2657() TO authenticated;

-- =========================================================================
-- RPC 6: quarterly_sentiment_trend_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.quarterly_sentiment_trend_r2657();
CREATE FUNCTION public.quarterly_sentiment_trend_r2657()
RETURNS TABLE (
  quarter_label text,
  total_investors bigint,
  positive_count bigint,
  concerned_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label,
         COUNT(*)::bigint AS total_investors,
         COUNT(*) FILTER (WHERE s.sentiment_kind IN ('strongly_positive','positive'))::bigint AS positive_count,
         COUNT(*) FILTER (WHERE s.sentiment_kind IN ('concerned','very_concerned'))::bigint AS concerned_count
  FROM public.founder_board_investor_sentiment_r2657 s
  GROUP BY s.quarter_label
  ORDER BY s.quarter_label DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_sentiment_trend_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_sentiment_trend_r2657() TO authenticated;

-- =========================================================================
-- RPC 7: founder_pulse_summary_r2657
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_pulse_summary_r2657();
CREATE FUNCTION public.founder_pulse_summary_r2657()
RETURNS TABLE (
  total_investors bigint,
  positive_pct numeric,
  concerned_pct numeric,
  open_recovery_actions bigint,
  recovered_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::bigint INTO v_total FROM public.founder_board_investor_sentiment_r2657;

  RETURN QUERY
  SELECT
    v_total,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(
           (SELECT COUNT(*)::numeric FROM public.founder_board_investor_sentiment_r2657 WHERE sentiment_kind IN ('strongly_positive','positive')) * 100.0 / v_total, 1)
    END AS positive_pct,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE ROUND(
           (SELECT COUNT(*)::numeric FROM public.founder_board_investor_sentiment_r2657 WHERE sentiment_kind IN ('concerned','very_concerned')) * 100.0 / v_total, 1)
    END AS concerned_pct,
    (SELECT COUNT(*)::bigint FROM public.sentiment_recovery_actions_r2657 WHERE status = 'open') AS open_recovery_actions,
    (SELECT COUNT(*)::bigint FROM public.founder_board_investor_sentiment_r2657 WHERE status = 'recovered') AS recovered_count;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2657() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2657() TO authenticated;

COMMIT;
