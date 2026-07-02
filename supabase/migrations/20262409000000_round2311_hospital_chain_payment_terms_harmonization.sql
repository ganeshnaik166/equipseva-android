BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_payment_terms_r2311 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  current_terms text NOT NULL CHECK (current_terms IN ('NET-15','NET-30','NET-45','NET-60','NET-75','NET-90','NET-120')),
  target_terms text NOT NULL DEFAULT 'NET-30' CHECK (target_terms IN ('NET-15','NET-30','NET-45','NET-60','NET-75','NET-90','NET-120')),
  monthly_billing_rupees bigint NOT NULL DEFAULT 0,
  outstanding_rupees bigint NOT NULL DEFAULT 0,
  contract_start_date date,
  contract_renewal_date date,
  relationship_owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  harmonization_status text NOT NULL DEFAULT 'pending' CHECK (harmonization_status IN ('pending','in_negotiation','agreed','executed','rejected','at_risk')),
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_terms_events_r2311 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES public.hospital_chain_payment_terms_r2311(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('proposal_sent','counter_received','agreed','executed','rejected','escalated','reminder_sent')),
  from_terms text,
  to_terms text,
  event_notes text NOT NULL DEFAULT '',
  occurred_at timestamptz NOT NULL DEFAULT now(),
  recorded_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_payment_terms_r2311 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_terms_events_r2311 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_chain_terms_r2311 ON public.hospital_chain_payment_terms_r2311;
CREATE POLICY founder_all_chain_terms_r2311 ON public.hospital_chain_payment_terms_r2311
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_chain_events_r2311 ON public.hospital_chain_terms_events_r2311;
CREATE POLICY founder_all_chain_events_r2311 ON public.hospital_chain_terms_events_r2311
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_chains
CREATE OR REPLACE FUNCTION public.list_chain_terms_r2311()
RETURNS TABLE (
  id uuid,
  chain_name text,
  current_terms text,
  target_terms text,
  monthly_billing_rupees bigint,
  outstanding_rupees bigint,
  contract_renewal_date date,
  harmonization_status text,
  days_to_renewal int,
  gap_days int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.current_terms, c.target_terms,
    c.monthly_billing_rupees, c.outstanding_rupees, c.contract_renewal_date, c.harmonization_status,
    CASE WHEN c.contract_renewal_date IS NULL THEN NULL ELSE (c.contract_renewal_date - CURRENT_DATE)::int END AS days_to_renewal,
    (NULLIF(regexp_replace(c.current_terms, '\D', '', 'g'), '')::int
     - NULLIF(regexp_replace(c.target_terms, '\D', '', 'g'), '')::int)::int AS gap_days
  FROM public.hospital_chain_payment_terms_r2311 c
  ORDER BY c.outstanding_rupees DESC;
END;
$$;

-- RPC 2: add_chain
CREATE OR REPLACE FUNCTION public.add_chain_terms_r2311(
  p_chain_name text,
  p_current_terms text,
  p_target_terms text,
  p_monthly_billing_rupees bigint,
  p_outstanding_rupees bigint,
  p_contract_renewal_date date,
  p_relationship_owner_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_payment_terms_r2311 (
    chain_name, current_terms, target_terms, monthly_billing_rupees,
    outstanding_rupees, contract_renewal_date, relationship_owner_user_id
  ) VALUES (
    p_chain_name, p_current_terms, COALESCE(p_target_terms,'NET-30'),
    COALESCE(p_monthly_billing_rupees,0), COALESCE(p_outstanding_rupees,0),
    p_contract_renewal_date, p_relationship_owner_user_id
  )
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_chain_terms_r2311',
    jsonb_build_object('chain_id', v_id, 'name', p_chain_name, 'current', p_current_terms, 'target', p_target_terms));
  RETURN v_id;
END;
$$;

-- RPC 3: update_status
CREATE OR REPLACE FUNCTION public.update_chain_status_r2311(
  p_chain_id uuid,
  p_status text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_chain_payment_terms_r2311
  SET harmonization_status = p_status,
      notes_md = COALESCE(p_notes, notes_md),
      updated_at = now()
  WHERE id = p_chain_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_chain_status_r2311',
    jsonb_build_object('chain_id', p_chain_id, 'status', p_status));
END;
$$;

-- RPC 4: log_event
CREATE OR REPLACE FUNCTION public.log_chain_event_r2311(
  p_chain_id uuid,
  p_event_type text,
  p_from_terms text,
  p_to_terms text,
  p_event_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_terms_events_r2311 (
    chain_id, event_type, from_terms, to_terms, event_notes, recorded_by_user_id
  ) VALUES (
    p_chain_id, p_event_type, p_from_terms, p_to_terms, COALESCE(p_event_notes,''), auth.uid()
  )
  RETURNING id INTO v_id;
  IF p_event_type = 'executed' AND p_to_terms IS NOT NULL THEN
    UPDATE public.hospital_chain_payment_terms_r2311
    SET current_terms = p_to_terms, harmonization_status = 'executed', updated_at = now()
    WHERE id = p_chain_id;
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_chain_event_r2311',
    jsonb_build_object('chain_id', p_chain_id, 'event', p_event_type));
  RETURN v_id;
END;
$$;

-- RPC 5: risk_concentration_summary
CREATE OR REPLACE FUNCTION public.chain_risk_concentration_r2311()
RETURNS TABLE (
  total_chains int,
  chains_above_net30 int,
  total_outstanding_rupees bigint,
  outstanding_above_net30_rupees bigint,
  pct_outstanding_above_net30 numeric,
  largest_chain_name text,
  largest_chain_outstanding bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_outstanding bigint;
  v_above_outstanding bigint;
  v_largest_name text;
  v_largest_out bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(outstanding_rupees),0) INTO v_total_outstanding
    FROM public.hospital_chain_payment_terms_r2311;
  SELECT COALESCE(SUM(outstanding_rupees),0) INTO v_above_outstanding
    FROM public.hospital_chain_payment_terms_r2311
    WHERE NULLIF(regexp_replace(current_terms, '\D', '', 'g'), '')::int > 30;
  SELECT chain_name, outstanding_rupees INTO v_largest_name, v_largest_out
    FROM public.hospital_chain_payment_terms_r2311
    ORDER BY outstanding_rupees DESC NULLS LAST
    LIMIT 1;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_chain_payment_terms_r2311),
    (SELECT COUNT(*)::int FROM public.hospital_chain_payment_terms_r2311
      WHERE NULLIF(regexp_replace(current_terms, '\D', '', 'g'), '')::int > 30),
    v_total_outstanding,
    v_above_outstanding,
    CASE WHEN v_total_outstanding = 0 THEN 0::numeric
      ELSE ROUND((v_above_outstanding::numeric / v_total_outstanding::numeric) * 100, 2)
    END,
    v_largest_name,
    v_largest_out;
