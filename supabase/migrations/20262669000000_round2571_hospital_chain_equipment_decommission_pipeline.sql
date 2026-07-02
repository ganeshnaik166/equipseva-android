-- Round 2571 — Hospital chain equipment decommission pipeline
-- Founder-only surface tracking chain x equipment x decommission reason x disposal kind x buyback revenue x compliance

CREATE TABLE IF NOT EXISTS public.chain_equipment_decommissions_r2571 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  decommission_reason text NOT NULL CHECK (decommission_reason IN ('end_of_life','upgrade','cost','safety','regulatory')),
  disposal_kind text NOT NULL CHECK (disposal_kind IN ('scrap','return_oem','resell','donate','buyback')),
  revenue_buyback_rupees bigint NOT NULL DEFAULT 0,
  compliance_status text NOT NULL CHECK (compliance_status IN ('compliant','marginal','non_compliant')),
  decomm_planned_at timestamptz,
  decomm_completed_at timestamptz,
  owner_email text,
  status text NOT NULL CHECK (status IN ('planned','in_progress','completed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.decommission_compliance_log_r2571 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decomm_id uuid NOT NULL REFERENCES public.chain_equipment_decommissions_r2571(id) ON DELETE CASCADE,
  log_at timestamptz NOT NULL DEFAULT now(),
  compliance_check_kind text NOT NULL CHECK (compliance_check_kind IN ('e_waste','radiation','biohazard','data_wipe','asset_register')),
  outcome text NOT NULL CHECK (outcome IN ('passed','failed','pending')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_equipment_decommissions_r2571 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decommission_compliance_log_r2571 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_equipment_decommissions_r2571;
CREATE POLICY founder_all ON public.chain_equipment_decommissions_r2571
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.decommission_compliance_log_r2571;
CREATE POLICY founder_all ON public.decommission_compliance_log_r2571
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_equipment_decommissions_r2571
  (chain_name, equipment_label, equipment_kind, decommission_reason, disposal_kind, revenue_buyback_rupees, compliance_status, decomm_planned_at, decomm_completed_at, owner_email, status, notes)
VALUES
  ('Apollo Chain','CT-Scanner Unit-12','ct_scanner','end_of_life','buyback', 850000,'compliant','2026-06-01T09:00:00+05:30'::timestamptz,'2026-06-15T17:00:00+05:30'::timestamptz,'ops1@equipseva.com','completed','OEM buyback finalized'),
  ('Fortis Chain','X-Ray Portable-04','xray','upgrade','return_oem', 0,'compliant','2026-06-10T09:00:00+05:30'::timestamptz, NULL,'ops2@equipseva.com','in_progress','Pending OEM pickup'),
  ('Manipal Chain','Dental Chair-22','dental_chair','cost','resell', 45000,'marginal','2026-06-18T09:00:00+05:30'::timestamptz, NULL,'ops1@equipseva.com','planned','Listed on resell channel'),
  ('Max Chain','Defibrillator-09','defibrillator','safety','scrap', 0,'non_compliant','2026-06-05T09:00:00+05:30'::timestamptz,'2026-06-12T17:00:00+05:30'::timestamptz,'ops3@equipseva.com','completed','E-waste vendor missed manifest'),
  ('Yashoda Chain','Ventilator-17','ventilator','regulatory','donate', 0,'compliant','2026-06-20T09:00:00+05:30'::timestamptz, NULL,'ops2@equipseva.com','planned','Donation to district hospital');

INSERT INTO public.decommission_compliance_log_r2571
  (decomm_id, log_at, compliance_check_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-15T10:00:00+05:30'::timestamptz,'asset_register','passed','ops1@equipseva.com','done','Asset register updated'
  FROM public.chain_equipment_decommissions_r2571 WHERE equipment_label='CT-Scanner Unit-12' LIMIT 1;

INSERT INTO public.decommission_compliance_log_r2571
  (decomm_id, log_at, compliance_check_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-15T11:00:00+05:30'::timestamptz,'radiation','passed','ops1@equipseva.com','done','Lead-shield sign-off'
  FROM public.chain_equipment_decommissions_r2571 WHERE equipment_label='CT-Scanner Unit-12' LIMIT 1;

INSERT INTO public.decommission_compliance_log_r2571
  (decomm_id, log_at, compliance_check_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-12T17:30:00+05:30'::timestamptz,'e_waste','failed','ops3@equipseva.com','open','Manifest missing'
  FROM public.chain_equipment_decommissions_r2571 WHERE equipment_label='Defibrillator-09' LIMIT 1;

INSERT INTO public.decommission_compliance_log_r2571
  (decomm_id, log_at, compliance_check_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-11T09:00:00+05:30'::timestamptz,'data_wipe','pending','ops2@equipseva.com','open','Awaiting OEM pickup'
  FROM public.chain_equipment_decommissions_r2571 WHERE equipment_label='X-Ray Portable-04' LIMIT 1;

INSERT INTO public.decommission_compliance_log_r2571
  (decomm_id, log_at, compliance_check_kind, outcome, owner_email, status, notes)
SELECT id,'2026-06-19T09:00:00+05:30'::timestamptz,'biohazard','pending','ops2@equipseva.com','open','Pre-donation biohazard check'
  FROM public.chain_equipment_decommissions_r2571 WHERE equipment_label='Ventilator-17' LIMIT 1;

-- RPCs

DROP FUNCTION IF EXISTS public.list_decommissions_r2571();
CREATE OR REPLACE FUNCTION public.list_decommissions_r2571()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  equipment_kind text,
  decommission_reason text,
  disposal_kind text,
  revenue_buyback_rupees bigint,
  compliance_status text,
  decomm_planned_at timestamptz,
  decomm_completed_at timestamptz,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.chain_name, d.equipment_label, d.equipment_kind, d.decommission_reason, d.disposal_kind,
           d.revenue_buyback_rupees, d.compliance_status, d.decomm_planned_at, d.decomm_completed_at,
           d.owner_email, d.status, d.notes
    FROM public.chain_equipment_decommissions_r2571 d
    ORDER BY d.decomm_planned_at DESC NULLS LAST, d.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decommissions_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decommissions_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.list_compliance_log_r2571();
CREATE OR REPLACE FUNCTION public.list_compliance_log_r2571()
RETURNS TABLE (
  id uuid,
  decomm_id uuid,
  chain_name text,
  equipment_label text,
  log_at timestamptz,
  compliance_check_kind text,
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
    SELECT l.id, l.decomm_id, d.chain_name, d.equipment_label, l.log_at, l.compliance_check_kind, l.outcome,
           l.owner_email, l.status, l.notes
    FROM public.decommission_compliance_log_r2571 l
    JOIN public.chain_equipment_decommissions_r2571 d ON d.id = l.decomm_id
    ORDER BY l.log_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_compliance_log_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_compliance_log_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.top_buyback_focus_r2571();
CREATE OR REPLACE FUNCTION public.top_buyback_focus_r2571()
RETURNS TABLE (
  chain_name text,
  total_buyback_rupees bigint,
  decomm_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.chain_name,
           COALESCE(SUM(d.revenue_buyback_rupees),0)::bigint AS total_buyback_rupees,
           COUNT(*)::bigint AS decomm_count
    FROM public.chain_equipment_decommissions_r2571 d
    GROUP BY d.chain_name
    ORDER BY total_buyback_rupees DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_buyback_focus_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_buyback_focus_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.disposal_kind_breakdown_r2571();
CREATE OR REPLACE FUNCTION public.disposal_kind_breakdown_r2571()
RETURNS TABLE (
  disposal_kind text,
  decomm_count bigint,
  total_buyback_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.disposal_kind,
           COUNT(*)::bigint AS decomm_count,
           COALESCE(SUM(d.revenue_buyback_rupees),0)::bigint AS total_buyback_rupees
    FROM public.chain_equipment_decommissions_r2571 d
    GROUP BY d.disposal_kind
    ORDER BY decomm_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.disposal_kind_breakdown_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.disposal_kind_breakdown_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.compliance_status_summary_r2571();
CREATE OR REPLACE FUNCTION public.compliance_status_summary_r2571()
RETURNS TABLE (
  compliance_status text,
  decomm_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.compliance_status, COUNT(*)::bigint AS decomm_count
    FROM public.chain_equipment_decommissions_r2571 d
    GROUP BY d.compliance_status
    ORDER BY decomm_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.compliance_status_summary_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compliance_status_summary_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.monthly_decomm_trend_r2571();
CREATE OR REPLACE FUNCTION public.monthly_decomm_trend_r2571()
RETURNS TABLE (
  month_label text,
  decomm_count bigint,
  total_buyback_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', COALESCE(d.decomm_planned_at, d.created_at)),'YYYY-MM') AS month_label,
           COUNT(*)::bigint AS decomm_count,
           COALESCE(SUM(d.revenue_buyback_rupees),0)::bigint AS total_buyback_rupees
    FROM public.chain_equipment_decommissions_r2571 d
    GROUP BY 1
    ORDER BY month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_decomm_trend_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_decomm_trend_r2571() TO authenticated;

DROP FUNCTION IF EXISTS public.owner_load_r2571();
CREATE OR REPLACE FUNCTION public.owner_load_r2571()
RETURNS TABLE (
  owner_email text,
  decomm_count bigint,
  open_compliance_logs bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(d.owner_email,'(unassigned)') AS owner_email,
           COUNT(DISTINCT d.id)::bigint AS decomm_count,
           COUNT(l.id) FILTER (WHERE l.status = 'open')::bigint AS open_compliance_logs
    FROM public.chain_equipment_decommissions_r2571 d
    LEFT JOIN public.decommission_compliance_log_r2571 l ON l.decomm_id = d.id
    GROUP BY COALESCE(d.owner_email,'(unassigned)')
    ORDER BY decomm_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2571() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2571() TO authenticated;
