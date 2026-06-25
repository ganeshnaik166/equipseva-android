-- r2659 hospital-chain-quarterly-renewal-risk-radar

CREATE TABLE IF NOT EXISTS public.chain_renewal_risk_radar_r2659 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  renewal_due_at timestamptz NOT NULL,
  risk_kind text NOT NULL CHECK (risk_kind IN ('low','medium','high','critical')),
  risk_signals_md text,
  mitigation_plan_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','intervening','renewed','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.renewal_risk_mitigation_actions_r2659 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_id uuid NOT NULL REFERENCES public.chain_renewal_risk_radar_r2659(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('price_lock','exec_dinner','data_review','early_renewal','loyalty_bonus')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_renewal_risk_radar_r2659 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renewal_risk_mitigation_actions_r2659 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_renewal_risk_radar_r2659;
CREATE POLICY founder_all ON public.chain_renewal_risk_radar_r2659
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.renewal_risk_mitigation_actions_r2659;
CREATE POLICY founder_all ON public.renewal_risk_mitigation_actions_r2659
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.chain_renewal_risk_radar_r2659 (chain_name, quarter_label, renewal_due_at, risk_kind, risk_signals_md, mitigation_plan_md, owner_email, status, notes) VALUES
  ('Apollo Multi-City', 'Q3-2026', '2026-09-30T00:00:00Z'::timestamptz, 'critical', 'CTO escalated downtime; SLA breach 3x in Q2', 'Exec dinner + price lock + early renewal discount 8 percent', 'gm@equipseva.in', 'intervening', 'Top ARR account; cannot lose'),
  ('Manipal Group', 'Q3-2026', '2026-08-15T00:00:00Z'::timestamptz, 'high', 'Procurement RFQ floated to 2 competitors', 'Data review session with CFO; show uptime advantage', 'sales@equipseva.in', 'intervening', 'Competitive bake-off'),
  ('Fortis Network', 'Q4-2026', '2026-11-30T00:00:00Z'::timestamptz, 'medium', 'New CIO from competitor background', 'Loyalty bonus offer; quarterly NABH report briefing', 'csm@equipseva.in', 'monitoring', 'Watch CIO orientation'),
  ('Yashoda Hospitals', 'Q3-2026', '2026-09-10T00:00:00Z'::timestamptz, 'low', 'High NPS; CFO endorses', 'Standard renewal flow; surprise loyalty credit', 'ops@equipseva.in', 'monitoring', 'Reference customer'),
  ('Kims Healthcare', 'Q4-2026', '2026-12-20T00:00:00Z'::timestamptz, 'high', 'Two engineer ratings under 3 stars last quarter', 'Engineer swap + ops review; show NABH ZIP', 'success@equipseva.in', 'intervening', 'Engineer rotation locked in');

INSERT INTO public.renewal_risk_mitigation_actions_r2659 (risk_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'price_lock', 'positive', 'gm@equipseva.in', 'done', 'Locked at 8 percent discount for 2 years' FROM public.chain_renewal_risk_radar_r2659 WHERE chain_name = 'Apollo Multi-City' LIMIT 1;

INSERT INTO public.renewal_risk_mitigation_actions_r2659 (risk_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'exec_dinner', 'pending', 'gm@equipseva.in', 'open', 'Scheduled with CTO next week' FROM public.chain_renewal_risk_radar_r2659 WHERE chain_name = 'Apollo Multi-City' LIMIT 1;

INSERT INTO public.renewal_risk_mitigation_actions_r2659 (risk_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'data_review', 'neutral', 'sales@equipseva.in', 'done', 'CFO reviewed uptime dashboard' FROM public.chain_renewal_risk_radar_r2659 WHERE chain_name = 'Manipal Group' LIMIT 1;

INSERT INTO public.renewal_risk_mitigation_actions_r2659 (risk_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'loyalty_bonus', 'pending', 'csm@equipseva.in', 'open', 'Offer drafted; pending CIO meeting' FROM public.chain_renewal_risk_radar_r2659 WHERE chain_name = 'Fortis Network' LIMIT 1;

INSERT INTO public.renewal_risk_mitigation_actions_r2659 (risk_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'early_renewal', 'positive', 'success@equipseva.in', 'done', 'Renewed 60 days early at standard terms' FROM public.chain_renewal_risk_radar_r2659 WHERE chain_name = 'Kims Healthcare' LIMIT 1;

-- RPC 1: list_renewal_risk_r2659
CREATE OR REPLACE FUNCTION public.list_renewal_risk_r2659()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  renewal_due_at timestamptz,
  risk_kind text,
  status text,
  owner_email text,
  risk_signals_md text,
  mitigation_plan_md text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.quarter_label, r.renewal_due_at, r.risk_kind,
         r.status, r.owner_email, r.risk_signals_md, r.mitigation_plan_md, r.notes, r.created_at
  FROM public.chain_renewal_risk_radar_r2659 r
  ORDER BY r.renewal_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_renewal_risk_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renewal_risk_r2659() TO authenticated;

-- RPC 2: list_mitigation_actions_r2659
CREATE OR REPLACE FUNCTION public.list_mitigation_actions_r2659()
RETURNS TABLE (
  id uuid,
  chain_name text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, r.chain_name, a.action_at, a.action_kind, a.outcome, a.status, a.owner_email, a.notes
  FROM public.renewal_risk_mitigation_actions_r2659 a
  JOIN public.chain_renewal_risk_radar_r2659 r ON r.id = a.risk_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_mitigation_actions_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_mitigation_actions_r2659() TO authenticated;

-- RPC 3: top_critical_focus_r2659
CREATE OR REPLACE FUNCTION public.top_critical_focus_r2659()
RETURNS TABLE (
  chain_name text,
  quarter_label text,
  renewal_due_at timestamptz,
  risk_kind text,
  status text,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.chain_name, r.quarter_label, r.renewal_due_at, r.risk_kind, r.status,
         (SELECT count(*) FROM public.renewal_risk_mitigation_actions_r2659 a
          WHERE a.risk_id = r.id AND a.status = 'open')
  FROM public.chain_renewal_risk_radar_r2659 r
  WHERE r.risk_kind IN ('critical','high') AND r.status IN ('monitoring','intervening')
  ORDER BY CASE r.risk_kind WHEN 'critical' THEN 0 WHEN 'high' THEN 1 ELSE 2 END, r.renewal_due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_critical_focus_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_critical_focus_r2659() TO authenticated;

-- RPC 4: risk_distribution_r2659
CREATE OR REPLACE FUNCTION public.risk_distribution_r2659()
RETURNS TABLE (
  risk_kind text,
  total bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.risk_kind, count(*)::bigint
  FROM public.chain_renewal_risk_radar_r2659 r
  GROUP BY r.risk_kind
  ORDER BY CASE r.risk_kind WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.risk_distribution_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.risk_distribution_r2659() TO authenticated;

-- RPC 5: status_funnel_r2659
CREATE OR REPLACE FUNCTION public.status_funnel_r2659()
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
  FROM public.chain_renewal_risk_radar_r2659 r
  GROUP BY r.status
  ORDER BY CASE r.status WHEN 'intervening' THEN 0 WHEN 'monitoring' THEN 1 WHEN 'renewed' THEN 2 ELSE 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2659() TO authenticated;

-- RPC 6: quarterly_risk_trend_r2659
CREATE OR REPLACE FUNCTION public.quarterly_risk_trend_r2659()
RETURNS TABLE (
  quarter_label text,
  critical_count bigint,
  high_count bigint,
  medium_count bigint,
  low_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.quarter_label,
         count(*) FILTER (WHERE r.risk_kind = 'critical')::bigint,
         count(*) FILTER (WHERE r.risk_kind = 'high')::bigint,
         count(*) FILTER (WHERE r.risk_kind = 'medium')::bigint,
         count(*) FILTER (WHERE r.risk_kind = 'low')::bigint
  FROM public.chain_renewal_risk_radar_r2659 r
  GROUP BY r.quarter_label
  ORDER BY r.quarter_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_risk_trend_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_risk_trend_r2659() TO authenticated;

-- RPC 7: owner_load_r2659
CREATE OR REPLACE FUNCTION public.owner_load_r2659()
RETURNS TABLE (
  owner_email text,
  active_risks bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.owner_email,'(unassigned)') AS owner_email,
         count(*)::bigint AS active_risks,
         (SELECT count(*) FROM public.renewal_risk_mitigation_actions_r2659 a
          WHERE a.owner_email = r.owner_email AND a.status = 'open')::bigint
  FROM public.chain_renewal_risk_radar_r2659 r
  WHERE r.status IN ('monitoring','intervening')
  GROUP BY r.owner_email
  ORDER BY active_risks DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2659() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2659() TO authenticated;
