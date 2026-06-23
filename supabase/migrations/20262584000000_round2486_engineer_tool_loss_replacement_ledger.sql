-- Round 2486: engineer-tool-loss-replacement-ledger
-- Tables: engineer_tool_losses_r2486, tool_loss_repeat_offenders_r2486

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tool_losses_r2486 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  tool_name text NOT NULL,
  tool_kind text NOT NULL CHECK (tool_kind IN ('multimeter','scope','calibrator','hand_tool','safety_gear','specialty_imaging')),
  loss_at timestamptz,
  loss_reason_kind text NOT NULL CHECK (loss_reason_kind IN ('left_at_site','stolen','damaged','forgotten','lost_in_transit')),
  replacement_cost_rupees int NOT NULL DEFAULT 0 CHECK (replacement_cost_rupees >= 0),
  insurance_claim_filed boolean NOT NULL DEFAULT false,
  insurance_recovery_rupees int NOT NULL DEFAULT 0 CHECK (insurance_recovery_rupees >= 0),
  repeat_offender boolean NOT NULL DEFAULT false,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','replaced','written_off','disputed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tool_loss_repeat_offenders_r2486 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  loss_count int NOT NULL DEFAULT 0 CHECK (loss_count >= 0),
  total_replacement_rupees bigint NOT NULL DEFAULT 0 CHECK (total_replacement_rupees >= 0),
  top_loss_kind text,
  action_plan_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tool_losses_r2486 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tool_loss_repeat_offenders_r2486 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_tool_losses_r2486;
CREATE POLICY founder_all ON public.engineer_tool_losses_r2486
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.tool_loss_repeat_offenders_r2486;
CREATE POLICY founder_all ON public.tool_loss_repeat_offenders_r2486
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed losses
INSERT INTO public.engineer_tool_losses_r2486
  (tool_name, tool_kind, loss_at, loss_reason_kind, replacement_cost_rupees, insurance_claim_filed, insurance_recovery_rupees, repeat_offender, owner_email, status, notes)
VALUES
  ('Fluke 87V Multimeter', 'multimeter', '2026-05-12T11:00:00Z'::timestamptz, 'left_at_site', 38000, true, 28000, false, 'ops@equipseva.in', 'replaced', 'Left at Apollo Hyd site; insurance partial recovery'),
  ('Tektronix TBS1052B Oscilloscope', 'scope', '2026-04-22T15:30:00Z'::timestamptz, 'stolen', 95000, true, 72000, true, 'ops@equipseva.in', 'replaced', 'Stolen from van at Vizag; FIR filed'),
  ('Pressure Calibrator Druck DPI', 'calibrator', '2026-06-02T09:00:00Z'::timestamptz, 'damaged', 142000, true, 0, false, 'ops@equipseva.in', 'disputed', 'Damaged in transit; insurer disputes claim'),
  ('Insulated Screwdriver Set', 'hand_tool', '2026-06-10T13:00:00Z'::timestamptz, 'forgotten', 4500, false, 0, true, 'ops@equipseva.in', 'replaced', 'Forgotten at hospital storeroom'),
  ('Arc-flash PPE Kit', 'safety_gear', '2026-06-15T16:00:00Z'::timestamptz, 'lost_in_transit', 32000, true, 24000, false, 'safety@equipseva.in', 'open', 'Lost between Hyderabad-Bangalore route'),
  ('Portable Ultrasound Probe (loaner)', 'specialty_imaging', '2026-06-18T10:00:00Z'::timestamptz, 'damaged', 285000, true, 0, false, 'ops@equipseva.in', 'open', 'Probe cracked during demo; OEM evaluating'),
  ('Cheap Knock-off Multimeter', 'multimeter', '2026-06-20T14:00:00Z'::timestamptz, 'damaged', 1500, false, 0, false, 'ops@equipseva.in', 'written_off', 'Not worth replacing — moving to Fluke standard');

-- Seed repeat offenders
INSERT INTO public.tool_loss_repeat_offenders_r2486
  (period_start, period_end, loss_count, total_replacement_rupees, top_loss_kind, action_plan_md, owner_email, status, notes)
VALUES
  ('2026-04-01'::date, '2026-06-30'::date, 4, 142000, 'hand_tool', 'Engineer paired with senior for 30 days; tool checkout sheet mandatory', 'people@equipseva.in', 'in_progress', 'Engineer A — 4 losses in Q2'),
  ('2026-04-01'::date, '2026-06-30'::date, 3, 99500, 'scope', 'Issued personal locker + checklist before van exit', 'people@equipseva.in', 'open', 'Engineer B — 3 losses incl Tek scope'),
  ('2026-01-01'::date, '2026-03-31'::date, 2, 8000, 'hand_tool', 'Coached; situation resolved in Q1', 'people@equipseva.in', 'closed', 'Engineer C — closed after Q1 coaching'),
  ('2026-04-01'::date, '2026-06-30'::date, 2, 47500, 'safety_gear', 'Counselled; safety gear tagged with engineer name', 'safety@equipseva.in', 'in_progress', 'Engineer D — repeated PPE losses'),
  ('2026-01-01'::date, '2026-06-30'::date, 5, 320000, 'specialty_imaging', 'Removed from imaging-tool eligibility list', 'ops@equipseva.in', 'dropped', 'Engineer E — escalated; banned from imaging tools');

