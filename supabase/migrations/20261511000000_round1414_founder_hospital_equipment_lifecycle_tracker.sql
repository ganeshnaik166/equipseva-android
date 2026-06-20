BEGIN;
-- r1414 founder_hospital_equipment_lifecycle_tracker
-- Tracks equipment from acquisition through retirement with event ledger.

CREATE TABLE IF NOT EXISTS public.founder_hospital_equipment_lifecycle (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  manufacturer text,
  model_number text,
  serial_number text UNIQUE,
  equipment_category text,
  lifecycle_stage text NOT NULL DEFAULT 'quotation'
    CHECK (lifecycle_stage IN ('quotation','procurement','installation','commissioned','operational','maintenance_only','decommissioned','disposed')),
  procurement_date date,
  installation_date date,
  commission_date date,
  decommission_date date,
  disposal_date date,
  purchase_cost_rupees numeric NOT NULL DEFAULT 0,
  current_book_value_rupees numeric NOT NULL DEFAULT 0,
  useful_life_years int NOT NULL DEFAULT 7,
  criticality_band text NOT NULL DEFAULT 'medium'
    CHECK (criticality_band IN ('critical','high','medium','low')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhel_hospital ON public.founder_hospital_equipment_lifecycle(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhel_stage ON public.founder_hospital_equipment_lifecycle(lifecycle_stage);
CREATE INDEX IF NOT EXISTS idx_fhel_crit ON public.founder_hospital_equipment_lifecycle(criticality_band);

CREATE TABLE IF NOT EXISTS public.founder_hospital_equipment_lifecycle_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES public.founder_hospital_equipment_lifecycle(id) ON DELETE CASCADE,
  event_kind text NOT NULL
    CHECK (event_kind IN ('major_repair','calibration','upgrade','part_replacement','incident','warranty_invoked','training_session','audit','status_change')),
  description text,
  happened_at timestamptz NOT NULL DEFAULT now(),
  value_rupees numeric NOT NULL DEFAULT 0,
  performed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhele_equipment ON public.founder_hospital_equipment_lifecycle_events(equipment_id);
CREATE INDEX IF NOT EXISTS idx_fhele_kind ON public.founder_hospital_equipment_lifecycle_events(event_kind);
CREATE INDEX IF NOT EXISTS idx_fhele_happened ON public.founder_hospital_equipment_lifecycle_events(happened_at DESC);

ALTER TABLE public.founder_hospital_equipment_lifecycle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_hospital_equipment_lifecycle_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhel_founder_all ON public.founder_hospital_equipment_lifecycle;
CREATE POLICY fhel_founder_all ON public.founder_hospital_equipment_lifecycle FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fhele_founder_all ON public.founder_hospital_equipment_lifecycle_events;
CREATE POLICY fhele_founder_all ON public.founder_hospital_equipment_lifecycle_events FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: summary 16 KPIs
CREATE OR REPLACE FUNCTION public.founder_equipment_lifecycle_summary()
RETURNS TABLE (
  total_equipment bigint,
  operational_count bigint,
  maintenance_only_count bigint,
  decommissioned_count bigint,
  disposed_count bigint,
  quotation_count bigint,
  procurement_count bigint,
  installation_count bigint,
  commissioned_count bigint,
  critical_count bigint,
  high_count bigint,
  total_purchase_cost_rupees numeric,
  total_book_value_rupees numeric,
  avg_useful_life_years numeric,
  total_events bigint,
  total_event_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='operational'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='maintenance_only'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='decommissioned'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='disposed'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='quotation'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='procurement'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='installation'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE lifecycle_stage='commissioned'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE criticality_band='critical'),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle WHERE criticality_band='high'),
    (SELECT COALESCE(sum(purchase_cost_rupees),0) FROM public.founder_hospital_equipment_lifecycle),
    (SELECT COALESCE(sum(current_book_value_rupees),0) FROM public.founder_hospital_equipment_lifecycle),
    (SELECT COALESCE(avg(useful_life_years),0)::numeric FROM public.founder_hospital_equipment_lifecycle),
    (SELECT count(*) FROM public.founder_hospital_equipment_lifecycle_events),
    (SELECT COALESCE(sum(value_rupees),0) FROM public.founder_hospital_equipment_lifecycle_events);
END;
$$;

-- RPC 2: recent equipment
CREATE OR REPLACE FUNCTION public.founder_equipment_lifecycle_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  equipment_label text,
  manufacturer text,
  model_number text,
  serial_number text,
  equipment_category text,
  lifecycle_stage text,
  criticality_band text,
  purchase_cost_rupees numeric,
  current_book_value_rupees numeric,
  useful_life_years int,
  hospital_name text,
  procurement_date date,
  commission_date date,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT e.id, e.equipment_label, e.manufacturer, e.model_number, e.serial_number,
         e.equipment_category, e.lifecycle_stage, e.criticality_band,
         e.purchase_cost_rupees, e.current_book_value_rupees, e.useful_life_years,
         o.name AS hospital_name, e.procurement_date, e.commission_date, e.created_at
  FROM public.founder_hospital_equipment_lifecycle e
  LEFT JOIN public.organizations o ON o.id = e.hospital_org_id
  ORDER BY e.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 3: recent events
CREATE OR REPLACE FUNCTION public.founder_equipment_lifecycle_events_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  equipment_id uuid,
  equipment_label text,
  event_kind text,
  description text,
  happened_at timestamptz,
  value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT ev.id, ev.equipment_id, e.equipment_label, ev.event_kind, ev.description,
         ev.happened_at, ev.value_rupees
  FROM public.founder_hospital_equipment_lifecycle_events ev
  LEFT JOIN public.founder_hospital_equipment_lifecycle e ON e.id = ev.equipment_id
  ORDER BY ev.happened_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 4: by stage
CREATE OR REPLACE FUNCTION public.founder_equipment_lifecycle_by_stage()
RETURNS TABLE (
  lifecycle_stage text,
  equipment_count bigint,
  total_book_value_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT e.lifecycle_stage, count(*)::bigint AS equipment_count,
         COALESCE(sum(e.current_book_value_rupees),0) AS total_book_value_rupees
  FROM public.founder_hospital_equipment_lifecycle e
  GROUP BY e.lifecycle_stage
  ORDER BY equipment_count DESC;
END;
$$;

-- RPC 5: register equipment
CREATE OR REPLACE FUNCTION public.log_founder_equipment_lifecycle_register(
  p_hospital_org_id uuid,
  p_equipment_label text,
  p_manufacturer text,
  p_model_number text,
  p_serial_number text,
  p_equipment_category text,
  p_purchase_cost_rupees numeric,
  p_criticality_band text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_hospital_equipment_lifecycle
    (hospital_org_id, equipment_label, manufacturer, model_number, serial_number,
     equipment_category, purchase_cost_rupees, current_book_value_rupees, criticality_band, lifecycle_stage)
  VALUES
    (p_hospital_org_id, p_equipment_label, p_manufacturer, p_model_number, p_serial_number,
     p_equipment_category, COALESCE(p_purchase_cost_rupees,0), COALESCE(p_purchase_cost_rupees,0),
     COALESCE(p_criticality_band,'medium'), 'quotation')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 6: stage change
CREATE OR REPLACE FUNCTION public.log_founder_equipment_lifecycle_stage_change(
  p_equipment_id uuid,
  p_new_stage text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_hospital_equipment_lifecycle
     SET lifecycle_stage = p_new_stage,
         updated_at = now(),
         notes = COALESCE(p_notes, notes),
         commission_date = CASE WHEN p_new_stage='commissioned' AND commission_date IS NULL THEN now()::date ELSE commission_date END,
         decommission_date = CASE WHEN p_new_stage='decommissioned' AND decommission_date IS NULL THEN now()::date ELSE decommission_date END,
         disposal_date = CASE WHEN p_new_stage='disposed' AND disposal_date IS NULL THEN now()::date ELSE disposal_date END
   WHERE id = p_equipment_id;
  INSERT INTO public.founder_hospital_equipment_lifecycle_events
    (equipment_id, event_kind, description, performed_by)
  VALUES (p_equipment_id, 'status_change', COALESCE(p_notes,'stage->'||p_new_stage), auth.uid());
END;
$$;

-- RPC 7: log event
CREATE OR REPLACE FUNCTION public.log_founder_equipment_lifecycle_event(
  p_equipment_id uuid,
  p_event_kind text,
  p_description text,
  p_value_rupees numeric
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_hospital_equipment_lifecycle_events
    (equipment_id, event_kind, description, value_rupees, performed_by)
  VALUES (p_equipment_id, p_event_kind, p_description, COALESCE(p_value_rupees,0), auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_equipment_lifecycle_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_equipment_lifecycle_recent(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_equipment_lifecycle_events_recent(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_equipment_lifecycle_by_stage() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_founder_equipment_lifecycle_register(uuid,text,text,text,text,text,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_founder_equipment_lifecycle_stage_change(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_founder_equipment_lifecycle_event(uuid,text,text,numeric) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_equipment_lifecycle_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_equipment_lifecycle_recent(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_equipment_lifecycle_events_recent(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_equipment_lifecycle_by_stage() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_equipment_lifecycle_register(uuid,text,text,text,text,text,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_equipment_lifecycle_stage_change(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_equipment_lifecycle_event(uuid,text,text,numeric) TO authenticated;
COMMIT;
