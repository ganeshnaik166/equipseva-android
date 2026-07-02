BEGIN;

-- ============================================================================
-- Round 1811 — Hospital Decision Maker Map
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_decision_makers_r1811 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  person_name text NOT NULL,
  person_role text NOT NULL CHECK (person_role IN ('ceo','cmo','cfo','coo','biomed_head','procurement','department_head','board_member')),
  person_email text,
  has_budget_authority boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'influencer' CHECK (status IN ('primary','influencer','blocker','historical')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hdm_r1811_hospital ON public.hospital_decision_makers_r1811(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hdm_r1811_status ON public.hospital_decision_makers_r1811(status);

ALTER TABLE public.hospital_decision_makers_r1811 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdm_r1811_founder_all ON public.hospital_decision_makers_r1811;
CREATE POLICY hdm_r1811_founder_all ON public.hospital_decision_makers_r1811
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_decision_maker_relationships_r1811 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_maker_id uuid NOT NULL REFERENCES public.hospital_decision_makers_r1811(id) ON DELETE CASCADE,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('warm','lukewarm','cold','no_contact')),
  last_engaged_at timestamptz,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hdmr_r1811_dm ON public.hospital_decision_maker_relationships_r1811(decision_maker_id);
CREATE INDEX IF NOT EXISTS idx_hdmr_r1811_strength ON public.hospital_decision_maker_relationships_r1811(relationship_strength);

ALTER TABLE public.hospital_decision_maker_relationships_r1811 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hdmr_r1811_founder_all ON public.hospital_decision_maker_relationships_r1811;
CREATE POLICY hdmr_r1811_founder_all ON public.hospital_decision_maker_relationships_r1811
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_decision_makers
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_decision_makers_r1811();
CREATE OR REPLACE FUNCTION public.list_decision_makers_r1811()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  person_name text,
  person_role text,
  person_email text,
  has_budget_authority boolean,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_user_id, COALESCE(o.name, p.full_name, 'Unknown')::text AS hospital_name,
         d.person_name, d.person_role, d.person_email, d.has_budget_authority, d.status, d.created_at
  FROM public.hospital_decision_makers_r1811 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY d.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_decision_makers_r1811() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_makers_r1811() TO authenticated;

-- ============================================================================
-- RPC 2: add_decision_maker
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_decision_maker_r1811(uuid, text, text, text, boolean, text);
CREATE OR REPLACE FUNCTION public.add_decision_maker_r1811(
  p_hospital_user_id uuid,
  p_person_name text,
  p_person_role text,
  p_person_email text,
  p_has_budget_authority boolean,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_decision_makers_r1811(
    hospital_user_id, person_name, person_role, person_email, has_budget_authority, status
  ) VALUES (
    p_hospital_user_id, p_person_name, p_person_role, p_person_email, p_has_budget_authority, p_status
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_decision_maker_r1811',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'person_role', p_person_role));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_decision_maker_r1811(uuid, text, text, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_decision_maker_r1811(uuid, text, text, text, boolean, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_relationships
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_relationships_r1811();
CREATE OR REPLACE FUNCTION public.list_relationships_r1811()
RETURNS TABLE (
  id uuid,
  decision_maker_id uuid,
  person_name text,
  person_role text,
  hospital_name text,
  relationship_strength text,
  last_engaged_at timestamptz,
  founder_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.decision_maker_id, d.person_name, d.person_role,
         COALESCE(o.name, p.full_name, 'Unknown')::text AS hospital_name,
         r.relationship_strength, r.last_engaged_at, r.founder_note, r.created_at
  FROM public.hospital_decision_maker_relationships_r1811 r
  JOIN public.hospital_decision_makers_r1811 d ON d.id = r.decision_maker_id
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY r.last_engaged_at DESC NULLS LAST, r.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_relationships_r1811() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_relationships_r1811() TO authenticated;

-- ============================================================================
-- RPC 4: set_relationship
-- ============================================================================
DROP FUNCTION IF EXISTS public.set_relationship_r1811(uuid, text, timestamptz, text);
CREATE OR REPLACE FUNCTION public.set_relationship_r1811(
  p_decision_maker_id uuid,
  p_relationship_strength text,
  p_last_engaged_at timestamptz,
  p_founder_note text
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

  INSERT INTO public.hospital_decision_maker_relationships_r1811(
    decision_maker_id, relationship_strength, last_engaged_at, founder_note
  ) VALUES (
    p_decision_maker_id, p_relationship_strength, COALESCE(p_last_engaged_at, now()), p_founder_note
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_relationship_r1811',
          jsonb_build_object('id', v_id, 'decision_maker_id', p_decision_maker_id, 'strength', p_relationship_strength));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_relationship_r1811(uuid, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_relationship_r1811(uuid, text, timestamptz, text) TO authenticated;

-- ============================================================================
-- RPC 5: top_warm_relationships
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_warm_relationships_r1811();
CREATE OR REPLACE FUNCTION public.top_warm_relationships_r1811()
RETURNS TABLE (
  decision_maker_id uuid,
  person_name text,
  person_role text,
  hospital_name text,
  last_engaged_at timestamptz,
  founder_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (d.id) d.id, d.person_name, d.person_role,
         COALESCE(o.name, p.full_name, 'Unknown')::text AS hospital_name,
         r.last_engaged_at, r.founder_note
  FROM public.hospital_decision_maker_relationships_r1811 r
  JOIN public.hospital_decision_makers_r1811 d ON d.id = r.decision_maker_id
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE r.relationship_strength = 'warm'
  ORDER BY d.id, r.last_engaged_at DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_warm_relationships_r1811() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_warm_relationships_r1811() TO authenticated;

-- ============================================================================
-- RPC 6: blockers_per_hospital
-- ============================================================================
DROP FUNCTION IF EXISTS public.blockers_per_hospital_r1811();
CREATE OR REPLACE FUNCTION public.blockers_per_hospital_r1811()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  blocker_count int,
  blocker_names text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Unknown')::text AS hospital_name,
         (COUNT(*) FILTER (WHERE d.status = 'blocker'))::int AS blocker_count,
         string_agg(d.person_name || ' (' || d.person_role || ')', ', ' ORDER BY d.person_name) FILTER (WHERE d.status = 'blocker') AS blocker_names
  FROM public.hospital_decision_makers_r1811 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  GROUP BY d.hospital_user_id, o.name, p.full_name
  HAVING (COUNT(*) FILTER (WHERE d.status = 'blocker'))::int > 0
  ORDER BY blocker_count DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.blockers_per_hospital_r1811() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blockers_per_hospital_r1811() TO authenticated;

-- ============================================================================
-- RPC 7: budget_holders
-- ============================================================================
DROP FUNCTION IF EXISTS public.budget_holders_r1811();
CREATE OR REPLACE FUNCTION public.budget_holders_r1811()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  person_name text,
  person_role text,
  person_email text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.hospital_user_id,
         COALESCE(o.name, p.full_name, 'Unknown')::text AS hospital_name,
         d.person_name, d.person_role, d.person_email, d.status
  FROM public.hospital_decision_makers_r1811 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE d.has_budget_authority = true
  ORDER BY d.status, d.person_name
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.budget_holders_r1811() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_holders_r1811() TO authenticated;

COMMIT;