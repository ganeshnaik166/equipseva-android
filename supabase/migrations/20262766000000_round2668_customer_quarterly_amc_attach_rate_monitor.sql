-- Round 2668: Customer Quarterly AMC Attach Rate Monitor
-- Track AMC attach rate per hospital per quarter and improvement actions.

BEGIN;

-- =========================================================================
-- TABLE 1: customer_amc_attach_r2668
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.customer_amc_attach_r2668 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  equipment_count int NOT NULL DEFAULT 0,
  amc_signed_count int NOT NULL DEFAULT 0,
  attach_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  target_attach_pct numeric(5,2) NOT NULL DEFAULT 60,
  owner_email text,
  status text NOT NULL DEFAULT 'below_target' CHECK (status IN ('below_target','at_target','above_target','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_caa_r2668_hospital ON public.customer_amc_attach_r2668(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_caa_r2668_quarter ON public.customer_amc_attach_r2668(quarter_label);
CREATE INDEX IF NOT EXISTS idx_caa_r2668_status ON public.customer_amc_attach_r2668(status);
CREATE INDEX IF NOT EXISTS idx_caa_r2668_attach_rate ON public.customer_amc_attach_r2668(attach_rate_pct);

ALTER TABLE public.customer_amc_attach_r2668 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_amc_attach_r2668;
CREATE POLICY founder_all ON public.customer_amc_attach_r2668
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: amc_attach_improvement_actions_r2668
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.amc_attach_improvement_actions_r2668 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attach_id uuid NOT NULL REFERENCES public.customer_amc_attach_r2668(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('bulk_quote','discount','exec_pitch','training','value_story')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aaia_r2668_attach ON public.amc_attach_improvement_actions_r2668(attach_id);
CREATE INDEX IF NOT EXISTS idx_aaia_r2668_status ON public.amc_attach_improvement_actions_r2668(status);
CREATE INDEX IF NOT EXISTS idx_aaia_r2668_outcome ON public.amc_attach_improvement_actions_r2668(outcome);
CREATE INDEX IF NOT EXISTS idx_aaia_r2668_action_at ON public.amc_attach_improvement_actions_r2668(action_at);

ALTER TABLE public.amc_attach_improvement_actions_r2668 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.amc_attach_improvement_actions_r2668;
CREATE POLICY founder_all ON public.amc_attach_improvement_actions_r2668
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
INSERT INTO public.customer_amc_attach_r2668
  (quarter_label, equipment_count, amc_signed_count, attach_rate_pct, target_attach_pct, owner_email, status, notes)
VALUES
  ('Q1 FY27', 40, 12, 30.00, 60.00, 'cs@equipseva.in', 'below_target', 'Apollo network slow ramp on AMC bundling'),
  ('Q1 FY27', 28, 22, 78.57, 60.00, 'cs@equipseva.in', 'above_target', 'Star Care exec sponsorship landed Q1'),
  ('Q4 FY26', 35, 18, 51.43, 60.00, 'cs@equipseva.in', 'below_target', 'Manipal pushback on annual prepay'),
  ('Q4 FY26', 22, 14, 63.64, 60.00, 'cs@equipseva.in', 'at_target', 'Yashoda baseline holding'),
  ('Q3 FY26', 18, 4, 22.22, 60.00, 'cs@equipseva.in', 'dropped', 'Tier3 client dropped after price hike');

INSERT INTO public.amc_attach_improvement_actions_r2668
  (attach_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '15 days', 'exec_pitch', 'positive', 'cs@equipseva.in', 'done', 'CEO breakfast meet locked 6 AMCs'
FROM public.customer_amc_attach_r2668 WHERE quarter_label = 'Q1 FY27' AND status = 'below_target' LIMIT 1;

INSERT INTO public.amc_attach_improvement_actions_r2668
  (attach_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '30 days', 'bulk_quote', 'pending', 'cs@equipseva.in', 'open', 'Proposal sent for 20-unit bundle'
FROM public.customer_amc_attach_r2668 WHERE quarter_label = 'Q4 FY26' AND status = 'below_target' LIMIT 1;

INSERT INTO public.amc_attach_improvement_actions_r2668
  (attach_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '45 days', 'training', 'positive', 'cs@equipseva.in', 'done', 'Biomed team trained on AMC value story'
FROM public.customer_amc_attach_r2668 WHERE quarter_label = 'Q4 FY26' AND status = 'at_target' LIMIT 1;

INSERT INTO public.amc_attach_improvement_actions_r2668
  (attach_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '60 days', 'discount', 'negative', 'cs@equipseva.in', 'done', 'Discount offered but client still churned'
FROM public.customer_amc_attach_r2668 WHERE quarter_label = 'Q3 FY26' LIMIT 1;

INSERT INTO public.amc_attach_improvement_actions_r2668
  (attach_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '5 days', 'value_story', 'pending', 'cs@equipseva.in', 'open', 'Sharing uptime case study with procurement'
FROM public.customer_amc_attach_r2668 WHERE quarter_label = 'Q1 FY27' AND status = 'above_target' LIMIT 1;

-- =========================================================================
-- RPC 1: list_attach_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_attach_r2668();
CREATE FUNCTION public.list_attach_r2668()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  quarter_label text,
  equipment_count int,
  amc_signed_count int,
  attach_rate_pct numeric,
  target_attach_pct numeric,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, a.quarter_label, a.equipment_count, a.amc_signed_count,
         a.attach_rate_pct, a.target_attach_pct, a.owner_email, a.status, a.notes, a.created_at
  FROM public.customer_amc_attach_r2668 a
  ORDER BY a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attach_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attach_r2668() TO authenticated;

-- =========================================================================
-- RPC 2: list_improvement_actions_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_improvement_actions_r2668();
CREATE FUNCTION public.list_improvement_actions_r2668()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, a.quarter_label, i.action_at, i.action_kind, i.outcome,
         i.owner_email, i.status, i.notes
  FROM public.amc_attach_improvement_actions_r2668 i
  JOIN public.customer_amc_attach_r2668 a ON a.id = i.attach_id
  ORDER BY i.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_improvement_actions_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_improvement_actions_r2668() TO authenticated;

-- =========================================================================
-- RPC 3: top_below_target_focus_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_below_target_focus_r2668();
CREATE FUNCTION public.top_below_target_focus_r2668()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  equipment_count int,
  amc_signed_count int,
  attach_rate_pct numeric,
  target_attach_pct numeric,
  status text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.quarter_label, a.equipment_count, a.amc_signed_count,
         a.attach_rate_pct, a.target_attach_pct, a.status, a.owner_email
  FROM public.customer_amc_attach_r2668 a
  WHERE a.status IN ('below_target','dropped')
  ORDER BY a.attach_rate_pct ASC, a.created_at DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_below_target_focus_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_below_target_focus_r2668() TO authenticated;

-- =========================================================================
-- RPC 4: status_distribution_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_distribution_r2668();
CREATE FUNCTION public.status_distribution_r2668()
RETURNS TABLE (
  status text,
  attach_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, count(*)::bigint
  FROM public.customer_amc_attach_r2668 a
  GROUP BY a.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2668() TO authenticated;

-- =========================================================================
-- RPC 5: status_funnel_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_funnel_r2668();
CREATE FUNCTION public.status_funnel_r2668()
RETURNS TABLE (
  status text,
  action_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.status, count(*)::bigint
  FROM public.amc_attach_improvement_actions_r2668 i
  GROUP BY i.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2668() TO authenticated;

-- =========================================================================
-- RPC 6: quarterly_attach_trend_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.quarterly_attach_trend_r2668();
CREATE FUNCTION public.quarterly_attach_trend_r2668()
RETURNS TABLE (
  quarter_label text,
  total_records bigint,
  total_equipment bigint,
  total_amc_signed bigint,
  avg_attach_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.quarter_label,
         count(*)::bigint,
         coalesce(sum(a.equipment_count), 0)::bigint,
         coalesce(sum(a.amc_signed_count), 0)::bigint,
         round(coalesce(avg(a.attach_rate_pct), 0)::numeric, 2)
  FROM public.customer_amc_attach_r2668 a
  GROUP BY a.quarter_label
  ORDER BY a.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_attach_trend_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_attach_trend_r2668() TO authenticated;

-- =========================================================================
-- RPC 7: owner_load_r2668
-- =========================================================================
DROP FUNCTION IF EXISTS public.owner_load_r2668();
CREATE FUNCTION public.owner_load_r2668()
RETURNS TABLE (
  owner_email text,
  attach_records bigint,
  open_actions bigint,
  avg_attach_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.owner_email,
         count(DISTINCT a.id)::bigint,
         count(DISTINCT i.id) FILTER (WHERE i.status = 'open')::bigint,
         round(coalesce(avg(a.attach_rate_pct), 0)::numeric, 2)
  FROM public.customer_amc_attach_r2668 a
  LEFT JOIN public.amc_attach_improvement_actions_r2668 i ON i.attach_id = a.id
  GROUP BY a.owner_email
  ORDER BY count(DISTINCT a.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2668() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2668() TO authenticated;

COMMIT;
