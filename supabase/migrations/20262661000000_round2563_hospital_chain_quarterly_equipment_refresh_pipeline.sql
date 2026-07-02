-- r2563 hospital chain quarterly equipment refresh pipeline
-- Tracks chain-wide quarterly refresh windows: new purchases, upgrades, replacements, loaner swaps.
-- Founder uses this to forecast revenue and orchestrate milestones across multi-site chains.

CREATE TABLE IF NOT EXISTS public.chain_quarterly_refresh_pipeline_r2563 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  refresh_kind text NOT NULL CHECK (refresh_kind IN ('new_purchase','upgrade','replacement','loaner_swap')),
  equipment_kind text NOT NULL,
  pipeline_value_rupees bigint NOT NULL DEFAULT 0,
  decision_kind text NOT NULL CHECK (decision_kind IN ('approved','rejected','postponed','in_negotiation')),
  scheduled_at timestamptz,
  owner_email text,
  status text NOT NULL CHECK (status IN ('monitoring','proposed','approved','scheduled','installed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.refresh_pipeline_milestones_r2563 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.chain_quarterly_refresh_pipeline_r2563(id) ON DELETE CASCADE,
  milestone_kind text NOT NULL CHECK (milestone_kind IN ('kickoff','quote','po','delivery','install','go_live')),
  planned_at timestamptz,
  actual_at timestamptz,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_quarterly_refresh_pipeline_r2563 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refresh_pipeline_milestones_r2563 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_quarterly_refresh_pipeline_r2563;
CREATE POLICY founder_all ON public.chain_quarterly_refresh_pipeline_r2563
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.refresh_pipeline_milestones_r2563;
CREATE POLICY founder_all ON public.refresh_pipeline_milestones_r2563
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed pipeline rows
INSERT INTO public.chain_quarterly_refresh_pipeline_r2563
  (chain_name, quarter_label, refresh_kind, equipment_kind, pipeline_value_rupees, decision_kind, scheduled_at, owner_email, status, notes)
VALUES
  ('Apollo Chain', 'Q2-FY27', 'new_purchase', 'CT scanner 64-slice', 18500000, 'approved', now() + interval '14 days', 'apollo.cmo@apollo.in', 'scheduled', 'Two new sites Hyderabad + Chennai'),
  ('Manipal Chain', 'Q2-FY27', 'upgrade', 'ultrasound color doppler', 4200000, 'in_negotiation', now() + interval '30 days', 'manipal.biomed@manipal.in', 'proposed', 'Awaiting board sign-off'),
  ('Fortis Chain', 'Q2-FY27', 'replacement', 'cath lab', 32000000, 'approved', now() + interval '45 days', 'fortis.bme@fortis.in', 'approved', 'PO drafted'),
  ('KIMS Chain', 'Q3-FY27', 'loaner_swap', 'ventilator x12', 0, 'approved', now() + interval '60 days', 'kims.biomed@kims.in', 'monitoring', 'Loaner during AMC repair window'),
  ('Yashoda Chain', 'Q2-FY27', 'new_purchase', 'MRI 3T', 75000000, 'postponed', NULL, 'yashoda.director@yashoda.in', 'monitoring', 'Postponed to FY28 budget cycle');

-- Seed milestones (single row each so we can RETURNING into scalar safely)
DO $seed$
DECLARE
  v_pipeline_id uuid;
BEGIN
  SELECT id INTO v_pipeline_id FROM public.chain_quarterly_refresh_pipeline_r2563 WHERE chain_name = 'Apollo Chain' AND equipment_kind = 'CT scanner 64-slice' LIMIT 1;
  IF v_pipeline_id IS NOT NULL THEN
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'kickoff', now() - interval '20 days', now() - interval '18 days', 'ops@equipseva.com', 'done', 'kickoff call complete');
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'quote', now() - interval '10 days', now() - interval '8 days', 'sales@equipseva.com', 'done', 'quote shared');
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'po', now() + interval '5 days', NULL, 'sales@equipseva.com', 'open', 'awaiting PO');
  END IF;

  SELECT id INTO v_pipeline_id FROM public.chain_quarterly_refresh_pipeline_r2563 WHERE chain_name = 'Fortis Chain' LIMIT 1;
  IF v_pipeline_id IS NOT NULL THEN
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'kickoff', now() - interval '5 days', now() - interval '4 days', 'ops@equipseva.com', 'done', 'cath lab kickoff');
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'delivery', now() + interval '40 days', NULL, 'logistics@equipseva.com', 'open', 'delivery slot reserved');
  END IF;

  SELECT id INTO v_pipeline_id FROM public.chain_quarterly_refresh_pipeline_r2563 WHERE chain_name = 'Manipal Chain' LIMIT 1;
  IF v_pipeline_id IS NOT NULL THEN
    INSERT INTO public.refresh_pipeline_milestones_r2563 (pipeline_id, milestone_kind, planned_at, actual_at, owner_email, status, notes)
    VALUES (v_pipeline_id, 'quote', now() - interval '2 days', now() - interval '1 day', 'sales@equipseva.com', 'done', 'quote v2 shared');
  END IF;
