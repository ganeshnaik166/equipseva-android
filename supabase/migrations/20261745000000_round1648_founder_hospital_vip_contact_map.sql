BEGIN;

-- =============================================================================
-- r1648 — Founder Hospital VIP Contact Map
-- Per-tier-A hospital decision-maker contact tree (CEO, biomedical head,
-- procurement) with relationship-tier scoring vs founder/CSM.
-- =============================================================================

-- ---------- TABLE 1: hospital_vip_contacts -----------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_vip_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  contact_name text NOT NULL,
  contact_role text NOT NULL CHECK (contact_role IN ('ceo','coo','biomedical_head','procurement_head','finance_head','medical_director','board_member','other')),
  contact_email text,
  contact_phone text,
  seniority_rank int NOT NULL DEFAULT 3 CHECK (seniority_rank BETWEEN 1 AND 5),
  relationship_tier text NOT NULL DEFAULT 'cold' CHECK (relationship_tier IN ('champion','warm','cold','hostile','unknown')),
  owned_by text NOT NULL DEFAULT 'founder' CHECK (owned_by IN ('founder','csm','sales','none')),
  hospital_tier text CHECK (hospital_tier IN ('A','B','C')),
  notes text,
  last_contacted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_vip_contacts_org ON public.hospital_vip_contacts(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hospital_vip_contacts_tier ON public.hospital_vip_contacts(hospital_tier);
CREATE INDEX IF NOT EXISTS idx_hospital_vip_contacts_relationship ON public.hospital_vip_contacts(relationship_tier);

ALTER TABLE public.hospital_vip_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hospital_vip_contacts_founder_only ON public.hospital_vip_contacts;
CREATE POLICY hospital_vip_contacts_founder_only ON public.hospital_vip_contacts
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ---------- TABLE 2: hospital_vip_touchpoints --------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_vip_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vip_contact_id uuid NOT NULL REFERENCES public.hospital_vip_contacts(id) ON DELETE CASCADE,
  touched_at timestamptz NOT NULL DEFAULT now(),
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('call','meeting','email','whatsapp','site_visit','event','gift')),
  outcome text CHECK (outcome IN ('positive','neutral','negative','no_response')),
  summary text,
  recorded_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_vip_touchpoints_contact ON public.hospital_vip_touchpoints(vip_contact_id);
CREATE INDEX IF NOT EXISTS idx_hospital_vip_touchpoints_at ON public.hospital_vip_touchpoints(touched_at DESC);

ALTER TABLE public.hospital_vip_touchpoints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS hospital_vip_touchpoints_founder_only ON public.hospital_vip_touchpoints;
CREATE POLICY hospital_vip_touchpoints_founder_only ON public.hospital_vip_touchpoints
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =============================================================================
-- RPC 1: founder_hospital_vip_tier_a_roster  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_tier_a_roster();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_tier_a_roster()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  state text,
  vip_count int,
  champion_count int,
  warm_count int,
  cold_count int,
  hostile_count int,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.name::text,
    o.state::text,
    (COUNT(v.id))::int,
    (COUNT(*) FILTER (WHERE v.relationship_tier = 'champion'))::int,
    (COUNT(*) FILTER (WHERE v.relationship_tier = 'warm'))::int,
    (COUNT(*) FILTER (WHERE v.relationship_tier = 'cold'))::int,
    (COUNT(*) FILTER (WHERE v.relationship_tier = 'hostile'))::int,
    MAX(v.last_contacted_at)
  FROM public.hospital_vip_contacts v
  JOIN public.organizations o ON o.id = v.hospital_org_id
  WHERE v.hospital_tier = 'A'
  GROUP BY o.id, o.name, o.state
  ORDER BY (COUNT(*) FILTER (WHERE v.relationship_tier = 'champion'))::int DESC, o.name;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_tier_a_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_tier_a_roster() TO authenticated;

-- =============================================================================
-- RPC 2: founder_hospital_vip_contact_tree  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_contact_tree();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_contact_tree()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  contact_name text,
  contact_role text,
  relationship_tier text,
  owned_by text,
  seniority_rank int,
  last_contacted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, o.name::text, v.contact_name, v.contact_role,
         v.relationship_tier, v.owned_by, v.seniority_rank, v.last_contacted_at
  FROM public.hospital_vip_contacts v
  JOIN public.organizations o ON o.id = v.hospital_org_id
  ORDER BY o.name, v.seniority_rank;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_contact_tree() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_contact_tree() TO authenticated;

