BEGIN;

-- ============================================================
-- Round 1731: Hospital Contract Renewal Pipeline
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_renewal_pipeline_r1731 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  amc_contract_id uuid,
  expires_on date NOT NULL,
  renewal_probability_pct int NOT NULL DEFAULT 50 CHECK (renewal_probability_pct >= 0 AND renewal_probability_pct <= 100),
  owner_email text,
  last_outreach_at timestamptz,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','in_negotiation','renewed','lost','extended')),
  renewal_value_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renewal_pipe_r1731_status ON public.hospital_renewal_pipeline_r1731(status);
CREATE INDEX IF NOT EXISTS idx_renewal_pipe_r1731_expires ON public.hospital_renewal_pipeline_r1731(expires_on);

CREATE TABLE IF NOT EXISTS public.hospital_renewal_outreach_log_r1731 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.hospital_renewal_pipeline_r1731(id) ON DELETE CASCADE,
  outreach_type text NOT NULL CHECK (outreach_type IN ('call','email','visit','proposal','board_intro')),
  outreach_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renewal_out_r1731_pipe ON public.hospital_renewal_outreach_log_r1731(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_renewal_out_r1731_at ON public.hospital_renewal_outreach_log_r1731(outreach_at DESC);

ALTER TABLE public.hospital_renewal_pipeline_r1731 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_renewal_outreach_log_r1731 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_renewal_pipe_r1731 ON public.hospital_renewal_pipeline_r1731;
CREATE POLICY founder_all_renewal_pipe_r1731 ON public.hospital_renewal_pipeline_r1731
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_renewal_out_r1731 ON public.hospital_renewal_outreach_log_r1731;
CREATE POLICY founder_all_renewal_out_r1731 ON public.hospital_renewal_outreach_log_r1731
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_pipeline
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_pipeline_r1731(p_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  amc_contract_id uuid,
  expires_on date,
  days_until_expiry int,
  renewal_probability_pct int,
  owner_email text,
  last_outreach_at timestamptz,
  status text,
  renewal_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_user_id, pr.email AS hospital_email, p.amc_contract_id, p.expires_on,
           (p.expires_on - CURRENT_DATE)::int AS days_until_expiry,
           p.renewal_probability_pct, p.owner_email, p.last_outreach_at, p.status, p.renewal_value_rupees
    FROM public.hospital_renewal_pipeline_r1731 p
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
    WHERE p.expires_on <= CURRENT_DATE + (p_days || ' days')::interval
    ORDER BY p.expires_on ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_pipeline_r1731(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pipeline_r1731(int) TO authenticated;

-- ============================================================
-- RPC 2: upsert_pipeline_entry
-- ============================================================
CREATE OR REPLACE FUNCTION public.upsert_pipeline_entry_r1731(
  p_id uuid,
  p_hospital_user_id uuid,
  p_amc_contract_id uuid,
  p_expires_on date,
  p_probability int,
  p_owner_email text,
  p_status text,
  p_value bigint,
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

  IF p_id IS NULL THEN
    INSERT INTO public.hospital_renewal_pipeline_r1731(hospital_user_id, amc_contract_id, expires_on, renewal_probability_pct, owner_email, status, renewal_value_rupees, notes)
    VALUES (p_hospital_user_id, p_amc_contract_id, p_expires_on, COALESCE(p_probability, 50), p_owner_email, COALESCE(p_status,'upcoming'), COALESCE(p_value,0), p_notes)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.hospital_renewal_pipeline_r1731
       SET hospital_user_id = COALESCE(p_hospital_user_id, hospital_user_id),
           amc_contract_id = COALESCE(p_amc_contract_id, amc_contract_id),
           expires_on = COALESCE(p_expires_on, expires_on),
           renewal_probability_pct = COALESCE(p_probability, renewal_probability_pct),
           owner_email = COALESCE(p_owner_email, owner_email),
           status = COALESCE(p_status, status),
           renewal_value_rupees = COALESCE(p_value, renewal_value_rupees),
           notes = COALESCE(p_notes, notes),
           updated_at = now()
     WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'upsert_pipeline_entry_r1731',
          jsonb_build_object('id', v_id, 'status', p_status, 'value', p_value, 'expires_on', p_expires_on));

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.upsert_pipeline_entry_r1731(uuid,uuid,uuid,date,int,text,text,bigint,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_pipeline_entry_r1731(uuid,uuid,uuid,date,int,text,text,bigint,text) TO authenticated;

-- ============================================================
-- RPC 3: list_outreach
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_outreach_r1731(p_pipeline_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  outreach_type text,
  outreach_at timestamptz,
  by_email text,
  response text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.pipeline_id, o.outreach_type, o.outreach_at, o.by_email, o.response, o.notes
    FROM public.hospital_renewal_outreach_log_r1731 o
    WHERE (p_pipeline_id IS NULL OR o.pipeline_id = p_pipeline_id)
    ORDER BY o.outreach_at DESC
    LIMIT GREATEST(p_limit, 1);
END $$;

REVOKE EXECUTE ON FUNCTION public.list_outreach_r1731(uuid,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outreach_r1731(uuid,int) TO authenticated;

-- ============================================================
-- RPC 4: log_outreach
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_outreach_r1731(
  p_pipeline_id uuid,
  p_outreach_type text,
  p_response text,
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

  INSERT INTO public.hospital_renewal_outreach_log_r1731(pipeline_id, outreach_type, by_email, response, notes)
  VALUES (p_pipeline_id, p_outreach_type, (auth.jwt()->>'email'), p_response, p_notes)
  RETURNING id INTO v_id;

  UPDATE public.hospital_renewal_pipeline_r1731
     SET last_outreach_at = now(), updated_at = now()
   WHERE id = p_pipeline_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outreach_r1731',
          jsonb_build_object('outreach_id', v_id, 'pipeline_id', p_pipeline_id, 'type', p_outreach_type));

  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.log_outreach_r1731(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_outreach_r1731(uuid,text,text,text) TO authenticated;

-- ============================================================
-- RPC 5: close_renewal
-- ============================================================
CREATE OR REPLACE FUNCTION public.close_renewal_r1731(
  p_pipeline_id uuid,
  p_status text,
  p_final_value bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('renewed','lost','extended') THEN
    RAISE EXCEPTION 'invalid_close_status';
  END IF;

  UPDATE public.hospital_renewal_pipeline_r1731
     SET status = p_status,
         renewal_value_rupees = COALESCE(p_final_value, renewal_value_rupees),
         updated_at = now()
   WHERE id = p_pipeline_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_renewal_r1731',
          jsonb_build_object('pipeline_id', p_pipeline_id, 'status', p_status, 'value', p_final_value));

  RETURN p_pipeline_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.close_renewal_r1731(uuid,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_renewal_r1731(uuid,text,bigint) TO authenticated;

-- ============================================================
-- RPC 6: top_at_risk_renewals
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_at_risk_renewals_r1731(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  expires_on date,
  days_until_expiry int,
  renewal_probability_pct int,
  renewal_value_rupees bigint,
  status text,
  last_outreach_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_user_id, pr.email AS hospital_email,
           p.expires_on, (p.expires_on - CURRENT_DATE)::int AS days_until_expiry,
           p.renewal_probability_pct, p.renewal_value_rupees, p.status, p.last_outreach_at
    FROM public.hospital_renewal_pipeline_r1731 p
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
    WHERE p.status IN ('upcoming','in_negotiation')
      AND p.renewal_probability_pct < 60
      AND p.expires_on <= CURRENT_DATE + INTERVAL '90 days'
    ORDER BY p.renewal_value_rupees DESC, p.expires_on ASC
    LIMIT GREATEST(p_limit, 1);
END $$;

REVOKE EXECUTE ON FUNCTION public.top_at_risk_renewals_r1731(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_at_risk_renewals_r1731(int) TO authenticated;

-- ============================================================
-- RPC 7: recently_renewed
-- ============================================================
CREATE OR REPLACE FUNCTION public.recently_renewed_r1731(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  expires_on date,
  status text,
  renewal_value_rupees bigint,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_user_id, pr.email AS hospital_email, p.expires_on, p.status, p.renewal_value_rupees, p.updated_at
    FROM public.hospital_renewal_pipeline_r1731 p
    LEFT JOIN public.profiles pr ON pr.id = p.hospital_user_id
    WHERE p.status IN ('renewed','extended')
      AND p.updated_at >= now() - (p_days || ' days')::interval
    ORDER BY p.updated_at DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.recently_renewed_r1731(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recently_renewed_r1731(int) TO authenticated;

COMMIT;