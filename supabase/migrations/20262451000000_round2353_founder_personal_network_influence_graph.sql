BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_network_contacts_r2353 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_name text NOT NULL,
  contact_role text NOT NULL CHECK (contact_role IN ('advisor','mentor','customer','founder','investor','operator','journalist')),
  organization text,
  relationship_strength int NOT NULL DEFAULT 3 CHECK (relationship_strength BETWEEN 1 AND 5),
  source_intro text,
  city text,
  country text DEFAULT 'IN',
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  added_by uuid REFERENCES public.profiles(id),
  added_at timestamptz NOT NULL DEFAULT now(),
  last_interaction_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_fnc_r2353_role ON public.founder_network_contacts_r2353(contact_role);
CREATE INDEX IF NOT EXISTS idx_fnc_r2353_strength ON public.founder_network_contacts_r2353(relationship_strength DESC);
CREATE INDEX IF NOT EXISTS idx_fnc_r2353_last ON public.founder_network_contacts_r2353(last_interaction_at DESC NULLS LAST);

CREATE TABLE IF NOT EXISTS public.founder_network_interactions_r2353 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.founder_network_contacts_r2353(id) ON DELETE CASCADE,
  interaction_type text NOT NULL CHECK (interaction_type IN ('call','meeting','email','message','event','intro','reference','dinner')),
  interaction_at timestamptz NOT NULL DEFAULT now(),
  summary text NOT NULL,
  value_score int CHECK (value_score BETWEEN 1 AND 5),
  follow_up_needed boolean NOT NULL DEFAULT false,
  follow_up_by date,
  logged_by uuid REFERENCES public.profiles(id),
  logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fni_r2353_contact ON public.founder_network_interactions_r2353(contact_id);
CREATE INDEX IF NOT EXISTS idx_fni_r2353_at ON public.founder_network_interactions_r2353(interaction_at DESC);
CREATE INDEX IF NOT EXISTS idx_fni_r2353_follow ON public.founder_network_interactions_r2353(follow_up_by) WHERE follow_up_needed = true;

