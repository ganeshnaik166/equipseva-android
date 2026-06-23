BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_finance_contacts_r2335 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  contact_name text NOT NULL,
  contact_role text NOT NULL,
  contact_email text,
  contact_phone text,
  owns_ap boolean NOT NULL DEFAULT false,
  owns_dispute_resolution boolean NOT NULL DEFAULT false,
  escalation_tier int NOT NULL DEFAULT 2,
  our_touchpoint_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_contacted_at timestamptz,
  relationship_strength text NOT NULL DEFAULT 'unknown',
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_r2335_tier CHECK (escalation_tier BETWEEN 1 AND 4),
  CONSTRAINT chk_r2335_strength CHECK (relationship_strength IN ('strong','moderate','weak','unknown'))
);

CREATE INDEX IF NOT EXISTS idx_r2335_contacts_chain ON public.hospital_chain_finance_contacts_r2335(chain_name);
CREATE INDEX IF NOT EXISTS idx_r2335_contacts_tier ON public.hospital_chain_finance_contacts_r2335(escalation_tier);

CREATE TABLE IF NOT EXISTS public.hospital_chain_finance_interactions_r2335 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.hospital_chain_finance_contacts_r2335(id) ON DELETE CASCADE,
  interaction_type text NOT NULL,
  interaction_date date NOT NULL DEFAULT CURRENT_DATE,
  outcome text NOT NULL DEFAULT 'neutral',
  amount_resolved_rupees bigint,
  summary text,
  logged_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_r2335_itype CHECK (interaction_type IN ('call','email','meeting','dispute','escalation','payment_chase')),
  CONSTRAINT chk_r2335_outcome CHECK (outcome IN ('positive','neutral','negative','unresolved'))
);

CREATE INDEX IF NOT EXISTS idx_r2335_interactions_contact ON public.hospital_chain_finance_interactions_r2335(contact_id);
CREATE INDEX IF NOT EXISTS idx_r2335_interactions_date ON public.hospital_chain_finance_interactions_r2335(interaction_date DESC);

