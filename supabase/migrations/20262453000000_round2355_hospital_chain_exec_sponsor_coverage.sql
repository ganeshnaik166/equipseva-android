BEGIN;

-- =====================================================================
-- r2355: Hospital chain executive-sponsor coverage
-- For each hospital chain, who on our side is exec sponsor, when was
-- last contact, how strong is the sponsor-relationship.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLE 1: chain sponsor assignments
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chain_exec_sponsors_r2355 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL DEFAULT 'tier_2'
    CHECK (chain_tier IN ('tier_1','tier_2','tier_3','strategic')),
  hospital_count int NOT NULL DEFAULT 0 CHECK (hospital_count >= 0),
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0 CHECK (annual_contract_value_rupees >= 0),
  sponsor_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  sponsor_name text NOT NULL,
  sponsor_title text NOT NULL DEFAULT 'Account Executive',
  sponsor_email text,
  counterpart_name text NOT NULL,
  counterpart_title text,
  counterpart_email text,
  relationship_strength text NOT NULL DEFAULT 'warm'
    CHECK (relationship_strength IN ('cold','warm','strong','champion','at_risk')),
  last_contact_at timestamptz,
  next_qbr_scheduled_at timestamptz,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_exec_sponsors_r2355_chain
  ON public.chain_exec_sponsors_r2355 (chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_exec_sponsors_r2355_strength
  ON public.chain_exec_sponsors_r2355 (relationship_strength);
CREATE INDEX IF NOT EXISTS idx_chain_exec_sponsors_r2355_last_contact
  ON public.chain_exec_sponsors_r2355 (last_contact_at DESC NULLS LAST);

ALTER TABLE public.chain_exec_sponsors_r2355 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_chain_exec_sponsors_r2355
  ON public.chain_exec_sponsors_r2355;
CREATE POLICY founder_all_chain_exec_sponsors_r2355
  ON public.chain_exec_sponsors_r2355
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- TABLE 2: contact touch log
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chain_exec_sponsor_touches_r2355 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_assignment_id uuid NOT NULL
    REFERENCES public.chain_exec_sponsors_r2355(id) ON DELETE CASCADE,
  touched_at timestamptz NOT NULL DEFAULT now(),
  touch_type text NOT NULL DEFAULT 'email'
    CHECK (touch_type IN ('email','call','meeting','qbr','escalation','site_visit')),
  summary text NOT NULL,
  sentiment text NOT NULL DEFAULT 'neutral'
    CHECK (sentiment IN ('positive','neutral','negative','at_risk')),
  logged_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  logged_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_exec_sponsor_touches_r2355_assignment
  ON public.chain_exec_sponsor_touches_r2355 (sponsor_assignment_id, touched_at DESC);
CREATE INDEX IF NOT EXISTS idx_chain_exec_sponsor_touches_r2355_when
  ON public.chain_exec_sponsor_touches_r2355 (touched_at DESC);

ALTER TABLE public.chain_exec_sponsor_touches_r2355 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_chain_exec_sponsor_touches_r2355
  ON public.chain_exec_sponsor_touches_r2355;
CREATE POLICY founder_all_chain_exec_sponsor_touches_r2355
  ON public.chain_exec_sponsor_touches_r2355
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- RPC 1: coverage list
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_coverage_list()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  hospital_count int,
  annual_contract_value_rupees bigint,
  sponsor_name text,
  sponsor_title text,
  counterpart_name text,
  counterpart_title text,
  relationship_strength text,
  last_contact_at timestamptz,
  days_since_contact int,
  next_qbr_scheduled_at timestamptz,
  is_active boolean
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
    SELECT
      s.id,
      s.chain_name,
      s.chain_tier,
      s.hospital_count,
      s.annual_contract_value_rupees,
      s.sponsor_name,
      s.sponsor_title,
      s.counterpart_name,
      s.counterpart_title,
      s.relationship_strength,
      s.last_contact_at,
      CASE WHEN s.last_contact_at IS NULL THEN NULL
           ELSE EXTRACT(DAY FROM (now() - s.last_contact_at))::int
      END AS days_since_contact,
      s.next_qbr_scheduled_at,
      s.is_active
    FROM public.chain_exec_sponsors_r2355 s
    ORDER BY
      CASE s.chain_tier
        WHEN 'strategic' THEN 1
        WHEN 'tier_1' THEN 2
        WHEN 'tier_2' THEN 3
        WHEN 'tier_3' THEN 4
      END,
      s.annual_contract_value_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_coverage_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_coverage_list() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: strength distribution
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_strength_distribution()
RETURNS TABLE (
  relationship_strength text,
  chain_count bigint,
  hospital_count_sum bigint,
  acv_rupees_sum bigint
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
    SELECT
      s.relationship_strength,
      COUNT(*)::bigint AS chain_count,
      COALESCE(SUM(s.hospital_count),0)::bigint AS hospital_count_sum,
      COALESCE(SUM(s.annual_contract_value_rupees),0)::bigint AS acv_rupees_sum
    FROM public.chain_exec_sponsors_r2355 s
    WHERE s.is_active = true
    GROUP BY s.relationship_strength
    ORDER BY
      CASE s.relationship_strength
        WHEN 'champion' THEN 1
        WHEN 'strong' THEN 2
        WHEN 'warm' THEN 3
        WHEN 'cold' THEN 4
        WHEN 'at_risk' THEN 5
      END;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_strength_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_strength_distribution() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: stale contact alert (>= 30 days)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_stale_contacts()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  sponsor_name text,
  counterpart_name text,
  last_contact_at timestamptz,
  days_since_contact int,
  relationship_strength text
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
    SELECT
      s.id,
      s.chain_name,
      s.chain_tier,
      s.sponsor_name,
      s.counterpart_name,
      s.last_contact_at,
      CASE WHEN s.last_contact_at IS NULL THEN 9999
           ELSE EXTRACT(DAY FROM (now() - s.last_contact_at))::int
      END AS days_since_contact,
      s.relationship_strength
    FROM public.chain_exec_sponsors_r2355 s
    WHERE s.is_active = true
      AND (
        s.last_contact_at IS NULL
        OR s.last_contact_at < (now() - interval '30 days')
      )
    ORDER BY s.last_contact_at ASC NULLS FIRST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_stale_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_stale_contacts() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: at-risk chains
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_at_risk_chains()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  annual_contract_value_rupees bigint,
  sponsor_name text,
  counterpart_name text,
  last_contact_at timestamptz,
  notes text
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
    SELECT
      s.id,
      s.chain_name,
      s.chain_tier,
      s.annual_contract_value_rupees,
      s.sponsor_name,
      s.counterpart_name,
      s.last_contact_at,
      s.notes
    FROM public.chain_exec_sponsors_r2355 s
    WHERE s.is_active = true
      AND s.relationship_strength IN ('at_risk','cold')
    ORDER BY s.annual_contract_value_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_at_risk_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_at_risk_chains() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: upcoming QBRs
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_upcoming_qbrs()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  sponsor_name text,
  counterpart_name text,
  next_qbr_scheduled_at timestamptz,
  days_until int
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
    SELECT
      s.id,
      s.chain_name,
      s.chain_tier,
      s.sponsor_name,
      s.counterpart_name,
      s.next_qbr_scheduled_at,
      EXTRACT(DAY FROM (s.next_qbr_scheduled_at - now()))::int AS days_until
    FROM public.chain_exec_sponsors_r2355 s
    WHERE s.is_active = true
      AND s.next_qbr_scheduled_at IS NOT NULL
      AND s.next_qbr_scheduled_at >= now()
      AND s.next_qbr_scheduled_at <= (now() + interval '60 days')
    ORDER BY s.next_qbr_scheduled_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_upcoming_qbrs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_upcoming_qbrs() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: recent touch log (latest 50)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_recent_touches()
RETURNS TABLE (
  id uuid,
  chain_name text,
  touched_at timestamptz,
  touch_type text,
  sentiment text,
  summary text,
  logged_by_email text
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
    SELECT
      t.id,
      s.chain_name,
      t.touched_at,
      t.touch_type,
      t.sentiment,
      t.summary,
      t.logged_by_email
    FROM public.chain_exec_sponsor_touches_r2355 t
    JOIN public.chain_exec_sponsors_r2355 s
      ON s.id = t.sponsor_assignment_id
    ORDER BY t.touched_at DESC
    LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_recent_touches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_recent_touches() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: portfolio summary
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_r2355_portfolio_summary()
RETURNS TABLE (
  total_chains bigint,
  active_chains bigint,
  total_hospitals bigint,
  total_acv_rupees bigint,
  champion_count bigint,
  at_risk_count bigint,
  stale_contact_count bigint,
  unassigned_count bigint
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
    SELECT
      COUNT(*)::bigint AS total_chains,
      COUNT(*) FILTER (WHERE s.is_active)::bigint AS active_chains,
      COALESCE(SUM(s.hospital_count) FILTER (WHERE s.is_active),0)::bigint AS total_hospitals,
      COALESCE(SUM(s.annual_contract_value_rupees) FILTER (WHERE s.is_active),0)::bigint AS total_acv_rupees,
      COUNT(*) FILTER (WHERE s.is_active AND s.relationship_strength = 'champion')::bigint AS champion_count,
      COUNT(*) FILTER (WHERE s.is_active AND s.relationship_strength IN ('at_risk','cold'))::bigint AS at_risk_count,
      COUNT(*) FILTER (
        WHERE s.is_active
          AND (s.last_contact_at IS NULL OR s.last_contact_at < (now() - interval '30 days'))
      )::bigint AS stale_contact_count,
      COUNT(*) FILTER (WHERE s.is_active AND s.sponsor_profile_id IS NULL)::bigint AS unassigned_count
    FROM public.chain_exec_sponsors_r2355 s;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_r2355_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_r2355_portfolio_summary() TO authenticated;

COMMIT;
