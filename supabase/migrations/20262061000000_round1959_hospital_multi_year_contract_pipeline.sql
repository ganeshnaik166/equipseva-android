BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_multi_year_contracts_r1959 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  contract_label text NOT NULL,
  contract_years int NOT NULL CHECK (contract_years > 0),
  total_value_rupees bigint NOT NULL DEFAULT 0,
  signed_date date,
  expiry_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expiring_soon','expired','renewed','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_multi_year_renewal_log_r1959 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES public.hospital_multi_year_contracts_r1959(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('renewal_intent_signaled','proposal_sent','negotiation','signed','declined','walked_away')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  value_change_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_multi_year_contracts_r1959 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_multi_year_renewal_log_r1959 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_contracts_r1959 ON public.hospital_multi_year_contracts_r1959;
CREATE POLICY founder_all_contracts_r1959 ON public.hospital_multi_year_contracts_r1959
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_renewals_r1959 ON public.hospital_multi_year_renewal_log_r1959;
CREATE POLICY founder_all_renewals_r1959 ON public.hospital_multi_year_renewal_log_r1959
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_mycontracts_r1959_status ON public.hospital_multi_year_contracts_r1959(status);
CREATE INDEX IF NOT EXISTS idx_mycontracts_r1959_expiry ON public.hospital_multi_year_contracts_r1959(expiry_date);
CREATE INDEX IF NOT EXISTS idx_myrenewal_r1959_contract ON public.hospital_multi_year_renewal_log_r1959(contract_id, taken_at DESC);

CREATE OR REPLACE FUNCTION public.list_contracts_r1959()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_email text,
  contract_label text,
  contract_years int,
  total_value_rupees bigint,
  signed_date date,
  expiry_date date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.email, c.contract_label, c.contract_years,
         c.total_value_rupees, c.signed_date, c.expiry_date, c.status, c.created_at
  FROM public.hospital_multi_year_contracts_r1959 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  ORDER BY c.created_at DESC
  LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_contract_r1959(
  p_hospital_id uuid,
  p_contract_label text,
  p_contract_years int,
  p_total_value_rupees bigint,
  p_signed_date date,
  p_expiry_date date,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_multi_year_contracts_r1959(hospital_id, contract_label, contract_years, total_value_rupees, signed_date, expiry_date, status)
  VALUES (p_hospital_id, p_contract_label, p_contract_years, COALESCE(p_total_value_rupees,0), p_signed_date, p_expiry_date, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_contract_r1959',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'label', p_contract_label, 'years', p_contract_years, 'value', p_total_value_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_renewals_r1959(p_contract_id uuid)
RETURNS TABLE(
  id uuid,
  contract_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text,
  value_change_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.contract_id, r.action_type, r.taken_at, r.by_email, r.notes_md, r.value_change_rupees
  FROM public.hospital_multi_year_renewal_log_r1959 r
  WHERE r.contract_id = p_contract_id
  ORDER BY r.taken_at DESC
  LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_renewal_r1959(
  p_contract_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text,
  p_value_change_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_multi_year_renewal_log_r1959(contract_id, action_type, by_email, notes_md, value_change_rupees)
  VALUES (p_contract_id, p_action_type, p_by_email, p_notes_md, COALESCE(p_value_change_rupees,0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_renewal_r1959',
          jsonb_build_object('id', v_id, 'contract_id', p_contract_id, 'action', p_action_type, 'value_change', p_value_change_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1959(p_contract_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_multi_year_contracts_r1959
  SET status = p_status, updated_at = now()
  WHERE id = p_contract_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1959',
          jsonb_build_object('id', p_contract_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.expiring_soon_r1959()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_email text,
  contract_label text,
  expiry_date date,
  days_to_expiry int,
  total_value_rupees bigint,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_id, p.email, c.contract_label, c.expiry_date,
         (c.expiry_date - CURRENT_DATE)::int AS days_to_expiry,
         c.total_value_rupees, c.status
  FROM public.hospital_multi_year_contracts_r1959 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  WHERE c.expiry_date IS NOT NULL
    AND c.expiry_date >= CURRENT_DATE
    AND c.expiry_date <= CURRENT_DATE + INTERVAL '90 days'
    AND c.status IN ('active','expiring_soon')
  ORDER BY c.expiry_date ASC
  LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_renewals_r1959()
RETURNS TABLE(
  id uuid,
  contract_id uuid,
  contract_label text,
  hospital_email text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  value_change_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.contract_id, c.contract_label, p.email, r.action_type, r.taken_at, r.by_email, r.value_change_rupees
  FROM public.hospital_multi_year_renewal_log_r1959 r
  JOIN public.hospital_multi_year_contracts_r1959 c ON c.id = r.contract_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_id
  ORDER BY r.taken_at DESC
  LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_contracts_r1959() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_contract_r1959(uuid, text, int, bigint, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_renewals_r1959(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_renewal_r1959(uuid, text, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1959(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_soon_r1959() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_renewals_r1959() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_contracts_r1959() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_contract_r1959(uuid, text, int, bigint, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_renewals_r1959(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_r1959(uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1959(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r1959() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_renewals_r1959() TO authenticated;

COMMIT;
