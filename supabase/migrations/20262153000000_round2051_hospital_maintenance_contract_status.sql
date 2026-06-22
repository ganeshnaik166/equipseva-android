BEGIN;

-- =========================================================================
-- Round 2051 — Hospital Maintenance Contract Status
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_maintenance_contract_status_r2051 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contract_label text NOT NULL,
  monthly_value_rupees bigint NOT NULL DEFAULT 0,
  contract_end_date date NOT NULL,
  days_until_expiry int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('active','expiring_soon','expired','renewed','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hmcs_r2051_hospital ON public.hospital_maintenance_contract_status_r2051(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hmcs_r2051_status ON public.hospital_maintenance_contract_status_r2051(status);
CREATE INDEX IF NOT EXISTS idx_hmcs_r2051_end ON public.hospital_maintenance_contract_status_r2051(contract_end_date);

CREATE TABLE IF NOT EXISTS public.hospital_maintenance_action_log_r2051 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.hospital_maintenance_contract_status_r2051(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('renewal_initiated','renewed','lost','walked_away','expired')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  value_change_rupees bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hmal_r2051_contract ON public.hospital_maintenance_action_log_r2051(contract_id);
CREATE INDEX IF NOT EXISTS idx_hmal_r2051_taken ON public.hospital_maintenance_action_log_r2051(taken_at DESC);

ALTER TABLE public.hospital_maintenance_contract_status_r2051 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_maintenance_action_log_r2051 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hmcs_r2051_founder ON public.hospital_maintenance_contract_status_r2051;
CREATE POLICY hmcs_r2051_founder ON public.hospital_maintenance_contract_status_r2051
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hmal_r2051_founder ON public.hospital_maintenance_action_log_r2051;
CREATE POLICY hmal_r2051_founder ON public.hospital_maintenance_action_log_r2051
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_contracts_r2051(int);
CREATE OR REPLACE FUNCTION public.list_contracts_r2051(p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  contract_label text,
  monthly_value_rupees bigint,
  contract_end_date date,
  days_until_expiry int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.full_name AS hospital_name, c.contract_label,
         c.monthly_value_rupees, c.contract_end_date, c.days_until_expiry,
         c.status, c.captured_at
  FROM public.hospital_maintenance_contract_status_r2051 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  ORDER BY c.contract_end_date ASC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.log_contract_r2051(uuid, text, bigint, date, int, text);
CREATE OR REPLACE FUNCTION public.log_contract_r2051(
  p_hospital_id uuid,
  p_contract_label text,
  p_monthly_value_rupees bigint,
  p_contract_end_date date,
  p_days_until_expiry int,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_maintenance_contract_status_r2051(
    hospital_id, contract_label, monthly_value_rupees, contract_end_date,
    days_until_expiry, status
  ) VALUES (
    p_hospital_id, p_contract_label, p_monthly_value_rupees, p_contract_end_date,
    p_days_until_expiry, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_contract_r2051',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r2051(uuid, int);
CREATE OR REPLACE FUNCTION public.list_actions_r2051(p_contract_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  contract_id uuid,
  contract_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  value_change_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.contract_id, c.contract_label, a.action_type, a.taken_at,
         a.by_email, a.value_change_rupees, a.notes_md
  FROM public.hospital_maintenance_action_log_r2051 a
  LEFT JOIN public.hospital_maintenance_contract_status_r2051 c ON c.id = a.contract_id
  WHERE p_contract_id IS NULL OR a.contract_id = p_contract_id
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r2051(uuid, text, text, bigint, text);
CREATE OR REPLACE FUNCTION public.log_action_r2051(
  p_contract_id uuid,
  p_action_type text,
  p_by_email text,
  p_value_change_rupees bigint,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_maintenance_action_log_r2051(
    contract_id, action_type, by_email, value_change_rupees, notes_md
  ) VALUES (
    p_contract_id, p_action_type, p_by_email, COALESCE(p_value_change_rupees, 0), p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2051',
    jsonb_build_object('id', v_id, 'contract_id', p_contract_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r2051(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2051(p_contract_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.hospital_maintenance_contract_status_r2051
  SET status = p_status, updated_at = now()
  WHERE id = p_contract_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2051',
    jsonb_build_object('id', p_contract_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.expiring_soon_r2051(int, int);
CREATE OR REPLACE FUNCTION public.expiring_soon_r2051(p_within_days int DEFAULT 60, p_limit int DEFAULT 200)
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  contract_label text,
  monthly_value_rupees bigint,
  contract_end_date date,
  days_until_expiry int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.full_name AS hospital_name, c.contract_label,
         c.monthly_value_rupees, c.contract_end_date, c.days_until_expiry, c.status
  FROM public.hospital_maintenance_contract_status_r2051 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  WHERE c.days_until_expiry <= p_within_days
    AND c.status NOT IN ('expired','renewed','lost')
  ORDER BY c.days_until_expiry ASC
  LIMIT p_limit;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r2051(int);
CREATE OR REPLACE FUNCTION public.recent_actions_r2051(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  contract_id uuid,
  contract_label text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  value_change_rupees bigint,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.contract_id, c.contract_label, a.action_type, a.taken_at,
         a.by_email, a.value_change_rupees, a.notes_md
  FROM public.hospital_maintenance_action_log_r2051 a
  LEFT JOIN public.hospital_maintenance_contract_status_r2051 c ON c.id = a.contract_id
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_contracts_r2051(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_contract_r2051(uuid, text, bigint, date, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2051(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2051(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2051(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2051(int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2051(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_contracts_r2051(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_contract_r2051(uuid, text, bigint, date, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2051(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2051(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2051(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2051(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2051(int) TO authenticated;

COMMIT;
