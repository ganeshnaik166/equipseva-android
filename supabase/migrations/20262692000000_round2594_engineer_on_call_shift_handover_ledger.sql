-- Round r2594: engineer-on-call-shift-handover-ledger
-- Tables: engineer_on_call_handovers_r2594, handover_discrepancy_resolution_r2594
-- 7 RPCs: list/breakdowns/trend/owner load

CREATE TABLE IF NOT EXISTS public.engineer_on_call_handovers_r2594 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  outgoing_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  incoming_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  handover_at timestamptz NOT NULL DEFAULT now(),
  shift_kind text NOT NULL CHECK (shift_kind IN ('day','night','weekend','code_red')),
  handover_items_count int NOT NULL DEFAULT 0,
  signoff_status text NOT NULL CHECK (signoff_status IN ('pending','complete','disputed')),
  discrepancies_count int NOT NULL DEFAULT 0,
  top_handover_item_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('scheduled','done','skipped')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.handover_discrepancy_resolution_r2594 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  handover_id uuid REFERENCES public.engineer_on_call_handovers_r2594(id) ON DELETE CASCADE,
  discrepancy_kind text NOT NULL CHECK (discrepancy_kind IN ('missed_step','wrong_part','missing_signoff','communication','data_gap')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  resolution_summary text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text
);

ALTER TABLE public.engineer_on_call_handovers_r2594 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handover_discrepancy_resolution_r2594 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_on_call_handovers_r2594;
CREATE POLICY founder_all ON public.engineer_on_call_handovers_r2594
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.handover_discrepancy_resolution_r2594;
CREATE POLICY founder_all ON public.handover_discrepancy_resolution_r2594
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.engineer_on_call_handovers_r2594 (handover_at, shift_kind, handover_items_count, signoff_status, discrepancies_count, top_handover_item_md, owner_email, status, notes) VALUES
  (now() - interval '1 day', 'day', 8, 'complete', 0, 'Ventilator-3 in OT-2 needs filter swap next shift', 'ops@equipseva.in', 'done', 'Smooth handover'),
  (now() - interval '2 days', 'night', 12, 'disputed', 3, 'Missing service log for X-Ray unit', 'ops@equipseva.in', 'done', 'Incoming engineer flagged gaps'),
  (now() - interval '5 days', 'weekend', 6, 'complete', 1, 'AMC pending follow-up at Apollo', 'ops@equipseva.in', 'done', NULL),
  (now() - interval '10 days', 'code_red', 4, 'pending', 2, 'ICU monitor escalation open', 'ops@equipseva.in', 'scheduled', 'Awaiting incoming engineer arrival'),
  (now() - interval '15 days', 'day', 9, 'complete', 0, 'Standard handover', 'ops@equipseva.in', 'done', NULL);

INSERT INTO public.handover_discrepancy_resolution_r2594 (handover_id, discrepancy_kind, severity, resolution_summary, owner_email, status, notes)
SELECT id, 'missing_signoff', 'high', 'Backfilled signoff with engineer notes', 'ops@equipseva.in', 'closed', 'Resolved next morning'
FROM public.engineer_on_call_handovers_r2594 WHERE signoff_status = 'disputed' LIMIT 1;

INSERT INTO public.handover_discrepancy_resolution_r2594 (handover_id, discrepancy_kind, severity, resolution_summary, owner_email, status, notes)
SELECT id, 'wrong_part', 'critical', 'Part swap mismatch traced to inventory mislabel', 'ops@equipseva.in', 'in_progress', 'Root cause analysis open'
FROM public.engineer_on_call_handovers_r2594 WHERE shift_kind = 'code_red' LIMIT 1;

INSERT INTO public.handover_discrepancy_resolution_r2594 (handover_id, discrepancy_kind, severity, resolution_summary, owner_email, status, notes)
SELECT id, 'communication', 'medium', 'Engineers reminded to use shared handover channel', 'ops@equipseva.in', 'closed', NULL
FROM public.engineer_on_call_handovers_r2594 WHERE shift_kind = 'weekend' LIMIT 1;