END $seed$;

-- RPC 1: list pipeline
CREATE OR REPLACE FUNCTION public.list_pipeline_r2563()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  quarter_label text,
  refresh_kind text,
  equipment_kind text,
  pipeline_value_rupees bigint,
  decision_kind text,
  scheduled_at timestamptz,
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
    SELECT p.id, p.chain_name, p.hospital_user_id, p.quarter_label, p.refresh_kind,
           p.equipment_kind, p.pipeline_value_rupees, p.decision_kind, p.scheduled_at,
           p.owner_email, p.status, p.notes, p.created_at
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    ORDER BY p.scheduled_at ASC NULLS LAST, p.pipeline_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pipeline_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_r2563() TO authenticated;

-- RPC 2: list milestones
CREATE OR REPLACE FUNCTION public.list_milestones_r2563()
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  chain_name text,
  equipment_kind text,
  milestone_kind text,
  planned_at timestamptz,
  actual_at timestamptz,
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
    SELECT m.id, m.pipeline_id, p.chain_name, p.equipment_kind, m.milestone_kind,
           m.planned_at, m.actual_at, m.owner_email, m.status, m.notes
    FROM public.refresh_pipeline_milestones_r2563 m
    JOIN public.chain_quarterly_refresh_pipeline_r2563 p ON p.id = m.pipeline_id
    ORDER BY m.planned_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r2563() TO authenticated;

-- RPC 3: top value refreshes
CREATE OR REPLACE FUNCTION public.top_value_refreshes_r2563()
RETURNS TABLE (
  chain_name text,
  equipment_kind text,
  refresh_kind text,
  pipeline_value_rupees bigint,
  status text,
  scheduled_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.chain_name, p.equipment_kind, p.refresh_kind, p.pipeline_value_rupees, p.status, p.scheduled_at
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    ORDER BY p.pipeline_value_rupees DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_value_refreshes_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_refreshes_r2563() TO authenticated;

-- RPC 4: refresh kind breakdown
CREATE OR REPLACE FUNCTION public.refresh_kind_breakdown_r2563()
RETURNS TABLE (
  refresh_kind text,
  pipeline_count bigint,
  total_value_rupees bigint,
  approved_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.refresh_kind,
           count(*)::bigint AS pipeline_count,
           coalesce(sum(p.pipeline_value_rupees), 0)::bigint AS total_value_rupees,
           count(*) FILTER (WHERE p.decision_kind = 'approved')::bigint AS approved_count
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    GROUP BY p.refresh_kind
    ORDER BY total_value_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refresh_kind_breakdown_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_kind_breakdown_r2563() TO authenticated;

-- RPC 5: decision distribution
CREATE OR REPLACE FUNCTION public.decision_distribution_r2563()
RETURNS TABLE (
  decision_kind text,
  pipeline_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.decision_kind,
           count(*)::bigint AS pipeline_count,
           coalesce(sum(p.pipeline_value_rupees), 0)::bigint AS total_value_rupees
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    GROUP BY p.decision_kind
    ORDER BY pipeline_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_distribution_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_distribution_r2563() TO authenticated;

-- RPC 6: scheduled focus (upcoming 90 days)
CREATE OR REPLACE FUNCTION public.scheduled_focus_r2563()
RETURNS TABLE (
  chain_name text,
  equipment_kind text,
  refresh_kind text,
  scheduled_at timestamptz,
  pipeline_value_rupees bigint,
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
    SELECT p.chain_name, p.equipment_kind, p.refresh_kind, p.scheduled_at,
           p.pipeline_value_rupees, p.status, p.owner_email
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    WHERE p.scheduled_at IS NOT NULL
      AND p.scheduled_at BETWEEN now() AND now() + interval '90 days'
    ORDER BY p.scheduled_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.scheduled_focus_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scheduled_focus_r2563() TO authenticated;

-- RPC 7: monthly pipeline trend
CREATE OR REPLACE FUNCTION public.monthly_pipeline_trend_r2563()
RETURNS TABLE (
  month_start timestamptz,
  pipeline_count bigint,
  total_value_rupees bigint,
  approved_value_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', coalesce(p.scheduled_at, p.created_at))::timestamptz AS month_start,
           count(*)::bigint AS pipeline_count,
           coalesce(sum(p.pipeline_value_rupees), 0)::bigint AS total_value_rupees,
           coalesce(sum(p.pipeline_value_rupees) FILTER (WHERE p.decision_kind = 'approved'), 0)::bigint AS approved_value_rupees
    FROM public.chain_quarterly_refresh_pipeline_r2563 p
    GROUP BY date_trunc('month', coalesce(p.scheduled_at, p.created_at))
    ORDER BY month_start ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2563() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pipeline_trend_r2563() TO authenticated;
