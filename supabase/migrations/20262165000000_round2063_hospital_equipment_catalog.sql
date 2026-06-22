BEGIN;

-- =====================================================================
-- Round 2063 — Hospital Equipment Catalog
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_catalog_r2063 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  manufacturer_name text NOT NULL,
  equipment_model text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','ventilator','anesthesia','monitor','lab','cardiac','dental','orthopedic')),
  typical_service_minutes int NOT NULL DEFAULT 60 CHECK (typical_service_minutes > 0),
  parts_availability text NOT NULL DEFAULT 'normal' CHECK (parts_availability IN ('abundant','normal','limited','scarce')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','discontinued','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_catalog_action_log_r2063 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES public.hospital_equipment_catalog_r2063(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('added','updated','marked_discontinued','parts_reissue','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hec_r2063_cat ON public.hospital_equipment_catalog_r2063(equipment_category);
CREATE INDEX IF NOT EXISTS idx_hec_r2063_status ON public.hospital_equipment_catalog_r2063(status);
CREATE INDEX IF NOT EXISTS idx_hcal_r2063_eq ON public.hospital_catalog_action_log_r2063(equipment_id);
CREATE INDEX IF NOT EXISTS idx_hcal_r2063_taken ON public.hospital_catalog_action_log_r2063(taken_at DESC);

ALTER TABLE public.hospital_equipment_catalog_r2063 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_catalog_action_log_r2063 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hec_r2063_founder_all ON public.hospital_equipment_catalog_r2063;
CREATE POLICY hec_r2063_founder_all ON public.hospital_equipment_catalog_r2063
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hcal_r2063_founder_all ON public.hospital_catalog_action_log_r2063;
CREATE POLICY hcal_r2063_founder_all ON public.hospital_catalog_action_log_r2063
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_equipment
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_equipment_r2063();
CREATE OR REPLACE FUNCTION public.list_equipment_r2063()
RETURNS TABLE (
  id uuid,
  manufacturer_name text,
  equipment_model text,
  equipment_category text,
  typical_service_minutes int,
  parts_availability text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.manufacturer_name, e.equipment_model, e.equipment_category,
         e.typical_service_minutes, e.parts_availability, e.status, e.captured_at
  FROM public.hospital_equipment_catalog_r2063 e
  ORDER BY e.captured_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_equipment_r2063() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_equipment_r2063() TO authenticated;

-- =====================================================================
-- RPC 2: log_equipment (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_equipment_r2063(text, text, text, int, text);
CREATE OR REPLACE FUNCTION public.log_equipment_r2063(
  p_manufacturer text,
  p_model text,
  p_category text,
  p_minutes int,
  p_parts text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_catalog_r2063(
    manufacturer_name, equipment_model, equipment_category, typical_service_minutes, parts_availability
  ) VALUES (p_manufacturer, p_model, p_category, p_minutes, p_parts)
  RETURNING id INTO v_id;

  INSERT INTO public.hospital_catalog_action_log_r2063(equipment_id, action_type, by_email, notes_md)
  VALUES (v_id, 'added', (auth.jwt()->>'email'), 'Equipment added to catalog');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_equipment_r2063',
    jsonb_build_object('id', v_id, 'manufacturer', p_manufacturer, 'model', p_model, 'category', p_category));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_equipment_r2063(text, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_equipment_r2063(text, text, text, int, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_actions
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_actions_r2063();
CREATE OR REPLACE FUNCTION public.list_actions_r2063()
RETURNS TABLE (
  id uuid,
  equipment_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text,
  equipment_model text,
  manufacturer_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.equipment_id, a.action_type, a.taken_at, a.by_email, a.notes_md,
         e.equipment_model, e.manufacturer_name
  FROM public.hospital_catalog_action_log_r2063 a
  LEFT JOIN public.hospital_equipment_catalog_r2063 e ON e.id = a.equipment_id
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2063() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2063() TO authenticated;

-- =====================================================================
-- RPC 4: log_action (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_action_r2063(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2063(
  p_equipment_id uuid,
  p_action_type text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_catalog_action_log_r2063(equipment_id, action_type, by_email, notes_md)
  VALUES (p_equipment_id, p_action_type, (auth.jwt()->>'email'), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2063',
    jsonb_build_object('id', v_id, 'equipment_id', p_equipment_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r2063(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2063(uuid, text, text) TO authenticated;

-- =====================================================================
-- RPC 5: mark_status (write)
-- =====================================================================
DROP FUNCTION IF EXISTS public.mark_status_r2063(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2063(
  p_equipment_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_equipment_catalog_r2063
  SET status = p_new_status, updated_at = now()
  WHERE id = p_equipment_id;

  INSERT INTO public.hospital_catalog_action_log_r2063(equipment_id, action_type, by_email, notes_md)
  VALUES (p_equipment_id,
    CASE WHEN p_new_status = 'discontinued' THEN 'marked_discontinued'
         WHEN p_new_status = 'superseded' THEN 'superseded'
         ELSE 'updated' END,
    (auth.jwt()->>'email'),
    'Status changed to ' || p_new_status);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2063',
    jsonb_build_object('equipment_id', p_equipment_id, 'new_status', p_new_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2063(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2063(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: by_category
-- =====================================================================
DROP FUNCTION IF EXISTS public.by_category_r2063();
CREATE OR REPLACE FUNCTION public.by_category_r2063()
RETURNS TABLE (
  equipment_category text,
  total_count bigint,
  active_count bigint,
  discontinued_count bigint,
  avg_service_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.equipment_category,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE e.status = 'active')::bigint AS active_count,
         COUNT(*) FILTER (WHERE e.status = 'discontinued')::bigint AS discontinued_count,
         ROUND(AVG(e.typical_service_minutes)::numeric, 1) AS avg_service_minutes
  FROM public.hospital_equipment_catalog_r2063 e
  GROUP BY e.equipment_category
  ORDER BY total_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.by_category_r2063() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.by_category_r2063() TO authenticated;

-- =====================================================================
-- RPC 7: recent_actions
-- =====================================================================
DROP FUNCTION IF EXISTS public.recent_actions_r2063();
CREATE OR REPLACE FUNCTION public.recent_actions_r2063()
RETURNS TABLE (
  id uuid,
  equipment_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  equipment_model text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.equipment_id, a.action_type, a.taken_at, a.by_email,
         e.equipment_model
  FROM public.hospital_catalog_action_log_r2063 a
  LEFT JOIN public.hospital_equipment_catalog_r2063 e ON e.id = a.equipment_id
  WHERE a.taken_at > now() - interval '30 days'
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2063() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2063() TO authenticated;

COMMIT;