-- =============================================================================
-- RPC 3: founder_hospital_vip_relationship_distribution  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_relationship_distribution();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_relationship_distribution()
RETURNS TABLE (
  relationship_tier text,
  contact_count int,
  tier_a_count int,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE total_count int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::int INTO total_count FROM public.hospital_vip_contacts;
  IF total_count = 0 THEN total_count := 1; END IF;
  RETURN QUERY
  SELECT v.relationship_tier,
         (COUNT(*))::int,
         (COUNT(*) FILTER (WHERE v.hospital_tier = 'A'))::int,
         ROUND((COUNT(*)::numeric / total_count) * 100, 1)
  FROM public.hospital_vip_contacts v
  GROUP BY v.relationship_tier
  ORDER BY (COUNT(*))::int DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_relationship_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_relationship_distribution() TO authenticated;

-- =============================================================================
-- RPC 4: founder_hospital_vip_stale_contacts  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_stale_contacts();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_stale_contacts()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  contact_name text,
  contact_role text,
  relationship_tier text,
  days_since_touch int,
  owned_by text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, o.name::text, v.contact_name, v.contact_role, v.relationship_tier,
         GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(v.last_contacted_at, v.created_at)))::int) AS days_since_touch,
         v.owned_by
  FROM public.hospital_vip_contacts v
  JOIN public.organizations o ON o.id = v.hospital_org_id
  WHERE v.hospital_tier = 'A'
    AND v.relationship_tier IN ('champion','warm')
    AND COALESCE(v.last_contacted_at, v.created_at) < now() - interval '30 days'
  ORDER BY COALESCE(v.last_contacted_at, v.created_at) ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_stale_contacts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_stale_contacts() TO authenticated;

-- =============================================================================
-- RPC 5: founder_hospital_vip_revenue_link  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_revenue_link();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_revenue_link()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  champion_count int,
  jobs_90d int,
  revenue_90d_rupees bigint,
  avg_rating numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id,
         o.name::text,
         (COUNT(*) FILTER (WHERE v.relationship_tier = 'champion'))::int,
         (COUNT(DISTINCT r.id) FILTER (WHERE r.created_at > now() - interval '90 days'))::int,
         COALESCE(SUM(r.contracted_amount_rupees) FILTER (WHERE r.created_at > now() - interval '90 days'), 0)::bigint,
         ROUND(AVG(r.hospital_rating) FILTER (WHERE r.hospital_rating IS NOT NULL), 2)
  FROM public.hospital_vip_contacts v
  JOIN public.organizations o ON o.id = v.hospital_org_id
  LEFT JOIN public.repair_jobs r ON r.hospital_org_id = o.id
  WHERE v.hospital_tier = 'A'
  GROUP BY o.id, o.name
  ORDER BY (SUM(r.contracted_amount_rupees) FILTER (WHERE r.created_at > now() - interval '90 days')) DESC NULLS LAST
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_revenue_link() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_revenue_link() TO authenticated;

-- =============================================================================
-- RPC 6: founder_hospital_vip_recent_touchpoints  (read)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_vip_recent_touchpoints();
CREATE OR REPLACE FUNCTION public.founder_hospital_vip_recent_touchpoints()
RETURNS TABLE (
  id uuid,
  touched_at timestamptz,
  hospital_name text,
  contact_name text,
  touchpoint_kind text,
  outcome text,
  summary text,
  recorded_by_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.touched_at, o.name::text, v.contact_name,
         t.touchpoint_kind, t.outcome, t.summary, t.recorded_by_email
  FROM public.hospital_vip_touchpoints t
  JOIN public.hospital_vip_contacts v ON v.id = t.vip_contact_id
  JOIN public.organizations o ON o.id = v.hospital_org_id
  ORDER BY t.touched_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_vip_recent_touchpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_vip_recent_touchpoints() TO authenticated;

-- =============================================================================
-- RPC 7: founder_log_vip_touchpoint  (write — VOLATILE)
-- =============================================================================
DROP FUNCTION IF EXISTS public.founder_log_vip_touchpoint(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.founder_log_vip_touchpoint(
  p_vip_contact_id uuid,
  p_touchpoint_kind text,
  p_outcome text,
  p_summary text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_vip_touchpoints(vip_contact_id, touchpoint_kind, outcome, summary, recorded_by_email)
  VALUES (p_vip_contact_id, p_touchpoint_kind, p_outcome, p_summary, (auth.jwt()->>'email'))
  RETURNING id INTO new_id;

  UPDATE public.hospital_vip_contacts
     SET last_contacted_at = now(), updated_at = now()
   WHERE id = p_vip_contact_id;

  INSERT INTO public.founder_action_log(action_kind, actor_email, payload)
  VALUES ('vip_touchpoint_logged', (auth.jwt()->>'email'),
          jsonb_build_object('vip_contact_id', p_vip_contact_id, 'kind', p_touchpoint_kind, 'outcome', p_outcome));

  RETURN new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_log_vip_touchpoint(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_log_vip_touchpoint(uuid, text, text, text) TO authenticated;

COMMIT;