ALTER TABLE public.hospital_chain_finance_contacts_r2335 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_finance_interactions_r2335 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2335_contacts ON public.hospital_chain_finance_contacts_r2335;
CREATE POLICY founder_all_r2335_contacts ON public.hospital_chain_finance_contacts_r2335
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2335_interactions ON public.hospital_chain_finance_interactions_r2335;
CREATE POLICY founder_all_r2335_interactions ON public.hospital_chain_finance_interactions_r2335
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r2335_list_chains()
RETURNS TABLE(
  chain_name text,
  contact_count bigint,
  ap_owners bigint,
  dispute_owners bigint,
  tier1_contacts bigint,
  last_interaction_date date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.chain_name,
    COUNT(*)::bigint AS contact_count,
    COUNT(*) FILTER (WHERE c.owns_ap)::bigint AS ap_owners,
    COUNT(*) FILTER (WHERE c.owns_dispute_resolution)::bigint AS dispute_owners,
    COUNT(*) FILTER (WHERE c.escalation_tier = 1)::bigint AS tier1_contacts,
    MAX(c.last_contacted_at)::date AS last_interaction_date
  FROM public.hospital_chain_finance_contacts_r2335 c
  GROUP BY c.chain_name
  ORDER BY c.chain_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_list_contacts(p_chain text DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  chain_name text,
  contact_name text,
  contact_role text,
  contact_email text,
  owns_ap boolean,
  owns_dispute_resolution boolean,
  escalation_tier int,
  relationship_strength text,
  touchpoint_email text,
  last_contacted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.contact_name,
    c.contact_role,
    c.contact_email,
    c.owns_ap,
    c.owns_dispute_resolution,
    c.escalation_tier,
    c.relationship_strength,
    p.email AS touchpoint_email,
    c.last_contacted_at
  FROM public.hospital_chain_finance_contacts_r2335 c
  LEFT JOIN public.profiles p ON p.id = c.our_touchpoint_user_id
  WHERE p_chain IS NULL OR c.chain_name = p_chain
  ORDER BY c.chain_name, c.escalation_tier, c.contact_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_list_interactions(p_contact_id uuid DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  contact_id uuid,
  contact_name text,
  chain_name text,
  interaction_type text,
  interaction_date date,
  outcome text,
  amount_resolved_rupees bigint,
  summary text,
  logged_by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    i.contact_id,
    c.contact_name,
    c.chain_name,
    i.interaction_type,
    i.interaction_date,
    i.outcome,
    i.amount_resolved_rupees,
    i.summary,
    p.email AS logged_by_email
  FROM public.hospital_chain_finance_interactions_r2335 i
  JOIN public.hospital_chain_finance_contacts_r2335 c ON c.id = i.contact_id
  LEFT JOIN public.profiles p ON p.id = i.logged_by
  WHERE p_contact_id IS NULL OR i.contact_id = p_contact_id
  ORDER BY i.interaction_date DESC, i.created_at DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_upsert_contact(
  p_id uuid,
  p_chain_name text,
  p_contact_name text,
  p_contact_role text,
  p_contact_email text,
  p_contact_phone text,
  p_owns_ap boolean,
  p_owns_dispute_resolution boolean,
  p_escalation_tier int,
  p_relationship_strength text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_caller FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  IF p_id IS NULL THEN
    INSERT INTO public.hospital_chain_finance_contacts_r2335(
      chain_name, contact_name, contact_role, contact_email, contact_phone,
      owns_ap, owns_dispute_resolution, escalation_tier, relationship_strength, notes, created_by
    ) VALUES (
      p_chain_name, p_contact_name, p_contact_role, p_contact_email, p_contact_phone,
      p_owns_ap, p_owns_dispute_resolution, p_escalation_tier, p_relationship_strength, p_notes, v_caller
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE public.hospital_chain_finance_contacts_r2335 SET
      chain_name = p_chain_name,
      contact_name = p_contact_name,
      contact_role = p_contact_role,
      contact_email = p_contact_email,
      contact_phone = p_contact_phone,
      owns_ap = p_owns_ap,
      owns_dispute_resolution = p_owns_dispute_resolution,
      escalation_tier = p_escalation_tier,
      relationship_strength = p_relationship_strength,
      notes = p_notes,
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_log_interaction(
  p_contact_id uuid,
  p_interaction_type text,
  p_interaction_date date,
  p_outcome text,
  p_amount_resolved_rupees bigint,
  p_summary text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_caller FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  INSERT INTO public.hospital_chain_finance_interactions_r2335(
    contact_id, interaction_type, interaction_date, outcome, amount_resolved_rupees, summary, logged_by
  ) VALUES (
    p_contact_id, p_interaction_type, COALESCE(p_interaction_date, CURRENT_DATE), p_outcome, p_amount_resolved_rupees, p_summary, v_caller
  ) RETURNING id INTO v_id;
  UPDATE public.hospital_chain_finance_contacts_r2335 SET last_contacted_at = now(), updated_at = now() WHERE id = p_contact_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_assign_touchpoint(
  p_contact_id uuid,
  p_touchpoint_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_chain_finance_contacts_r2335
  SET our_touchpoint_user_id = p_touchpoint_user_id, updated_at = now()
  WHERE id = p_contact_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2335_summary()
RETURNS TABLE(
  total_chains bigint,
  total_contacts bigint,
  total_ap_owners bigint,
  total_dispute_owners bigint,
  chains_missing_ap_owner bigint,
  chains_missing_dispute_owner bigint,
  strong_relationships bigint,
  weak_relationships bigint,
  recent_interactions_30d bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH chain_agg AS (
    SELECT chain_name,
      bool_or(owns_ap) AS has_ap,
      bool_or(owns_dispute_resolution) AS has_dispute
    FROM public.hospital_chain_finance_contacts_r2335
    GROUP BY chain_name
  )
  SELECT
    (SELECT COUNT(DISTINCT chain_name) FROM public.hospital_chain_finance_contacts_r2335)::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_contacts_r2335)::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_contacts_r2335 WHERE owns_ap)::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_contacts_r2335 WHERE owns_dispute_resolution)::bigint,
    (SELECT COUNT(*) FROM chain_agg WHERE NOT has_ap)::bigint,
    (SELECT COUNT(*) FROM chain_agg WHERE NOT has_dispute)::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_contacts_r2335 WHERE relationship_strength = 'strong')::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_contacts_r2335 WHERE relationship_strength = 'weak')::bigint,
    (SELECT COUNT(*) FROM public.hospital_chain_finance_interactions_r2335 WHERE interaction_date >= CURRENT_DATE - INTERVAL '30 days')::bigint;
END;
$$;

REVOKE ALL ON FUNCTION public.r2335_list_chains() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_list_contacts(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_list_interactions(uuid, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_upsert_contact(uuid, text, text, text, text, text, boolean, boolean, int, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_log_interaction(uuid, text, date, text, bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_assign_touchpoint(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2335_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2335_list_chains() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_list_contacts(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_list_interactions(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_upsert_contact(uuid, text, text, text, text, text, boolean, boolean, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_log_interaction(uuid, text, date, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_assign_touchpoint(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2335_summary() TO authenticated;

COMMIT;