ALTER TABLE public.founder_network_contacts_r2353 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_network_interactions_r2353 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fnc_r2353 ON public.founder_network_contacts_r2353;
CREATE POLICY founder_all_fnc_r2353 ON public.founder_network_contacts_r2353
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fni_r2353 ON public.founder_network_interactions_r2353;
CREATE POLICY founder_all_fni_r2353 ON public.founder_network_interactions_r2353
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list contacts with last interaction
DROP FUNCTION IF EXISTS public.list_network_contacts_r2353();
CREATE FUNCTION public.list_network_contacts_r2353()
RETURNS TABLE (
  id uuid,
  contact_name text,
  contact_role text,
  organization text,
  relationship_strength int,
  city text,
  is_active boolean,
  last_interaction_at timestamptz,
  days_since_contact int,
  interaction_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.contact_name, c.contact_role, c.organization, c.relationship_strength,
         c.city, c.is_active, c.last_interaction_at,
         CASE WHEN c.last_interaction_at IS NULL THEN NULL
              ELSE EXTRACT(DAY FROM (now() - c.last_interaction_at))::int END,
         COUNT(i.id)
  FROM public.founder_network_contacts_r2353 c
  LEFT JOIN public.founder_network_interactions_r2353 i ON i.contact_id = c.id
  GROUP BY c.id
  ORDER BY c.relationship_strength DESC, c.last_interaction_at DESC NULLS LAST;
END $$;

-- RPC 2: recent interactions
DROP FUNCTION IF EXISTS public.recent_interactions_r2353();
CREATE FUNCTION public.recent_interactions_r2353()
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  contact_name text,
  contact_role text,
  interaction_type text,
  interaction_at timestamptz,
  summary text,
  value_score int,
  follow_up_needed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.contact_id, c.contact_name, c.contact_role, i.interaction_type,
         i.interaction_at, i.summary, i.value_score, i.follow_up_needed
  FROM public.founder_network_interactions_r2353 i
  JOIN public.founder_network_contacts_r2353 c ON c.id = i.contact_id
  ORDER BY i.interaction_at DESC
  LIMIT 100;
END $$;

-- RPC 3: stale contacts (no interaction in 60+ days)
DROP FUNCTION IF EXISTS public.stale_contacts_r2353();
CREATE FUNCTION public.stale_contacts_r2353()
RETURNS TABLE (
  id uuid,
  contact_name text,
  contact_role text,
  organization text,
  relationship_strength int,
  last_interaction_at timestamptz,
  days_since_contact int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.contact_name, c.contact_role, c.organization, c.relationship_strength,
         c.last_interaction_at,
         CASE WHEN c.last_interaction_at IS NULL THEN 9999
              ELSE EXTRACT(DAY FROM (now() - c.last_interaction_at))::int END
  FROM public.founder_network_contacts_r2353 c
  WHERE c.is_active = true
    AND (c.last_interaction_at IS NULL OR c.last_interaction_at < now() - interval '60 days')
    AND c.relationship_strength >= 3
  ORDER BY c.relationship_strength DESC, c.last_interaction_at ASC NULLS FIRST;
END $$;

-- RPC 4: follow-ups due
DROP FUNCTION IF EXISTS public.follow_ups_due_r2353();
CREATE FUNCTION public.follow_ups_due_r2353()
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  contact_name text,
  contact_role text,
  summary text,
  follow_up_by date,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.contact_id, c.contact_name, c.contact_role, i.summary, i.follow_up_by,
         (i.follow_up_by - CURRENT_DATE)::int
  FROM public.founder_network_interactions_r2353 i
  JOIN public.founder_network_contacts_r2353 c ON c.id = i.contact_id
  WHERE i.follow_up_needed = true
    AND i.follow_up_by IS NOT NULL
  ORDER BY i.follow_up_by ASC;
END $$;

-- RPC 5: rollup by role
DROP FUNCTION IF EXISTS public.network_rollup_by_role_r2353();
CREATE FUNCTION public.network_rollup_by_role_r2353()
RETURNS TABLE (
  contact_role text,
  contact_count bigint,
  avg_strength numeric,
  active_count bigint,
  stale_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.contact_role,
         COUNT(*),
         ROUND(AVG(c.relationship_strength)::numeric, 2),
         COUNT(*) FILTER (WHERE c.is_active = true),
         COUNT(*) FILTER (WHERE c.last_interaction_at IS NULL OR c.last_interaction_at < now() - interval '60 days')
  FROM public.founder_network_contacts_r2353 c
  GROUP BY c.contact_role
  ORDER BY COUNT(*) DESC;
END $$;

-- RPC 6: top influencers (strength 4-5)
DROP FUNCTION IF EXISTS public.top_influencers_r2353();
CREATE FUNCTION public.top_influencers_r2353()
RETURNS TABLE (
  id uuid,
  contact_name text,
  contact_role text,
  organization text,
  relationship_strength int,
  interaction_count bigint,
  last_interaction_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.contact_name, c.contact_role, c.organization, c.relationship_strength,
         COUNT(i.id), c.last_interaction_at
  FROM public.founder_network_contacts_r2353 c
  LEFT JOIN public.founder_network_interactions_r2353 i ON i.contact_id = c.id
  WHERE c.relationship_strength >= 4 AND c.is_active = true
  GROUP BY c.id
  ORDER BY c.relationship_strength DESC, COUNT(i.id) DESC
  LIMIT 50;
END $$;

-- RPC 7: interaction-type distribution
DROP FUNCTION IF EXISTS public.interaction_type_distribution_r2353();
CREATE FUNCTION public.interaction_type_distribution_r2353()
RETURNS TABLE (
  interaction_type text,
  total_count bigint,
  avg_value_score numeric,
  last_30_days bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.interaction_type,
         COUNT(*),
         ROUND(AVG(i.value_score)::numeric, 2),
         COUNT(*) FILTER (WHERE i.interaction_at >= now() - interval '30 days')
  FROM public.founder_network_interactions_r2353 i
  GROUP BY i.interaction_type
  ORDER BY COUNT(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_network_contacts_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_interactions_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stale_contacts_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.follow_ups_due_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.network_rollup_by_role_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_influencers_r2353() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.interaction_type_distribution_r2353() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_network_contacts_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_interactions_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stale_contacts_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.follow_ups_due_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.network_rollup_by_role_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_influencers_r2353() TO authenticated;
GRANT EXECUTE ON FUNCTION public.interaction_type_distribution_r2353() TO authenticated;

COMMIT;