-- RPC 1: list losses
CREATE OR REPLACE FUNCTION public.list_losses_r2486()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  tool_name text,
  tool_kind text,
  loss_at timestamptz,
  loss_reason_kind text,
  replacement_cost_rupees int,
  insurance_claim_filed boolean,
  insurance_recovery_rupees int,
  repeat_offender boolean,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.engineer_user_id, l.tool_name, l.tool_kind, l.loss_at,
         l.loss_reason_kind, l.replacement_cost_rupees, l.insurance_claim_filed,
         l.insurance_recovery_rupees, l.repeat_offender, l.owner_email, l.status, l.notes
  FROM public.engineer_tool_losses_r2486 l
  ORDER BY l.loss_at DESC NULLS LAST, l.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_losses_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_losses_r2486() TO authenticated;

-- RPC 2: list repeat offenders
CREATE OR REPLACE FUNCTION public.list_repeat_offenders_r2486()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  period_start date,
  period_end date,
  loss_count int,
  total_replacement_rupees bigint,
  top_loss_kind text,
  action_plan_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.engineer_user_id, o.period_start, o.period_end, o.loss_count,
         o.total_replacement_rupees, o.top_loss_kind, o.action_plan_md,
         o.owner_email, o.status, o.notes
  FROM public.tool_loss_repeat_offenders_r2486 o
  ORDER BY o.total_replacement_rupees DESC, o.loss_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_repeat_offenders_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_repeat_offenders_r2486() TO authenticated;

-- RPC 3: top loss engineers
CREATE OR REPLACE FUNCTION public.top_loss_engineers_r2486()
RETURNS TABLE (
  engineer_user_id uuid,
  loss_count bigint,
  total_replacement_rupees bigint,
  total_recovered_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.engineer_user_id,
         COUNT(*)::bigint AS loss_count,
         SUM(l.replacement_cost_rupees)::bigint AS total_replacement_rupees,
         SUM(l.insurance_recovery_rupees)::bigint AS total_recovered_rupees
  FROM public.engineer_tool_losses_r2486 l
  WHERE l.engineer_user_id IS NOT NULL
  GROUP BY l.engineer_user_id
  ORDER BY total_replacement_rupees DESC NULLS LAST, loss_count DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_loss_engineers_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loss_engineers_r2486() TO authenticated;

-- RPC 4: monthly replacement trend
CREATE OR REPLACE FUNCTION public.monthly_replacement_trend_r2486()
RETURNS TABLE (
  month_start date,
  loss_count bigint,
  total_replacement_rupees bigint,
  total_recovered_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', COALESCE(l.loss_at, l.created_at))::date AS month_start,
         COUNT(*)::bigint AS loss_count,
         SUM(l.replacement_cost_rupees)::bigint AS total_replacement_rupees,
         SUM(l.insurance_recovery_rupees)::bigint AS total_recovered_rupees
  FROM public.engineer_tool_losses_r2486 l
  GROUP BY month_start
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_replacement_trend_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_replacement_trend_r2486() TO authenticated;

-- RPC 5: loss kind breakdown
CREATE OR REPLACE FUNCTION public.loss_kind_breakdown_r2486()
RETURNS TABLE (
  loss_reason_kind text,
  loss_count bigint,
  total_replacement_rupees bigint,
  total_recovered_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.loss_reason_kind,
         COUNT(*)::bigint AS loss_count,
         SUM(l.replacement_cost_rupees)::bigint AS total_replacement_rupees,
         SUM(l.insurance_recovery_rupees)::bigint AS total_recovered_rupees
  FROM public.engineer_tool_losses_r2486 l
  GROUP BY l.loss_reason_kind
  ORDER BY total_replacement_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.loss_kind_breakdown_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.loss_kind_breakdown_r2486() TO authenticated;

-- RPC 6: insurance recovery summary
CREATE OR REPLACE FUNCTION public.insurance_recovery_summary_r2486()
RETURNS TABLE (
  claims_filed bigint,
  claims_not_filed bigint,
  total_loss_rupees bigint,
  total_recovered_rupees bigint,
  recovery_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE l.insurance_claim_filed)::bigint AS claims_filed,
    COUNT(*) FILTER (WHERE NOT l.insurance_claim_filed)::bigint AS claims_not_filed,
    SUM(l.replacement_cost_rupees)::bigint AS total_loss_rupees,
    SUM(l.insurance_recovery_rupees)::bigint AS total_recovered_rupees,
    CASE
      WHEN SUM(l.replacement_cost_rupees) > 0
        THEN ROUND((SUM(l.insurance_recovery_rupees)::numeric / SUM(l.replacement_cost_rupees)::numeric) * 100.0, 2)
      ELSE 0
    END AS recovery_rate_pct
  FROM public.engineer_tool_losses_r2486 l;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.insurance_recovery_summary_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.insurance_recovery_summary_r2486() TO authenticated;

-- RPC 7: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2486()
RETURNS TABLE (
  status text,
  loss_count bigint,
  total_replacement_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.status,
         COUNT(*)::bigint AS loss_count,
         SUM(l.replacement_cost_rupees)::bigint AS total_replacement_rupees
  FROM public.engineer_tool_losses_r2486 l
  GROUP BY l.status
  ORDER BY loss_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2486() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2486() TO authenticated;

