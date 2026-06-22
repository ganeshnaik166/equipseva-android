BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_equipment_sourcing_vendor_map_r2111 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_name text NOT NULL,
  vendor_specialty text NOT NULL CHECK (vendor_specialty IN ('imaging_supplier','parts_supplier','consumables','diagnostics','full_lifecycle')),
  reliability_score int NOT NULL DEFAULT 70 CHECK (reliability_score BETWEEN 0 AND 100),
  lead_time_days int NOT NULL DEFAULT 7,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','pause','delisted','preferred')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_vendor_action_log_r2111 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.hospital_equipment_sourcing_vendor_map_r2111(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('onboarded','order_placed','late_delivery','preferred','delisted','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_equipment_sourcing_vendor_map_r2111 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_vendor_action_log_r2111 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r2111_vendor_map_founder ON public.hospital_equipment_sourcing_vendor_map_r2111;
CREATE POLICY r2111_vendor_map_founder ON public.hospital_equipment_sourcing_vendor_map_r2111
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r2111_vendor_log_founder ON public.hospital_vendor_action_log_r2111;
CREATE POLICY r2111_vendor_log_founder ON public.hospital_vendor_action_log_r2111
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2111_list_vendors()
RETURNS TABLE (id uuid, vendor_name text, vendor_specialty text, reliability_score int, lead_time_days int, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.vendor_name, v.vendor_specialty, v.reliability_score, v.lead_time_days, v.status, v.captured_at
  FROM public.hospital_equipment_sourcing_vendor_map_r2111 v
  ORDER BY v.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_log_vendor(
  p_vendor_name text,
  p_vendor_specialty text,
  p_reliability_score int,
  p_lead_time_days int,
  p_status text
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
  INSERT INTO public.hospital_equipment_sourcing_vendor_map_r2111
    (vendor_name, vendor_specialty, reliability_score, lead_time_days, status)
  VALUES (p_vendor_name, p_vendor_specialty, p_reliability_score, p_lead_time_days, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r2111_log_vendor',
    jsonb_build_object('vendor_id', v_id, 'vendor_name', p_vendor_name, 'status', p_status)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_list_actions()
RETURNS TABLE (id uuid, vendor_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.vendor_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_vendor_action_log_r2111 a
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_log_action(
  p_vendor_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_vendor_action_log_r2111
    (vendor_id, action_type, by_email, notes_md)
  VALUES (p_vendor_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r2111_log_action',
    jsonb_build_object('action_id', v_id, 'vendor_id', p_vendor_id, 'action_type', p_action_type)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_mark_status(
  p_vendor_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_sourcing_vendor_map_r2111
  SET status = p_status, updated_at = now()
  WHERE id = p_vendor_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r2111_mark_status',
    jsonb_build_object('vendor_id', p_vendor_id, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_preferred_vendors()
RETURNS TABLE (id uuid, vendor_name text, vendor_specialty text, reliability_score int, lead_time_days int, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.vendor_name, v.vendor_specialty, v.reliability_score, v.lead_time_days, v.status, v.captured_at
  FROM public.hospital_equipment_sourcing_vendor_map_r2111 v
  WHERE v.status = 'preferred'
  ORDER BY v.reliability_score DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2111_recent_actions()
RETURNS TABLE (id uuid, vendor_id uuid, vendor_name text, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.vendor_id, v.vendor_name, a.action_type, a.taken_at, a.by_email
  FROM public.hospital_vendor_action_log_r2111 a
  JOIN public.hospital_equipment_sourcing_vendor_map_r2111 v ON v.id = a.vendor_id
  WHERE a.taken_at > now() - interval '30 days'
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2111_list_vendors() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_log_vendor(text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_list_actions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_preferred_vendors() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2111_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2111_list_vendors() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_log_vendor(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_preferred_vendors() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2111_recent_actions() TO authenticated;

COMMIT;
