BEGIN;

-- =========================================================================
-- Round 1903: Hospital Equipment Warranty Expiry
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_warranty_r1903 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  manufacturer text,
  purchase_date date,
  warranty_expires_on date NOT NULL,
  warranty_terms_md text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','expiring_soon','expired','renewed','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hew_r1903_hospital
  ON public.hospital_equipment_warranty_r1903 (hospital_id);
CREATE INDEX IF NOT EXISTS idx_hew_r1903_expires
  ON public.hospital_equipment_warranty_r1903 (warranty_expires_on);
CREATE INDEX IF NOT EXISTS idx_hew_r1903_status
  ON public.hospital_equipment_warranty_r1903 (status);

CREATE TABLE IF NOT EXISTS public.hospital_warranty_renewal_actions_r1903 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warranty_id uuid NOT NULL REFERENCES public.hospital_equipment_warranty_r1903(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('quote_requested','quote_received','renewed','declined','escalate_to_founder')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  cost_estimate_rupees bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hwra_r1903_warranty
  ON public.hospital_warranty_renewal_actions_r1903 (warranty_id);
CREATE INDEX IF NOT EXISTS idx_hwra_r1903_taken
  ON public.hospital_warranty_renewal_actions_r1903 (taken_at DESC);

ALTER TABLE public.hospital_equipment_warranty_r1903 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_warranty_renewal_actions_r1903 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hew_r1903 ON public.hospital_equipment_warranty_r1903;
CREATE POLICY founder_all_hew_r1903 ON public.hospital_equipment_warranty_r1903
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hwra_r1903 ON public.hospital_warranty_renewal_actions_r1903;
CREATE POLICY founder_all_hwra_r1903 ON public.hospital_warranty_renewal_actions_r1903
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_warranties_r1903()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  equipment_name text,
  manufacturer text,
  purchase_date date,
  warranty_expires_on date,
  status text,
  days_remaining int,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.id, w.hospital_id, w.equipment_name, w.manufacturer,
           w.purchase_date, w.warranty_expires_on, w.status,
           (w.warranty_expires_on - CURRENT_DATE)::int AS days_remaining,
           w.captured_at
      FROM public.hospital_equipment_warranty_r1903 w
     ORDER BY w.warranty_expires_on ASC NULLS LAST
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_warranty_r1903(
  p_hospital_id uuid,
  p_equipment_name text,
  p_manufacturer text,
  p_purchase_date date,
  p_warranty_expires_on date,
  p_warranty_terms_md text,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_warranty_r1903
    (hospital_id, equipment_name, manufacturer, purchase_date,
     warranty_expires_on, warranty_terms_md, status)
  VALUES
    (p_hospital_id, p_equipment_name, p_manufacturer, p_purchase_date,
     p_warranty_expires_on, p_warranty_terms_md, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_warranty_r1903',
          jsonb_build_object('warranty_id', v_id, 'hospital_id', p_hospital_id,
                             'equipment_name', p_equipment_name,
                             'expires_on', p_warranty_expires_on));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1903(p_warranty_id uuid)
RETURNS TABLE (
  id uuid,
  warranty_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_estimate_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.warranty_id, a.action_type, a.taken_at, a.by_email, a.cost_estimate_rupees
      FROM public.hospital_warranty_renewal_actions_r1903 a
     WHERE a.warranty_id = p_warranty_id
     ORDER BY a.taken_at DESC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_renewal_action_r1903(
  p_warranty_id uuid,
  p_action_type text,
  p_by_email text,
  p_cost_estimate_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_warranty_renewal_actions_r1903
    (warranty_id, action_type, by_email, cost_estimate_rupees)
  VALUES (p_warranty_id, p_action_type, p_by_email, p_cost_estimate_rupees)
  RETURNING id INTO v_id;

  IF p_action_type = 'escalate_to_founder' THEN
    UPDATE public.hospital_equipment_warranty_r1903
       SET status = 'escalated', updated_at = now()
     WHERE id = p_warranty_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_renewal_action_r1903',
          jsonb_build_object('warranty_id', p_warranty_id,
                             'action_type', p_action_type,
                             'cost_estimate_rupees', p_cost_estimate_rupees));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_renewed_r1903(p_warranty_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_warranty_r1903
     SET status = 'renewed', updated_at = now()
   WHERE id = p_warranty_id;

  INSERT INTO public.hospital_warranty_renewal_actions_r1903 (warranty_id, action_type, by_email)
  VALUES (p_warranty_id, 'renewed', (auth.jwt()->>'email'));

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_renewed_r1903',
          jsonb_build_object('warranty_id', p_warranty_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.expiring_within_30d_r1903()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  equipment_name text,
  manufacturer text,
  warranty_expires_on date,
  days_remaining int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT w.id, w.hospital_id, w.equipment_name, w.manufacturer,
           w.warranty_expires_on,
           (w.warranty_expires_on - CURRENT_DATE)::int AS days_remaining,
           w.status
      FROM public.hospital_equipment_warranty_r1903 w
     WHERE w.warranty_expires_on BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
       AND w.status NOT IN ('renewed','expired')
     ORDER BY w.warranty_expires_on ASC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_renewal_actions_r1903()
RETURNS TABLE (
  id uuid,
  warranty_id uuid,
  equipment_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  cost_estimate_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.warranty_id, w.equipment_name, a.action_type,
           a.taken_at, a.by_email, a.cost_estimate_rupees
      FROM public.hospital_warranty_renewal_actions_r1903 a
      JOIN public.hospital_equipment_warranty_r1903 w ON w.id = a.warranty_id
     ORDER BY a.taken_at DESC
     LIMIT 200;
END;
$$;

-- =========================================================================
-- REVOKE + GRANT
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_warranties_r1903() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_warranties_r1903() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_warranty_r1903(uuid, text, text, date, date, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_warranty_r1903(uuid, text, text, date, date, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1903(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_actions_r1903(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_renewal_action_r1903(uuid, text, text, bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_renewal_action_r1903(uuid, text, text, bigint) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_renewed_r1903(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_renewed_r1903(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.expiring_within_30d_r1903() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.expiring_within_30d_r1903() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_renewal_actions_r1903() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recent_renewal_actions_r1903() TO authenticated;

COMMIT;
