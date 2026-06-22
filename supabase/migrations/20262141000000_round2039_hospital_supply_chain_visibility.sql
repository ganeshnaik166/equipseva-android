BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_supply_chain_visibility_r2039 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id),
  supply_category text NOT NULL CHECK (supply_category IN ('spare_parts','consumables','medications','diagnostic_supplies')),
  inventory_days_remaining int NOT NULL DEFAULT 0,
  supplier_count int NOT NULL DEFAULT 0,
  alternate_suppliers_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'resilient' CHECK (status IN ('resilient','concerning','at_risk','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_supply_action_log_r2039 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visibility_id uuid NOT NULL REFERENCES public.hospital_supply_chain_visibility_r2039(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('inventory_added','supplier_qualified','alternate_sourced','escalated','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_supply_chain_visibility_r2039 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_supply_action_log_r2039 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_vis_r2039 ON public.hospital_supply_chain_visibility_r2039;
CREATE POLICY founder_all_vis_r2039 ON public.hospital_supply_chain_visibility_r2039
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_log_r2039 ON public.hospital_supply_action_log_r2039;
CREATE POLICY founder_all_log_r2039 ON public.hospital_supply_action_log_r2039
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_supply_visibilities_r2039()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, supply_category text, inventory_days_remaining int, supplier_count int, alternate_suppliers_count int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.hospital_id, COALESCE(o.name, p.email) AS hospital_name,
           v.supply_category, v.inventory_days_remaining, v.supplier_count,
           v.alternate_suppliers_count, v.status, v.captured_at
    FROM public.hospital_supply_chain_visibility_r2039 v
    JOIN public.profiles p ON p.id = v.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY v.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_supply_visibility_r2039(
  p_hospital_id uuid,
  p_supply_category text,
  p_inventory_days int,
  p_supplier_count int,
  p_alternate_count int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_supply_chain_visibility_r2039(hospital_id, supply_category, inventory_days_remaining, supplier_count, alternate_suppliers_count, status)
    VALUES (p_hospital_id, p_supply_category, p_inventory_days, p_supplier_count, p_alternate_count, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_supply_visibility_r2039',
            jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'category', p_supply_category, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_supply_actions_r2039(p_visibility_id uuid)
RETURNS TABLE(id uuid, visibility_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.visibility_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_supply_action_log_r2039 a
    WHERE a.visibility_id = p_visibility_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_supply_action_r2039(
  p_visibility_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.hospital_supply_action_log_r2039(visibility_id, action_type, by_email, notes_md)
    VALUES (p_visibility_id, p_action_type, v_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_supply_action_r2039',
            jsonb_build_object('id', v_id, 'visibility_id', p_visibility_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_supply_status_r2039(p_visibility_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_supply_chain_visibility_r2039
    SET status = p_status, updated_at = now()
    WHERE id = p_visibility_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_supply_status_r2039',
            jsonb_build_object('id', p_visibility_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.at_risk_supply_hospitals_r2039()
RETURNS TABLE(hospital_id uuid, hospital_name text, at_risk_categories int, min_days_remaining int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.hospital_id, COALESCE(o.name, p.email) AS hospital_name,
           COUNT(*)::int AS at_risk_categories,
           MIN(v.inventory_days_remaining)::int AS min_days_remaining
    FROM public.hospital_supply_chain_visibility_r2039 v
    JOIN public.profiles p ON p.id = v.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE v.status IN ('at_risk','critical')
    GROUP BY v.hospital_id, o.name, p.email
    ORDER BY min_days_remaining ASC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_supply_actions_r2039()
RETURNS TABLE(id uuid, visibility_id uuid, action_type text, taken_at timestamptz, by_email text, hospital_name text, supply_category text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.visibility_id, a.action_type, a.taken_at, a.by_email,
           COALESCE(o.name, p.email) AS hospital_name, v.supply_category
    FROM public.hospital_supply_action_log_r2039 a
    JOIN public.hospital_supply_chain_visibility_r2039 v ON v.id = a.visibility_id
    JOIN public.profiles p ON p.id = v.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_supply_visibilities_r2039() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_supply_visibility_r2039(uuid, text, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_supply_actions_r2039(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_supply_action_r2039(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_supply_status_r2039(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_supply_hospitals_r2039() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_supply_actions_r2039() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_supply_visibilities_r2039() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_supply_visibility_r2039(uuid, text, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_supply_actions_r2039(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_supply_action_r2039(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_supply_status_r2039(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_supply_hospitals_r2039() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_supply_actions_r2039() TO authenticated;

COMMIT;
