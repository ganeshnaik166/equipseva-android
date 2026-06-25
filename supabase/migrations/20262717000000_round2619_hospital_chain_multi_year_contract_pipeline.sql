-- Round 2619: Hospital chain multi-year contract pipeline
-- Two tables: chain_multi_year_contracts_r2619, multi_year_contract_progress_r2619
-- Seven RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.chain_multi_year_contracts_r2619 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  contract_term_years int NOT NULL CHECK (contract_term_years > 0),
  total_value_rupees bigint NOT NULL CHECK (total_value_rupees >= 0),
  escalator_pct numeric(6,2) NOT NULL DEFAULT 0,
  lock_in_clauses_md text,
  win_probability_pct int NOT NULL DEFAULT 50 CHECK (win_probability_pct >= 0 AND win_probability_pct <= 100),
  owner_email text,
  status text NOT NULL DEFAULT 'prospecting' CHECK (status IN ('prospecting','proposed','negotiating','signed','lost','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.multi_year_contract_progress_r2619 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.chain_multi_year_contracts_r2619(id) ON DELETE CASCADE,
  progress_at timestamptz NOT NULL DEFAULT now(),
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('intro','proposal','legal_review','signoff','kickoff')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_multi_year_contracts_r2619 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.multi_year_contract_progress_r2619 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_multi_year_contracts_r2619;
CREATE POLICY founder_all ON public.chain_multi_year_contracts_r2619
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.multi_year_contract_progress_r2619;
CREATE POLICY founder_all ON public.multi_year_contract_progress_r2619
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data (no apostrophes in strings)
INSERT INTO public.chain_multi_year_contracts_r2619
  (chain_name, contract_term_years, total_value_rupees, escalator_pct, lock_in_clauses_md, win_probability_pct, owner_email, status, notes)
VALUES
  ('Apollo North', 5, 180000000, 6.50, '- 5 year exclusive AMC across 12 sites\n- Annual 6.5 percent escalator\n- 18 month exit penalty', 65, 'founder@equipseva.in', 'negotiating', 'Procurement aligned; legal in review'),
  ('Yashoda Group', 3, 72000000, 5.00, '- 3 year imaging block AMC\n- 5 percent annual escalator\n- Right of first refusal on capex', 70, 'sales@equipseva.in', 'proposed', 'Awaiting board approval'),
  ('Care Hospitals', 4, 96000000, 4.50, '- 4 year multi-modal coverage\n- 4.5 percent escalator\n- Outcome guarantee clause', 45, 'founder@equipseva.in', 'prospecting', 'Initial mapping with COO'),
  ('KIMS', 5, 150000000, 7.00, '- 5 year ICU + OT bundle\n- 7 percent escalator\n- 12hr SLA premium', 85, 'ops@equipseva.in', 'signed', 'Renewal closed at premium tier'),
  ('Continental', 2, 28000000, 3.50, '- 2 year pilot AMC\n- 3.5 percent escalator\n- Convert option to 5 year', 30, 'founder@equipseva.in', 'lost', 'Went in-house biomed');

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-12 10:00:00'::timestamptz, 'intro', 'positive', 'founder@equipseva.in', 'done', 'CXO intro warm'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'Apollo North' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-15 11:30:00'::timestamptz, 'proposal', 'neutral', 'founder@equipseva.in', 'done', 'Sent 5yr term sheet'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'Apollo North' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-10 14:00:00'::timestamptz, 'legal_review', 'pending', 'founder@equipseva.in', 'open', 'Legal redlines coming'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'Apollo North' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-22 10:00:00'::timestamptz, 'proposal', 'neutral', 'sales@equipseva.in', 'done', 'Board pack delivered'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'Yashoda Group' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-01 09:00:00'::timestamptz, 'intro', 'positive', 'ops@equipseva.in', 'done', 'Renewal kickoff with COO'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'KIMS' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-10 13:00:00'::timestamptz, 'signoff', 'positive', 'ops@equipseva.in', 'done', 'Master agreement executed'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'KIMS' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-01 11:00:00'::timestamptz, 'kickoff', 'positive', 'ops@equipseva.in', 'done', 'Implementation underway'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'KIMS' LIMIT 1;

INSERT INTO public.multi_year_contract_progress_r2619 (contract_id, progress_at, milestone_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-15 09:30:00'::timestamptz, 'intro', 'pending', 'founder@equipseva.in', 'open', 'COO mapping call scheduled'
FROM public.chain_multi_year_contracts_r2619 WHERE chain_name = 'Care Hospitals' LIMIT 1;

-- RPC 1: list_contracts_r2619
CREATE OR REPLACE FUNCTION public.list_contracts_r2619()
RETURNS TABLE (
  id uuid,
  chain_name text,
  contract_term_years int,
  total_value_rupees bigint,
  escalator_pct numeric,
  win_probability_pct int,
  weighted_value_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.contract_term_years, c.total_value_rupees,
         c.escalator_pct, c.win_probability_pct,
         ((c.total_value_rupees * c.win_probability_pct) / 100)::bigint AS weighted_value_rupees,
         c.owner_email, c.status, c.notes
  FROM public.chain_multi_year_contracts_r2619 c
  ORDER BY c.total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_contracts_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_contracts_r2619() TO authenticated;

-- RPC 2: list_progress_r2619
CREATE OR REPLACE FUNCTION public.list_progress_r2619()
RETURNS TABLE (
  id uuid,
  chain_name text,
  progress_at timestamptz,
  milestone_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, c.chain_name, p.progress_at, p.milestone_kind, p.outcome,
         p.owner_email, p.status, p.notes
  FROM public.multi_year_contract_progress_r2619 p
  JOIN public.chain_multi_year_contracts_r2619 c ON c.id = p.contract_id
  ORDER BY p.progress_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_progress_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_progress_r2619() TO authenticated;

-- RPC 3: top_value_focus_r2619
CREATE OR REPLACE FUNCTION public.top_value_focus_r2619()
RETURNS TABLE (
  chain_name text,
  total_value_rupees bigint,
  win_probability_pct int,
  weighted_value_rupees bigint,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_name, c.total_value_rupees, c.win_probability_pct,
         ((c.total_value_rupees * c.win_probability_pct) / 100)::bigint AS weighted_value_rupees,
         c.status, c.owner_email
  FROM public.chain_multi_year_contracts_r2619 c
  WHERE c.status IN ('prospecting','proposed','negotiating')
  ORDER BY ((c.total_value_rupees * c.win_probability_pct) / 100) DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2619() TO authenticated;

-- RPC 4: status_funnel_r2619
CREATE OR REPLACE FUNCTION public.status_funnel_r2619()
RETURNS TABLE (
  status text,
  total bigint,
  total_value_rupees bigint,
  weighted_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
         count(*)::bigint,
         COALESCE(sum(c.total_value_rupees), 0)::bigint,
         COALESCE(sum((c.total_value_rupees * c.win_probability_pct) / 100), 0)::bigint
  FROM public.chain_multi_year_contracts_r2619 c
  GROUP BY c.status
  ORDER BY
    CASE c.status
      WHEN 'prospecting' THEN 0
      WHEN 'proposed' THEN 1
      WHEN 'negotiating' THEN 2
      WHEN 'signed' THEN 3
      WHEN 'lost' THEN 4
      WHEN 'dropped' THEN 5
      ELSE 6
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2619() TO authenticated;

-- RPC 5: milestone_distribution_r2619
CREATE OR REPLACE FUNCTION public.milestone_distribution_r2619()
RETURNS TABLE (
  milestone_kind text,
  total bigint,
  positive_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.milestone_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE p.outcome = 'positive')::bigint,
         count(*) FILTER (WHERE p.outcome = 'pending')::bigint
  FROM public.multi_year_contract_progress_r2619 p
  GROUP BY p.milestone_kind
  ORDER BY
    CASE p.milestone_kind
      WHEN 'intro' THEN 0
      WHEN 'proposal' THEN 1
      WHEN 'legal_review' THEN 2
      WHEN 'signoff' THEN 3
      WHEN 'kickoff' THEN 4
      ELSE 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.milestone_distribution_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.milestone_distribution_r2619() TO authenticated;

-- RPC 6: monthly_pipeline_trend_r2619
CREATE OR REPLACE FUNCTION public.monthly_pipeline_trend_r2619()
RETURNS TABLE (
  month_label text,
  contracts_added bigint,
  total_value_rupees bigint,
  weighted_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', c.created_at), 'YYYY-MM') AS month_label,
         count(*)::bigint,
         COALESCE(sum(c.total_value_rupees), 0)::bigint,
         COALESCE(sum((c.total_value_rupees * c.win_probability_pct) / 100), 0)::bigint
  FROM public.chain_multi_year_contracts_r2619 c
  GROUP BY date_trunc('month', c.created_at)
  ORDER BY date_trunc('month', c.created_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2619() TO authenticated;

-- RPC 7: win_probability_summary_r2619
CREATE OR REPLACE FUNCTION public.win_probability_summary_r2619()
RETURNS TABLE (
  probability_band text,
  total bigint,
  total_value_rupees bigint,
  weighted_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH banded AS (
    SELECT
      CASE
        WHEN c.win_probability_pct >= 75 THEN 'high_75_plus'
        WHEN c.win_probability_pct >= 50 THEN 'mid_50_74'
        WHEN c.win_probability_pct >= 25 THEN 'low_25_49'
        ELSE 'cold_below_25'
      END AS probability_band,
      c.total_value_rupees,
      c.win_probability_pct
    FROM public.chain_multi_year_contracts_r2619 c
    WHERE c.status IN ('prospecting','proposed','negotiating')
  )
  SELECT b.probability_band,
         count(*)::bigint,
         COALESCE(sum(b.total_value_rupees), 0)::bigint,
         COALESCE(sum((b.total_value_rupees * b.win_probability_pct) / 100), 0)::bigint
  FROM banded b
  GROUP BY b.probability_band
  ORDER BY
    CASE b.probability_band
      WHEN 'high_75_plus' THEN 0
      WHEN 'mid_50_74' THEN 1
      WHEN 'low_25_49' THEN 2
      WHEN 'cold_below_25' THEN 3
      ELSE 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.win_probability_summary_r2619() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.win_probability_summary_r2619() TO authenticated;
