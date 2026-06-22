BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_msa_r2267 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  primary_contact_user_id uuid REFERENCES public.profiles(id),
  primary_contact_email text,
  msa_start_date date NOT NULL,
  msa_end_date date NOT NULL,
  annual_value_rupees bigint NOT NULL CHECK (annual_value_rupees >= 0),
  hospital_count int NOT NULL DEFAULT 1 CHECK (hospital_count >= 1),
  current_terms text,
  renewal_status text NOT NULL DEFAULT 'upcoming' CHECK (renewal_status IN ('upcoming','negotiating','renewed','at_risk','lost')),
  non_renewal_risk text NOT NULL DEFAULT 'low' CHECK (non_renewal_risk IN ('low','medium','high','critical')),
  last_review_date date,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_msa_term_changes_r2267 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  msa_id uuid NOT NULL REFERENCES public.hospital_chain_msa_r2267(id) ON DELETE CASCADE,
  term_name text NOT NULL,
  current_value text,
  proposed_value text,
  rationale text,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','blocker')),
  by_email text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_msa_r2267 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_msa_term_changes_r2267 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2267_msa ON public.hospital_chain_msa_r2267;
CREATE POLICY founder_all_r2267_msa ON public.hospital_chain_msa_r2267
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2267_terms ON public.hospital_chain_msa_term_changes_r2267;
CREATE POLICY founder_all_r2267_terms ON public.hospital_chain_msa_term_changes_r2267
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list all MSAs ordered by end date asc
CREATE OR REPLACE FUNCTION public.list_chain_msa_r2267()
RETURNS TABLE (
  id uuid,
  chain_name text,
  primary_contact_user_id uuid,
  primary_contact_email text,
  msa_start_date date,
  msa_end_date date,
  days_to_renewal int,
  annual_value_rupees bigint,
  hospital_count int,
  current_terms text,
  renewal_status text,
  non_renewal_risk text,
  last_review_date date,
  owner_email text,
  notes text,
  term_change_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.chain_name,
    m.primary_contact_user_id,
    m.primary_contact_email,
    m.msa_start_date,
    m.msa_end_date,
    (m.msa_end_date - current_date)::int AS days_to_renewal,
    m.annual_value_rupees,
    m.hospital_count,
    m.current_terms,
    m.renewal_status,
    m.non_renewal_risk,
    m.last_review_date,
    m.owner_email,
    m.notes,
    (SELECT (COUNT(*))::int FROM public.hospital_chain_msa_term_changes_r2267 t WHERE t.msa_id = m.id)
  FROM public.hospital_chain_msa_r2267 m
  ORDER BY m.msa_end_date ASC, m.annual_value_rupees DESC
  LIMIT 500;
END;
$$;

-- RPC 2: upcoming renewals within N days
CREATE OR REPLACE FUNCTION public.upcoming_chain_msa_renewals_r2267(p_window_days int)
RETURNS TABLE (
  id uuid,
  chain_name text,
  msa_end_date date,
  days_to_renewal int,
  annual_value_rupees bigint,
  hospital_count int,
  renewal_status text,
  non_renewal_risk text,
  owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.chain_name,
    m.msa_end_date,
    (m.msa_end_date - current_date)::int AS days_to_renewal,
    m.annual_value_rupees,
    m.hospital_count,
    m.renewal_status,
    m.non_renewal_risk,
    m.owner_email
  FROM public.hospital_chain_msa_r2267 m
  WHERE m.msa_end_date >= current_date
    AND m.msa_end_date <= current_date + (COALESCE(p_window_days, 90)::int)
    AND m.renewal_status IN ('upcoming','negotiating','at_risk')
  ORDER BY m.msa_end_date ASC, m.annual_value_rupees DESC
  LIMIT 200;
END;
$$;

-- RPC 3: high risk MSAs
CREATE OR REPLACE FUNCTION public.high_risk_chain_msa_r2267()
RETURNS TABLE (
  id uuid,
  chain_name text,
  msa_end_date date,
  days_to_renewal int,
  annual_value_rupees bigint,
  hospital_count int,
  non_renewal_risk text,
  renewal_status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.chain_name,
    m.msa_end_date,
    (m.msa_end_date - current_date)::int AS days_to_renewal,
    m.annual_value_rupees,
    m.hospital_count,
    m.non_renewal_risk,
    m.renewal_status,
    m.owner_email,
    m.notes
  FROM public.hospital_chain_msa_r2267 m
  WHERE m.non_renewal_risk IN ('high','critical')
    AND m.renewal_status NOT IN ('renewed','lost')
  ORDER BY
    CASE m.non_renewal_risk WHEN 'critical' THEN 0 WHEN 'high' THEN 1 ELSE 2 END,
    m.annual_value_rupees DESC
  LIMIT 100;
END;
$$;

-- RPC 4: list term changes for an MSA
CREATE OR REPLACE FUNCTION public.list_chain_msa_term_changes_r2267(p_msa_id uuid)
RETURNS TABLE (
  id uuid,
  msa_id uuid,
  term_name text,
  current_value text,
  proposed_value text,
  rationale text,
  priority text,
  by_email text,
  at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.msa_id, t.term_name, t.current_value, t.proposed_value,
         t.rationale, t.priority, t.by_email, t.at
  FROM public.hospital_chain_msa_term_changes_r2267 t
  WHERE t.msa_id = p_msa_id
  ORDER BY
    CASE t.priority WHEN 'blocker' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    t.at DESC
  LIMIT 200;
END;
$$;

-- RPC 5: add a term change
CREATE OR REPLACE FUNCTION public.add_chain_msa_term_change_r2267(
  p_msa_id uuid,
  p_term_name text,
  p_current_value text,
  p_proposed_value text,
  p_rationale text,
  p_priority text,
  p_by_email text
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
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','medium','high','blocker') THEN
    RAISE EXCEPTION 'invalid priority';
  END IF;
  INSERT INTO public.hospital_chain_msa_term_changes_r2267(
    msa_id, term_name, current_value, proposed_value, rationale, priority, by_email
  ) VALUES (
    p_msa_id, p_term_name, p_current_value, p_proposed_value, p_rationale,
    COALESCE(p_priority, 'medium'), p_by_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2267_add_term_change',
    jsonb_build_object('id', v_id, 'msa_id', p_msa_id, 'term_name', p_term_name, 'priority', p_priority));
  RETURN v_id;
END;
$$;

-- RPC 6: update renewal status and risk
CREATE OR REPLACE FUNCTION public.update_chain_msa_status_r2267(
  p_msa_id uuid,
  p_renewal_status text,
  p_non_renewal_risk text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_renewal_status IS NOT NULL AND p_renewal_status NOT IN ('upcoming','negotiating','renewed','at_risk','lost') THEN
    RAISE EXCEPTION 'invalid renewal_status';
  END IF;
  IF p_non_renewal_risk IS NOT NULL AND p_non_renewal_risk NOT IN ('low','medium','high','critical') THEN
    RAISE EXCEPTION 'invalid non_renewal_risk';
  END IF;
  UPDATE public.hospital_chain_msa_r2267
    SET renewal_status = COALESCE(p_renewal_status, renewal_status),
        non_renewal_risk = COALESCE(p_non_renewal_risk, non_renewal_risk),
        notes = COALESCE(p_notes, notes),
        last_review_date = current_date,
        updated_at = now()
    WHERE id = p_msa_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2267_update_msa_status',
    jsonb_build_object('msa_id', p_msa_id, 'renewal_status', p_renewal_status, 'non_renewal_risk', p_non_renewal_risk));
END;
$$;

-- RPC 7: monthly renewal calendar bucket
CREATE OR REPLACE FUNCTION public.chain_msa_renewal_calendar_r2267()
RETURNS TABLE (
  bucket_month date,
  renewal_count int,
  total_annual_value_rupees bigint,
  at_risk_count int,
  high_risk_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', m.msa_end_date)::date AS bucket_month,
    (COUNT(*))::int AS renewal_count,
    (COALESCE(SUM(m.annual_value_rupees), 0))::bigint AS total_annual_value_rupees,
    (COUNT(*) FILTER (WHERE m.non_renewal_risk IN ('high','critical')))::int AS at_risk_count,
    (COALESCE(SUM(m.annual_value_rupees) FILTER (WHERE m.non_renewal_risk IN ('high','critical')), 0))::bigint AS high_risk_value_rupees
  FROM public.hospital_chain_msa_r2267 m
  WHERE m.msa_end_date >= current_date - interval '30 days'
    AND m.msa_end_date <= current_date + interval '365 days'
  GROUP BY date_trunc('month', m.msa_end_date)
  ORDER BY bucket_month ASC
  LIMIT 24;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_msa_r2267() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_chain_msa_renewals_r2267(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_risk_chain_msa_r2267() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_msa_term_changes_r2267(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_msa_term_change_r2267(uuid, text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_chain_msa_status_r2267(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_msa_renewal_calendar_r2267() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_msa_r2267() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_chain_msa_renewals_r2267(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_risk_chain_msa_r2267() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_msa_term_changes_r2267(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_msa_term_change_r2267(uuid, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_chain_msa_status_r2267(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_msa_renewal_calendar_r2267() TO authenticated;

COMMIT;
