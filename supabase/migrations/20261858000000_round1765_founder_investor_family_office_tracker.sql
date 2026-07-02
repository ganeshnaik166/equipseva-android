BEGIN;

-- ============================================================================
-- Round 1765 — Investor Family Office Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_family_offices_r1765 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_office_name text NOT NULL,
  primary_contact_name text NOT NULL,
  primary_contact_email text NOT NULL,
  family_generation_focus text NOT NULL CHECK (family_generation_focus IN ('current','next_gen','multi_gen')),
  investment_thesis_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'cultivating' CHECK (status IN ('engaged','cultivating','dormant')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ifo_r1765_status ON public.investor_family_offices_r1765(status);
CREATE INDEX IF NOT EXISTS idx_ifo_r1765_generation ON public.investor_family_offices_r1765(family_generation_focus);

CREATE TABLE IF NOT EXISTS public.investor_family_office_meetings_r1765 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_office_id uuid NOT NULL REFERENCES public.investor_family_offices_r1765(id) ON DELETE CASCADE,
  meeting_date date NOT NULL,
  attendee_emails text[] NOT NULL DEFAULT '{}',
  generation_attended text NOT NULL CHECK (generation_attended IN ('current','next_gen','both')),
  key_topics text NOT NULL DEFAULT '',
  follow_up_required boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ifom_r1765_family_office ON public.investor_family_office_meetings_r1765(family_office_id);
CREATE INDEX IF NOT EXISTS idx_ifom_r1765_meeting_date ON public.investor_family_office_meetings_r1765(meeting_date DESC);

ALTER TABLE public.investor_family_offices_r1765 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_family_office_meetings_r1765 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ifo_r1765_founder_all ON public.investor_family_offices_r1765;
CREATE POLICY p_ifo_r1765_founder_all ON public.investor_family_offices_r1765
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_ifom_r1765_founder_all ON public.investor_family_office_meetings_r1765;
CREATE POLICY p_ifom_r1765_founder_all ON public.investor_family_office_meetings_r1765
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.investor_family_offices_r1765 FROM PUBLIC, anon;
REVOKE ALL ON public.investor_family_office_meetings_r1765 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.investor_family_offices_r1765 TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investor_family_office_meetings_r1765 TO authenticated;

-- ============================================================================
-- RPC 1: list_family_offices_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_family_offices_r1765();
CREATE OR REPLACE FUNCTION public.list_family_offices_r1765()
RETURNS TABLE (
  id uuid,
  family_office_name text,
  primary_contact_name text,
  primary_contact_email text,
  family_generation_focus text,
  status text,
  investment_thesis_md text,
  meeting_count bigint,
  last_meeting_date date,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.family_office_name,
    f.primary_contact_name,
    f.primary_contact_email,
    f.family_generation_focus,
    f.status,
    f.investment_thesis_md,
    COALESCE(m.cnt, 0)::bigint AS meeting_count,
    m.last_dt AS last_meeting_date,
    f.created_at
  FROM public.investor_family_offices_r1765 f
  LEFT JOIN (
    SELECT family_office_id, COUNT(*)::bigint AS cnt, MAX(meeting_date) AS last_dt
    FROM public.investor_family_office_meetings_r1765
    GROUP BY family_office_id
  ) m ON m.family_office_id = f.id
  ORDER BY f.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_family_offices_r1765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_family_offices_r1765() TO authenticated;

-- ============================================================================
-- RPC 2: add_family_office_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_family_office_r1765(text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.add_family_office_r1765(
  p_name text,
  p_contact_name text,
  p_contact_email text,
  p_generation_focus text,
  p_thesis_md text
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

  INSERT INTO public.investor_family_offices_r1765(
    family_office_name, primary_contact_name, primary_contact_email,
    family_generation_focus, investment_thesis_md
  )
  VALUES (p_name, p_contact_name, p_contact_email, p_generation_focus, COALESCE(p_thesis_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1765.add_family_office',
    jsonb_build_object('id', v_id, 'name', p_name, 'generation', p_generation_focus)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_family_office_r1765(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_family_office_r1765(text, text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_meetings_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_meetings_r1765(uuid);
CREATE OR REPLACE FUNCTION public.list_meetings_r1765(p_family_office_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  family_office_id uuid,
  family_office_name text,
  meeting_date date,
  attendee_emails text[],
  generation_attended text,
  key_topics text,
  follow_up_required boolean,
  created_at timestamptz
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
    m.family_office_id,
    f.family_office_name,
    m.meeting_date,
    m.attendee_emails,
    m.generation_attended,
    m.key_topics,
    m.follow_up_required,
    m.created_at
  FROM public.investor_family_office_meetings_r1765 m
  JOIN public.investor_family_offices_r1765 f ON f.id = m.family_office_id
  WHERE (p_family_office_id IS NULL OR m.family_office_id = p_family_office_id)
  ORDER BY m.meeting_date DESC, m.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_meetings_r1765(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_meetings_r1765(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_meeting_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_meeting_r1765(uuid, date, text[], text, text, boolean);
CREATE OR REPLACE FUNCTION public.log_meeting_r1765(
  p_family_office_id uuid,
  p_meeting_date date,
  p_attendee_emails text[],
  p_generation_attended text,
  p_key_topics text,
  p_follow_up_required boolean
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

  INSERT INTO public.investor_family_office_meetings_r1765(
    family_office_id, meeting_date, attendee_emails,
    generation_attended, key_topics, follow_up_required
  )
  VALUES (
    p_family_office_id, p_meeting_date, COALESCE(p_attendee_emails, '{}'::text[]),
    p_generation_attended, COALESCE(p_key_topics,''), COALESCE(p_follow_up_required,false)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1765.log_meeting',
    jsonb_build_object('id', v_id, 'family_office_id', p_family_office_id, 'date', p_meeting_date)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_meeting_r1765(uuid, date, text[], text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_meeting_r1765(uuid, date, text[], text, text, boolean) TO authenticated;

-- ============================================================================
-- RPC 5: update_status_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.update_status_r1765(uuid, text);
CREATE OR REPLACE FUNCTION public.update_status_r1765(
  p_family_office_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_new_status NOT IN ('engaged','cultivating','dormant') THEN
    RAISE EXCEPTION 'invalid_status: %', p_new_status;
  END IF;

  UPDATE public.investor_family_offices_r1765
  SET status = p_new_status, updated_at = now()
  WHERE id = p_family_office_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1765.update_status',
    jsonb_build_object('id', p_family_office_id, 'new_status', p_new_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_status_r1765(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_status_r1765(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: active_family_offices_summary_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.active_family_offices_summary_r1765();
CREATE OR REPLACE FUNCTION public.active_family_offices_summary_r1765()
RETURNS TABLE (
  total_count bigint,
  engaged_count bigint,
  cultivating_count bigint,
  dormant_count bigint,
  meetings_last_30d bigint,
  follow_ups_pending bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.investor_family_offices_r1765)::bigint,
    (SELECT COUNT(*) FROM public.investor_family_offices_r1765 WHERE status = 'engaged')::bigint,
    (SELECT COUNT(*) FROM public.investor_family_offices_r1765 WHERE status = 'cultivating')::bigint,
    (SELECT COUNT(*) FROM public.investor_family_offices_r1765 WHERE status = 'dormant')::bigint,
    (SELECT COUNT(*) FROM public.investor_family_office_meetings_r1765 WHERE meeting_date >= (now()::date - INTERVAL '30 days'))::bigint,
    (SELECT COUNT(*) FROM public.investor_family_office_meetings_r1765 WHERE follow_up_required = true)::bigint;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.active_family_offices_summary_r1765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_family_offices_summary_r1765() TO authenticated;

-- ============================================================================
-- RPC 7: generation_engagement_summary_r1765
-- ============================================================================
DROP FUNCTION IF EXISTS public.generation_engagement_summary_r1765();
CREATE OR REPLACE FUNCTION public.generation_engagement_summary_r1765()
RETURNS TABLE (
  generation_bucket text,
  office_count bigint,
  meeting_count bigint,
  engaged_offices bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.family_generation_focus AS generation_bucket,
    COUNT(DISTINCT f.id)::bigint AS office_count,
    COALESCE(COUNT(m.id), 0)::bigint AS meeting_count,
    (COUNT(DISTINCT f.id) FILTER (WHERE f.status = 'engaged'))::bigint AS engaged_offices
  FROM public.investor_family_offices_r1765 f
  LEFT JOIN public.investor_family_office_meetings_r1765 m ON m.family_office_id = f.id
  GROUP BY f.family_generation_focus
  ORDER BY office_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.generation_engagement_summary_r1765() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generation_engagement_summary_r1765() TO authenticated;

COMMIT;