END;
$$;

-- RPC 6: chains_at_risk
CREATE OR REPLACE FUNCTION public.chains_at_risk_r2311()
RETURNS TABLE (
  id uuid,
  chain_name text,
  current_terms text,
  outstanding_rupees bigint,
  contract_renewal_date date,
  days_to_renewal int,
  harmonization_status text,
  risk_reason text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.current_terms, c.outstanding_rupees, c.contract_renewal_date,
    CASE WHEN c.contract_renewal_date IS NULL THEN NULL ELSE (c.contract_renewal_date - CURRENT_DATE)::int END,
    c.harmonization_status,
    CASE
      WHEN c.harmonization_status = 'rejected' THEN 'Chain rejected harmonization'
      WHEN c.harmonization_status = 'at_risk' THEN 'Flagged at risk by relationship owner'
      WHEN NULLIF(regexp_replace(c.current_terms, '\D', '', 'g'), '')::int >= 90 THEN 'Terms NET-90 or worse'
      WHEN c.outstanding_rupees > 1000000 AND NULLIF(regexp_replace(c.current_terms, '\D', '', 'g'), '')::int > 30
        THEN 'High outstanding above NET-30'
      ELSE 'Other'
    END
  FROM public.hospital_chain_payment_terms_r2311 c
  WHERE c.harmonization_status IN ('rejected','at_risk')
     OR NULLIF(regexp_replace(c.current_terms, '\D', '', 'g'), '')::int >= 90
     OR (c.outstanding_rupees > 1000000 AND NULLIF(regexp_replace(c.current_terms, '\D', '', 'g'), '')::int > 30)
  ORDER BY c.outstanding_rupees DESC;
END;
$$;

-- RPC 7: list_events
CREATE OR REPLACE FUNCTION public.list_chain_events_r2311(p_chain_id uuid)
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  event_type text,
  from_terms text,
  to_terms text,
  event_notes text,
  occurred_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_id, e.event_type, e.from_terms, e.to_terms, e.event_notes, e.occurred_at
  FROM public.hospital_chain_terms_events_r2311 e
  WHERE e.chain_id = p_chain_id
  ORDER BY e.occurred_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_terms_r2311() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_terms_r2311(text, text, text, bigint, bigint, date, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_chain_status_r2311(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_chain_event_r2311(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_risk_concentration_r2311() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chains_at_risk_r2311() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_events_r2311(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_terms_r2311() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_terms_r2311(text, text, text, bigint, bigint, date, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_chain_status_r2311(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_chain_event_r2311(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_risk_concentration_r2311() TO authenticated;
GRANT EXECUTE ON FUNCTION public.chains_at_risk_r2311() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_events_r2311(uuid) TO authenticated;

COMMIT;