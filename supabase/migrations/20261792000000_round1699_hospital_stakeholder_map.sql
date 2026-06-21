BEGIN;

-- =====================================================
-- Round 1699: Hospital Stakeholder Map
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hospital_stakeholders_r1699 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  person_name text NOT NULL,
  person_role text NOT NULL,
  person_email text,
  relationship text NOT NULL CHECK (relationship IN ('champion','decision_maker','influencer','blocker','neutral')),
  influence_score int NOT NULL CHECK (influence_score BETWEEN 1 AND 10),
  last_engaged_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hs_r1699_hospital ON public.hospital_stakeholders_r1699(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hs_r1699_relationship ON public.hospital_stakeholders_r1699(relationship);

CREATE TABLE IF NOT EXISTS public.hospital_stakeholder_engagements_r1699 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stakeholder_id uuid NOT NULL REFERENCES public.hospital_stakeholders_r1699(id) ON DELETE CASCADE,
  engagement_type text NOT NULL CHECK (engagement_type IN ('call','visit','email','event')),
  engagement_at timestamptz NOT NULL DEFAULT now(),
  summary text,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hse_r1699_stakeholder ON public.hospital_stakeholder_engagements_r1699(stakeholder_id);
CREATE INDEX IF NOT EXISTS idx_hse_r1699_at ON public.hospital_stakeholder_engagements_r1699(engagement_at DESC);

ALTER TABLE public.hospital_stakeholders_r1699 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_stakeholder_engagements_r1699 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hs_r1699_founder_all ON public.hospital_stakeholders_r1699;
CREATE POLICY hs_r1699_founder_all ON public.hospital_stakeholders_r1699
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hse_r1699_founder_all ON public.hospital_stakeholder_engagements_r1699;
CREATE POLICY hse_r1699_founder_all ON public.hospital_stakeholder_engagements_r1699
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================
-- RPC 1: list_stakeholders
-- =====================================================
CREATE OR REPLACE FUNCTION public.list_stakeholders_r1699()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  person_name text,
  person_role text,
  person_email text,
  relationship text,
  influence_score int,
  last_engaged_at timestamptz,
  engagement_count int
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
    s.hospital_user_id,
    COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
    s.person_name,
    s.person_role,
    s.person_email,
    s.relationship,
    s.influence_score,
    s.last_engaged_at,
    (SELECT (COUNT(*))::int FROM public.hospital_stakeholder_engagements_r1699 e WHERE e.stakeholder_id = s.id) AS engagement_count
  FROM public.hospital_stakeholders_r1699 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.influence_score DESC, s.created_at DESC;
END;
$$;

-- =====================================================
-- RPC 2: add_stakeholder
-- =====================================================
CREATE OR REPLACE FUNCTION public.add_stakeholder_r1699(
  p_hospital_user_id uuid,
  p_person_name text,
  p_person_role text,
  p_person_email text,
  p_relationship text,
  p_influence_score int
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

  INSERT INTO public.hospital_stakeholders_r1699(
    hospital_user_id, person_name, person_role, person_email, relationship, influence_score
  ) VALUES (
    p_hospital_user_id, p_person_name, p_person_role, p_person_email, p_relationship, p_influence_score
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_stakeholder_r1699', jsonb_build_object(
    'id', v_id,
    'hospital_user_id', p_hospital_user_id,
    'person_name', p_person_name,
    'relationship', p_relationship,
    'influence_score', p_influence_score
  ));

  RETURN v_id;
END;
$$;

-- =====================================================
-- RPC 3: list_engagements
-- =====================================================
CREATE OR REPLACE FUNCTION public.list_engagements_r1699(p_stakeholder_id uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  stakeholder_id uuid,
  person_name text,
  hospital_user_id uuid,
  engagement_type text,
  engagement_at timestamptz,
  summary text,
  sentiment text
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
    e.id,
    e.stakeholder_id,
    s.person_name,
    s.hospital_user_id,
    e.engagement_type,
    e.engagement_at,
    e.summary,
    e.sentiment
  FROM public.hospital_stakeholder_engagements_r1699 e
  JOIN public.hospital_stakeholders_r1699 s ON s.id = e.stakeholder_id
  WHERE (p_stakeholder_id IS NULL OR e.stakeholder_id = p_stakeholder_id)
  ORDER BY e.engagement_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================
-- RPC 4: log_engagement
-- =====================================================
CREATE OR REPLACE FUNCTION public.log_engagement_r1699(
  p_stakeholder_id uuid,
  p_engagement_type text,
  p_summary text,
  p_sentiment text
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

  INSERT INTO public.hospital_stakeholder_engagements_r1699(
    stakeholder_id, engagement_type, summary, sentiment
  ) VALUES (
    p_stakeholder_id, p_engagement_type, p_summary, p_sentiment
  )
  RETURNING id INTO v_id;

  UPDATE public.hospital_stakeholders_r1699
  SET last_engaged_at = now(), updated_at = now()
  WHERE id = p_stakeholder_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engagement_r1699', jsonb_build_object(
    'id', v_id,
    'stakeholder_id', p_stakeholder_id,
    'engagement_type', p_engagement_type,
    'sentiment', p_sentiment
  ));

  RETURN v_id;
END;
$$;

-- =====================================================
-- RPC 5: top_influencers_per_hospital
-- =====================================================
CREATE OR REPLACE FUNCTION public.top_influencers_per_hospital_r1699()
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_name text,
  person_name text,
  person_role text,
  relationship text,
  influence_score int,
  last_engaged_at timestamptz
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
    s.hospital_user_id,
    COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
    s.person_name,
    s.person_role,
    s.relationship,
    s.influence_score,
    s.last_engaged_at
  FROM (
    SELECT DISTINCT ON (hospital_user_id)
      id, hospital_user_id, person_name, person_role, relationship, influence_score, last_engaged_at
    FROM public.hospital_stakeholders_r1699
    ORDER BY hospital_user_id, influence_score DESC, created_at DESC
  ) s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY s.influence_score DESC;
END;
$$;

-- =====================================================
-- RPC 6: blockers_to_address
-- =====================================================
CREATE OR REPLACE FUNCTION public.blockers_to_address_r1699()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  person_name text,
  person_role text,
  influence_score int,
  days_since_engagement int,
  last_engaged_at timestamptz
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
    s.hospital_user_id,
    COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
    s.person_name,
    s.person_role,
    s.influence_score,
    CASE
      WHEN s.last_engaged_at IS NULL THEN NULL
      ELSE EXTRACT(DAY FROM (now() - s.last_engaged_at))::int
    END AS days_since_engagement,
    s.last_engaged_at
  FROM public.hospital_stakeholders_r1699 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE s.relationship = 'blocker'
  ORDER BY s.influence_score DESC, s.last_engaged_at ASC NULLS FIRST;
END;
$$;

-- =====================================================
-- RPC 7: stakeholder_summary
-- =====================================================
CREATE OR REPLACE FUNCTION public.stakeholder_summary_r1699()
RETURNS TABLE(
  total_stakeholders int,
  champions int,
  decision_makers int,
  influencers int,
  blockers int,
  neutral_count int,
  avg_influence numeric,
  engagements_last_30d int,
  positive_sentiment_pct numeric,
  hospitals_covered int
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
    (SELECT (COUNT(*))::int FROM public.hospital_stakeholders_r1699) AS total_stakeholders,
    (SELECT (COUNT(*) FILTER (WHERE relationship = 'champion'))::int FROM public.hospital_stakeholders_r1699) AS champions,
    (SELECT (COUNT(*) FILTER (WHERE relationship = 'decision_maker'))::int FROM public.hospital_stakeholders_r1699) AS decision_makers,
    (SELECT (COUNT(*) FILTER (WHERE relationship = 'influencer'))::int FROM public.hospital_stakeholders_r1699) AS influencers,
    (SELECT (COUNT(*) FILTER (WHERE relationship = 'blocker'))::int FROM public.hospital_stakeholders_r1699) AS blockers,
    (SELECT (COUNT(*) FILTER (WHERE relationship = 'neutral'))::int FROM public.hospital_stakeholders_r1699) AS neutral_count,
    COALESCE((SELECT ROUND(AVG(influence_score)::numeric, 2) FROM public.hospital_stakeholders_r1699), 0) AS avg_influence,
    (SELECT (COUNT(*))::int FROM public.hospital_stakeholder_engagements_r1699 WHERE engagement_at > now() - interval '30 days') AS engagements_last_30d,
    COALESCE((
      SELECT ROUND(
        (COUNT(*) FILTER (WHERE sentiment = 'positive'))::numeric * 100.0 / NULLIF(COUNT(*), 0)::numeric,
        1
      )
      FROM public.hospital_stakeholder_engagements_r1699
      WHERE engagement_at > now() - interval '90 days'
    ), 0) AS positive_sentiment_pct,
    (SELECT (COUNT(DISTINCT hospital_user_id))::int FROM public.hospital_stakeholders_r1699) AS hospitals_covered;
END;
$$;

-- =====================================================
-- REVOKE + GRANT
-- =====================================================
REVOKE EXECUTE ON FUNCTION public.list_stakeholders_r1699() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_stakeholder_r1699(uuid, text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_engagements_r1699(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1699(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_influencers_per_hospital_r1699() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.blockers_to_address_r1699() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stakeholder_summary_r1699() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_stakeholders_r1699() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_stakeholder_r1699(uuid, text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_engagements_r1699(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1699(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_influencers_per_hospital_r1699() TO authenticated;
GRANT EXECUTE ON FUNCTION public.blockers_to_address_r1699() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stakeholder_summary_r1699() TO authenticated;

COMMIT;