BEGIN;

-- =====================================================================
-- Round 1813 — Investor Family Communications
-- Heavy founder console feature for tracking relationship-building
-- communications with investor spouse/family members.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_family_communications_r1813 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  family_member_name text NOT NULL,
  family_member_relationship text NOT NULL CHECK (family_member_relationship IN ('spouse','child','parent','sibling','other')),
  contact_type text NOT NULL CHECK (contact_type IN ('call','email','event','gift')),
  contact_at timestamptz NOT NULL DEFAULT now(),
  summary text,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ifc_r1813_investor ON public.investor_family_communications_r1813(investor_id);
CREATE INDEX IF NOT EXISTS idx_ifc_r1813_contact_at ON public.investor_family_communications_r1813(contact_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_family_engagement_events_r1813 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  communication_id uuid NOT NULL REFERENCES public.investor_family_communications_r1813(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('dinner','celebration','charity_event','sports','cultural','personal_milestone')),
  event_at timestamptz NOT NULL DEFAULT now(),
  attended boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ifee_r1813_comm ON public.investor_family_engagement_events_r1813(communication_id);
CREATE INDEX IF NOT EXISTS idx_ifee_r1813_event_at ON public.investor_family_engagement_events_r1813(event_at DESC);

ALTER TABLE public.investor_family_communications_r1813 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_family_engagement_events_r1813 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ifc_r1813_founder ON public.investor_family_communications_r1813;
CREATE POLICY p_ifc_r1813_founder ON public.investor_family_communications_r1813
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_ifee_r1813_founder ON public.investor_family_engagement_events_r1813;
CREATE POLICY p_ifee_r1813_founder ON public.investor_family_engagement_events_r1813
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_communications
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_investor_family_communications_r1813(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  family_member_name text,
  family_member_relationship text,
  contact_type text,
  contact_at timestamptz,
  summary text,
  founder_note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_id, c.family_member_name, c.family_member_relationship,
         c.contact_type, c.contact_at, c.summary, c.founder_note
  FROM public.investor_family_communications_r1813 c
  ORDER BY c.contact_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_investor_family_communications_r1813(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_family_communications_r1813(int) TO authenticated;

-- =====================================================================
-- RPC 2: log_communication
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_investor_family_communication_r1813(
  p_investor_id uuid,
  p_family_member_name text,
  p_family_member_relationship text,
  p_contact_type text,
  p_summary text,
  p_founder_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_family_communications_r1813
    (investor_id, family_member_name, family_member_relationship, contact_type, summary, founder_note)
  VALUES (p_investor_id, p_family_member_name, p_family_member_relationship, p_contact_type, p_summary, p_founder_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_family_communication_r1813',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'relationship', p_family_member_relationship, 'contact_type', p_contact_type));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_investor_family_communication_r1813(uuid, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_family_communication_r1813(uuid, text, text, text, text, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_events
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_investor_family_events_r1813(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  communication_id uuid,
  family_member_name text,
  event_type text,
  event_at timestamptz,
  attended boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.communication_id, c.family_member_name, e.event_type, e.event_at, e.attended
  FROM public.investor_family_engagement_events_r1813 e
  LEFT JOIN public.investor_family_communications_r1813 c ON c.id = e.communication_id
  ORDER BY e.event_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_investor_family_events_r1813(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_family_events_r1813(int) TO authenticated;

-- =====================================================================
-- RPC 4: log_event
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_investor_family_event_r1813(
  p_communication_id uuid,
  p_event_type text,
  p_attended boolean
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_family_engagement_events_r1813
    (communication_id, event_type, attended)
  VALUES (p_communication_id, p_event_type, COALESCE(p_attended, false))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_family_event_r1813',
    jsonb_build_object('id', v_id, 'communication_id', p_communication_id, 'event_type', p_event_type, 'attended', p_attended));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_investor_family_event_r1813(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_family_event_r1813(uuid, text, boolean) TO authenticated;

-- =====================================================================
-- RPC 5: top_engaged_families
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_engaged_investor_families_r1813(p_limit int DEFAULT 10)
RETURNS TABLE (
  investor_id uuid,
  family_member_name text,
  family_member_relationship text,
  touch_count int,
  last_contact_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.investor_id,
         c.family_member_name,
         c.family_member_relationship,
         (COUNT(*))::int AS touch_count,
         MAX(c.contact_at) AS last_contact_at
  FROM public.investor_family_communications_r1813 c
  GROUP BY c.investor_id, c.family_member_name, c.family_member_relationship
  ORDER BY touch_count DESC, last_contact_at DESC NULLS LAST
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_engaged_investor_families_r1813(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_engaged_investor_families_r1813(int) TO authenticated;

-- =====================================================================
-- RPC 6: recent_communications (last 30 days)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_investor_family_communications_r1813(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  family_member_name text,
  family_member_relationship text,
  contact_type text,
  contact_at timestamptz,
  summary text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_id, c.family_member_name, c.family_member_relationship,
         c.contact_type, c.contact_at, c.summary
  FROM public.investor_family_communications_r1813 c
  WHERE c.contact_at >= now() - make_interval(days => GREATEST(p_days, 1))
  ORDER BY c.contact_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_investor_family_communications_r1813(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_investor_family_communications_r1813(int) TO authenticated;

-- =====================================================================
-- RPC 7: engagement_summary
-- =====================================================================
CREATE OR REPLACE FUNCTION public.investor_family_engagement_summary_r1813()
RETURNS TABLE (
  total_communications int,
  total_events int,
  events_attended int,
  unique_investors int,
  unique_family_members int,
  calls_count int,
  emails_count int,
  events_count int,
  gifts_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.investor_family_communications_r1813)::int,
    (SELECT COUNT(*) FROM public.investor_family_engagement_events_r1813)::int,
    (SELECT (COUNT(*) FILTER (WHERE attended)) FROM public.investor_family_engagement_events_r1813)::int,
    (SELECT COUNT(DISTINCT investor_id) FROM public.investor_family_communications_r1813)::int,
    (SELECT COUNT(DISTINCT (investor_id, family_member_name)) FROM public.investor_family_communications_r1813)::int,
    (SELECT (COUNT(*) FILTER (WHERE contact_type = 'call')) FROM public.investor_family_communications_r1813)::int,
    (SELECT (COUNT(*) FILTER (WHERE contact_type = 'email')) FROM public.investor_family_communications_r1813)::int,
    (SELECT (COUNT(*) FILTER (WHERE contact_type = 'event')) FROM public.investor_family_communications_r1813)::int,
    (SELECT (COUNT(*) FILTER (WHERE contact_type = 'gift')) FROM public.investor_family_communications_r1813)::int;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.investor_family_engagement_summary_r1813() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.investor_family_engagement_summary_r1813() TO authenticated;

COMMIT;