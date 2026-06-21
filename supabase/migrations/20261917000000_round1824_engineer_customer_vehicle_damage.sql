BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_vehicle_damage_incidents_r1824 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_registration text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  incident_date date NOT NULL DEFAULT CURRENT_DATE,
  damage_description text NOT NULL,
  estimated_damage_rupees bigint NOT NULL DEFAULT 0 CHECK (estimated_damage_rupees >= 0),
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported','investigating','settled','disputed','written_off')),
  settled_amount_rupees bigint CHECK (settled_amount_rupees IS NULL OR settled_amount_rupees >= 0),
  settled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_vehicle_insurance_claims_r1824 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES public.engineer_vehicle_damage_incidents_r1824(id) ON DELETE CASCADE,
  insurance_provider text NOT NULL,
  claim_filed_at timestamptz NOT NULL DEFAULT now(),
  claim_status text NOT NULL DEFAULT 'filed' CHECK (claim_status IN ('filed','processing','approved','rejected')),
  payout_rupees bigint CHECK (payout_rupees IS NULL OR payout_rupees >= 0),
  payout_received_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_vehicle_damage_incidents_r1824 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_vehicle_insurance_claims_r1824 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_incidents_r1824 ON public.engineer_vehicle_damage_incidents_r1824;
CREATE POLICY founder_all_incidents_r1824 ON public.engineer_vehicle_damage_incidents_r1824
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_claims_r1824 ON public.engineer_vehicle_insurance_claims_r1824;
CREATE POLICY founder_all_claims_r1824 ON public.engineer_vehicle_insurance_claims_r1824
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_evdi_r1824_engineer ON public.engineer_vehicle_damage_incidents_r1824(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evdi_r1824_status ON public.engineer_vehicle_damage_incidents_r1824(status);
CREATE INDEX IF NOT EXISTS idx_evic_r1824_incident ON public.engineer_vehicle_insurance_claims_r1824(incident_id);

-- 1. list_incidents
CREATE OR REPLACE FUNCTION public.list_incidents_r1824()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  vehicle_registration text,
  hospital_user_id uuid,
  hospital_email text,
  incident_date date,
  damage_description text,
  estimated_damage_rupees bigint,
  status text,
  settled_amount_rupees bigint,
  settled_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, ep.email, i.vehicle_registration,
         i.hospital_user_id, hp.email, i.incident_date, i.damage_description,
         i.estimated_damage_rupees, i.status, i.settled_amount_rupees, i.settled_at, i.created_at
  FROM public.engineer_vehicle_damage_incidents_r1824 i
  LEFT JOIN public.profiles ep ON ep.id = i.engineer_user_id
  LEFT JOIN public.profiles hp ON hp.id = i.hospital_user_id
  ORDER BY i.incident_date DESC, i.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_incident
CREATE OR REPLACE FUNCTION public.log_incident_r1824(
  p_engineer_user_id uuid,
  p_vehicle_registration text,
  p_hospital_user_id uuid,
  p_incident_date date,
  p_damage_description text,
  p_estimated_damage_rupees bigint
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
  INSERT INTO public.engineer_vehicle_damage_incidents_r1824(
    engineer_user_id, vehicle_registration, hospital_user_id, incident_date,
    damage_description, estimated_damage_rupees
  ) VALUES (
    p_engineer_user_id, p_vehicle_registration, p_hospital_user_id, COALESCE(p_incident_date, CURRENT_DATE),
    p_damage_description, COALESCE(p_estimated_damage_rupees, 0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_incident_r1824',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'estimated_damage_rupees', p_estimated_damage_rupees));

  RETURN v_id;
END;
$$;

-- 3. list_claims
CREATE OR REPLACE FUNCTION public.list_claims_r1824()
RETURNS TABLE (
  id uuid,
  incident_id uuid,
  vehicle_registration text,
  insurance_provider text,
  claim_filed_at timestamptz,
  claim_status text,
  payout_rupees bigint,
  payout_received_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.incident_id, i.vehicle_registration, c.insurance_provider,
         c.claim_filed_at, c.claim_status, c.payout_rupees, c.payout_received_at, c.created_at
  FROM public.engineer_vehicle_insurance_claims_r1824 c
  LEFT JOIN public.engineer_vehicle_damage_incidents_r1824 i ON i.id = c.incident_id
  ORDER BY c.claim_filed_at DESC
  LIMIT 200;
END;
$$;

-- 4. file_claim
CREATE OR REPLACE FUNCTION public.file_claim_r1824(
  p_incident_id uuid,
  p_insurance_provider text,
  p_claim_status text,
  p_payout_rupees bigint
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
  INSERT INTO public.engineer_vehicle_insurance_claims_r1824(
    incident_id, insurance_provider, claim_status, payout_rupees,
    payout_received_at
  ) VALUES (
    p_incident_id, p_insurance_provider, COALESCE(p_claim_status, 'filed'), p_payout_rupees,
    CASE WHEN p_claim_status = 'approved' THEN now() ELSE NULL END
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'file_claim_r1824',
    jsonb_build_object('id', v_id, 'incident_id', p_incident_id, 'insurance_provider', p_insurance_provider));

  RETURN v_id;
END;
$$;

-- 5. settle_incident
CREATE OR REPLACE FUNCTION public.settle_incident_r1824(
  p_incident_id uuid,
  p_settled_amount_rupees bigint,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_vehicle_damage_incidents_r1824
  SET settled_amount_rupees = p_settled_amount_rupees,
      settled_at = now(),
      status = COALESCE(p_status, 'settled'),
      updated_at = now()
  WHERE id = p_incident_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'settle_incident_r1824',
    jsonb_build_object('incident_id', p_incident_id, 'settled_amount_rupees', p_settled_amount_rupees, 'status', p_status));
END;
$$;

-- 6. incidents_by_engineer
CREATE OR REPLACE FUNCTION public.incidents_by_engineer_r1824()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  incident_count int,
  total_estimated_rupees bigint,
  total_settled_rupees bigint,
  open_incidents int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.engineer_user_id,
         p.email,
         COUNT(*)::int,
         COALESCE(SUM(i.estimated_damage_rupees), 0)::bigint,
         COALESCE(SUM(i.settled_amount_rupees), 0)::bigint,
         (COUNT(*) FILTER (WHERE i.status IN ('reported','investigating','disputed')))::int
  FROM public.engineer_vehicle_damage_incidents_r1824 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  GROUP BY i.engineer_user_id, p.email
  ORDER BY COUNT(*) DESC
  LIMIT 100;
END;
$$;

-- 7. recent_settlements
CREATE OR REPLACE FUNCTION public.recent_settlements_r1824()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  vehicle_registration text,
  estimated_damage_rupees bigint,
  settled_amount_rupees bigint,
  status text,
  settled_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, p.email, i.vehicle_registration,
         i.estimated_damage_rupees, i.settled_amount_rupees, i.status, i.settled_at
  FROM public.engineer_vehicle_damage_incidents_r1824 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  WHERE i.settled_at IS NOT NULL
  ORDER BY i.settled_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_incidents_r1824() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_incident_r1824(uuid, text, uuid, date, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_claims_r1824() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.file_claim_r1824(uuid, text, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.settle_incident_r1824(uuid, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.incidents_by_engineer_r1824() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_settlements_r1824() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_incidents_r1824() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_incident_r1824(uuid, text, uuid, date, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_claims_r1824() TO authenticated;
GRANT EXECUTE ON FUNCTION public.file_claim_r1824(uuid, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_incident_r1824(uuid, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.incidents_by_engineer_r1824() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_settlements_r1824() TO authenticated;

COMMIT;