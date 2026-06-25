-- Round 2615: Hospital chain board resolution tracker
-- Two tables: chain_board_resolutions_r2615, resolution_response_actions_r2615
-- Seven RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.chain_board_resolutions_r2615 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_label text NOT NULL,
  passed_at timestamptz NOT NULL DEFAULT now(),
  resolution_kind text NOT NULL CHECK (resolution_kind IN ('capex','vendor_change','policy','pricing','staffing')),
  our_impact_kind text NOT NULL CHECK (our_impact_kind IN ('positive','neutral','negative','blocker')),
  action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.resolution_response_actions_r2615 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resolution_id uuid NOT NULL REFERENCES public.chain_board_resolutions_r2615(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('pitch','counter_pricing','exec_meet','walkaway','escalation')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_board_resolutions_r2615 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resolution_response_actions_r2615 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_board_resolutions_r2615;
CREATE POLICY founder_all ON public.chain_board_resolutions_r2615
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.resolution_response_actions_r2615;
CREATE POLICY founder_all ON public.resolution_response_actions_r2615
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data (no apostrophes in strings)
INSERT INTO public.chain_board_resolutions_r2615 (chain_name, resolution_label, passed_at, resolution_kind, our_impact_kind, action_md, owner_email, status, notes) VALUES
  ('Apollo North', 'Consolidate biomed vendors to 2 preferred partners', '2026-05-12 10:00:00'::timestamptz, 'vendor_change', 'blocker', 'Pitch tier-2 retention bundle to procurement head', 'founder@equipseva.in', 'in_progress', 'We are vendor 4 today; risk of exit'),
  ('Yashoda Group', 'Approve 4-crore CT scanner refresh capex', '2026-05-20 11:30:00'::timestamptz, 'capex', 'positive', 'Bid for AMC + install service contract', 'sales@equipseva.in', 'monitoring', 'Tender opens June'),
  ('Care Hospitals', 'Cap AMC spend at 1.2 percent of revenue', '2026-06-02 09:15:00'::timestamptz, 'pricing', 'negative', 'Counter with tiered pricing + outcomes guarantee', 'founder@equipseva.in', 'in_progress', 'Need to model 18 percent margin floor'),
  ('KIMS', 'Mandate next-day SLA for ICU equipment', '2026-06-10 14:00:00'::timestamptz, 'policy', 'positive', 'Highlight existing 12hr SLA in renewal pitch', 'ops@equipseva.in', 'closed', 'Renewal signed at premium tier'),
  ('Continental', 'Hire in-house biomed team of 6', '2026-06-15 16:45:00'::timestamptz, 'staffing', 'blocker', 'Position as overflow + niche-OEM support', 'founder@equipseva.in', 'monitoring', 'Hiring kicks off Q3');

INSERT INTO public.resolution_response_actions_r2615 (resolution_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-22 10:00:00'::timestamptz, 'pitch', 'neutral', 'founder@equipseva.in', 'done', 'Procurement open to demo'
FROM public.chain_board_resolutions_r2615 WHERE chain_name = 'Apollo North' LIMIT 1;

INSERT INTO public.resolution_response_actions_r2615 (resolution_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-05 13:00:00'::timestamptz, 'counter_pricing', 'pending', 'founder@equipseva.in', 'open', 'Sent revised tier sheet'
FROM public.chain_board_resolutions_r2615 WHERE chain_name = 'Care Hospitals' LIMIT 1;

INSERT INTO public.resolution_response_actions_r2615 (resolution_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12 11:00:00'::timestamptz, 'exec_meet', 'positive', 'ops@equipseva.in', 'done', 'COO confirmed renewal'
FROM public.chain_board_resolutions_r2615 WHERE chain_name = 'KIMS' LIMIT 1;

INSERT INTO public.resolution_response_actions_r2615 (resolution_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18 09:30:00'::timestamptz, 'escalation', 'pending', 'founder@equipseva.in', 'open', 'Flagged to board contact'
FROM public.chain_board_resolutions_r2615 WHERE chain_name = 'Continental' LIMIT 1;

-- RPC 1: list_resolutions_r2615
CREATE OR REPLACE FUNCTION public.list_resolutions_r2615()
RETURNS TABLE (
  id uuid,
  chain_name text,
  resolution_label text,
  passed_at timestamptz,
  resolution_kind text,
  our_impact_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.resolution_label, r.passed_at, r.resolution_kind,
         r.our_impact_kind, r.owner_email, r.status, r.notes
  FROM public.chain_board_resolutions_r2615 r
  ORDER BY r.passed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_resolutions_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_resolutions_r2615() TO authenticated;

-- RPC 2: list_response_actions_r2615
CREATE OR REPLACE FUNCTION public.list_response_actions_r2615()
RETURNS TABLE (
  id uuid,
  chain_name text,
  resolution_label text,
  action_at timestamptz,
  action_kind text,
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
  SELECT a.id, r.chain_name, r.resolution_label, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.resolution_response_actions_r2615 a
  JOIN public.chain_board_resolutions_r2615 r ON r.id = a.resolution_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_response_actions_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_response_actions_r2615() TO authenticated;

-- RPC 3: top_blocker_focus_r2615
CREATE OR REPLACE FUNCTION public.top_blocker_focus_r2615()
RETURNS TABLE (
  chain_name text,
  resolution_label text,
  resolution_kind text,
  passed_at timestamptz,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.resolution_label, r.resolution_kind, r.passed_at,
         r.owner_email, r.status
  FROM public.chain_board_resolutions_r2615 r
  WHERE r.our_impact_kind IN ('blocker','negative')
    AND r.status IN ('monitoring','in_progress')
  ORDER BY
    CASE r.our_impact_kind WHEN 'blocker' THEN 0 ELSE 1 END,
    r.passed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_blocker_focus_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_blocker_focus_r2615() TO authenticated;

-- RPC 4: resolution_kind_distribution_r2615
CREATE OR REPLACE FUNCTION public.resolution_kind_distribution_r2615()
RETURNS TABLE (
  resolution_kind text,
  total bigint,
  blocker_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.resolution_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE r.our_impact_kind = 'blocker')::bigint,
         count(*) FILTER (WHERE r.our_impact_kind = 'positive')::bigint
  FROM public.chain_board_resolutions_r2615 r
  GROUP BY r.resolution_kind
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.resolution_kind_distribution_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolution_kind_distribution_r2615() TO authenticated;

-- RPC 5: status_funnel_r2615
CREATE OR REPLACE FUNCTION public.status_funnel_r2615()
RETURNS TABLE (
  status text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, count(*)::bigint
  FROM public.chain_board_resolutions_r2615 r
  GROUP BY r.status
  ORDER BY
    CASE r.status
      WHEN 'monitoring' THEN 0
      WHEN 'in_progress' THEN 1
      WHEN 'closed' THEN 2
      WHEN 'dropped' THEN 3
      ELSE 4
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2615() TO authenticated;

-- RPC 6: monthly_resolution_trend_r2615
CREATE OR REPLACE FUNCTION public.monthly_resolution_trend_r2615()
RETURNS TABLE (
  month_label text,
  total bigint,
  blocker_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', r.passed_at), 'YYYY-MM') AS month_label,
         count(*)::bigint,
         count(*) FILTER (WHERE r.our_impact_kind = 'blocker')::bigint,
         count(*) FILTER (WHERE r.our_impact_kind = 'positive')::bigint
  FROM public.chain_board_resolutions_r2615 r
  GROUP BY date_trunc('month', r.passed_at)
  ORDER BY date_trunc('month', r.passed_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_resolution_trend_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_resolution_trend_r2615() TO authenticated;

-- RPC 7: owner_load_r2615
CREATE OR REPLACE FUNCTION public.owner_load_r2615()
RETURNS TABLE (
  owner_email text,
  open_resolutions bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH res AS (
    SELECT r.owner_email, count(*)::bigint AS c
    FROM public.chain_board_resolutions_r2615 r
    WHERE r.status IN ('monitoring','in_progress')
      AND r.owner_email IS NOT NULL
    GROUP BY r.owner_email
  ),
  act AS (
    SELECT a.owner_email, count(*)::bigint AS c
    FROM public.resolution_response_actions_r2615 a
    WHERE a.status = 'open'
      AND a.owner_email IS NOT NULL
    GROUP BY a.owner_email
  )
  SELECT COALESCE(res.owner_email, act.owner_email) AS owner_email,
         COALESCE(res.c, 0) AS open_resolutions,
         COALESCE(act.c, 0) AS open_actions
  FROM res
  FULL OUTER JOIN act ON res.owner_email = act.owner_email
  ORDER BY (COALESCE(res.c, 0) + COALESCE(act.c, 0)) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2615() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2615() TO authenticated;