INSERT INTO public.handover_discrepancy_resolution_r2594 (handover_id, discrepancy_kind, severity, resolution_summary, owner_email, status, notes)
SELECT id, 'data_gap', 'low', 'Logged missing data into ledger retroactively', 'ops@equipseva.in', 'open', NULL
FROM public.engineer_on_call_handovers_r2594 WHERE shift_kind = 'night' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_handovers_r2594()
RETURNS TABLE (
  id uuid,
  handover_at timestamptz,
  shift_kind text,
  handover_items_count int,
  signoff_status text,
  discrepancies_count int,
  top_handover_item_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.handover_at, h.shift_kind, h.handover_items_count, h.signoff_status,
         h.discrepancies_count, h.top_handover_item_md, h.owner_email, h.status, h.notes
  FROM public.engineer_on_call_handovers_r2594 h
  ORDER BY h.handover_at DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_handovers_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_handovers_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_discrepancy_resolution_r2594()
RETURNS TABLE (
  id uuid,
  handover_id uuid,
  discrepancy_kind text,
  severity text,
  resolution_summary text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.handover_id, d.discrepancy_kind, d.severity, d.resolution_summary,
         d.owner_email, d.status, d.notes
  FROM public.handover_discrepancy_resolution_r2594 d
  ORDER BY d.created_at DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_discrepancy_resolution_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_discrepancy_resolution_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_discrepancy_focus_r2594()
RETURNS TABLE (
  discrepancy_kind text,
  severity text,
  open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.discrepancy_kind, d.severity, count(*)::bigint AS open_count
  FROM public.handover_discrepancy_resolution_r2594 d
  WHERE d.status IN ('open','in_progress')
  GROUP BY d.discrepancy_kind, d.severity
  ORDER BY count(*) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_discrepancy_focus_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_discrepancy_focus_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.shift_kind_breakdown_r2594()
RETURNS TABLE (
  shift_kind text,
  handovers bigint,
  total_items bigint,
  total_discrepancies bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.shift_kind, count(*)::bigint, coalesce(sum(h.handover_items_count),0)::bigint,
         coalesce(sum(h.discrepancies_count),0)::bigint
  FROM public.engineer_on_call_handovers_r2594 h
  GROUP BY h.shift_kind
  ORDER BY count(*) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.shift_kind_breakdown_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shift_kind_breakdown_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.signoff_status_summary_r2594()
RETURNS TABLE (
  signoff_status text,
  handovers bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.signoff_status, count(*)::bigint
  FROM public.engineer_on_call_handovers_r2594 h
  GROUP BY h.signoff_status
  ORDER BY count(*) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.signoff_status_summary_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.signoff_status_summary_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_handover_trend_r2594()
RETURNS TABLE (
  month_start timestamptz,
  handovers bigint,
  total_discrepancies bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', h.handover_at)::timestamptz AS month_start,
         count(*)::bigint,
         coalesce(sum(h.discrepancies_count),0)::bigint
  FROM public.engineer_on_call_handovers_r2594 h
  GROUP BY date_trunc('month', h.handover_at)
  ORDER BY date_trunc('month', h.handover_at) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_handover_trend_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_handover_trend_r2594() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2594()
RETURNS TABLE (
  owner_email text,
  handovers bigint,
  open_discrepancies bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.owner_email,
         count(DISTINCT h.id)::bigint AS handovers,
         count(d.id) FILTER (WHERE d.status IN ('open','in_progress'))::bigint AS open_discrepancies
  FROM public.engineer_on_call_handovers_r2594 h
  LEFT JOIN public.handover_discrepancy_resolution_r2594 d ON d.handover_id = h.id
  GROUP BY h.owner_email
  ORDER BY count(DISTINCT h.id) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2594() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2594() TO authenticated;
