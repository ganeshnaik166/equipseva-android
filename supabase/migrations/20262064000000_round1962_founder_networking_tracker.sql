BEGIN;

-- ============================================================================
-- Round 1962: Founder Networking Tracker
-- Track founder networking contacts and interaction log
-- ============================================================================

-- Contacts table
CREATE TABLE IF NOT EXISTS public.founder_networking_tracker_r1962 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_name text NOT NULL,
  contact_organization text,
  contact_role text,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('cold','warm','strong','very_strong','inner_circle')),
  last_interaction_at timestamptz,
  next_followup_due_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','cold','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Interaction log table
CREATE TABLE IF NOT EXISTS public.founder_networking_interaction_log_r1962 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.founder_networking_tracker_r1962(id) ON DELETE CASCADE,
  interaction_type text NOT NULL CHECK (interaction_type IN ('intro_made','coffee_chat','intro_received','asked_favor','gave_favor','quarterly_checkin')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_nwt_r1962_status ON public.founder_networking_tracker_r1962(status);
CREATE INDEX IF NOT EXISTS idx_nwt_r1962_followup ON public.founder_networking_tracker_r1962(next_followup_due_at);
CREATE INDEX IF NOT EXISTS idx_nwil_r1962_contact ON public.founder_networking_interaction_log_r1962(contact_id);
CREATE INDEX IF NOT EXISTS idx_nwil_r1962_taken ON public.founder_networking_interaction_log_r1962(taken_at DESC);

-- RLS
ALTER TABLE public.founder_networking_tracker_r1962 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_networking_interaction_log_r1962 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_nwt_r1962 ON public.founder_networking_tracker_r1962;
CREATE POLICY founder_all_nwt_r1962 ON public.founder_networking_tracker_r1962
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_nwil_r1962 ON public.founder_networking_interaction_log_r1962;
CREATE POLICY founder_all_nwil_r1962 ON public.founder_networking_interaction_log_r1962
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_contacts
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_contacts_r1962();
CREATE OR REPLACE FUNCTION public.list_contacts_r1962()
RETURNS TABLE (
  id uuid,
  contact_name text,
  contact_organization text,
  contact_role text,
  relationship_strength text,
  last_interaction_at timestamptz,
  next_followup_due_at timestamptz,
  status text,
  created_at timestamptz
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
    SELECT c.id, c.contact_name, c.contact_organization, c.contact_role,
           c.relationship_strength, c.last_interaction_at, c.next_followup_due_at,
           c.status, c.created_at
      FROM public.founder_networking_tracker_r1962 c
     ORDER BY c.created_at DESC
     LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_contacts_r1962() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_contacts_r1962() TO authenticated;

-- ============================================================================
-- RPC 2: log_contact
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_contact_r1962(text, text, text, text, timestamptz);
CREATE OR REPLACE FUNCTION public.log_contact_r1962(
  p_contact_name text,
  p_contact_organization text,
  p_contact_role text,
  p_relationship_strength text,
  p_next_followup_due_at timestamptz
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
  INSERT INTO public.founder_networking_tracker_r1962
    (contact_name, contact_organization, contact_role, relationship_strength, next_followup_due_at)
    VALUES (p_contact_name, p_contact_organization, p_contact_role, p_relationship_strength, p_next_followup_due_at)
    RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_contact_r1962',
            jsonb_build_object('contact_id', v_id, 'contact_name', p_contact_name, 'relationship_strength', p_relationship_strength));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_contact_r1962(text, text, text, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_contact_r1962(text, text, text, text, timestamptz) TO authenticated;

-- ============================================================================
-- RPC 3: list_interactions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_interactions_r1962(uuid);
CREATE OR REPLACE FUNCTION public.list_interactions_r1962(p_contact_id uuid)
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  interaction_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
    SELECT l.id, l.contact_id, l.interaction_type, l.taken_at, l.by_email, l.notes_md
      FROM public.founder_networking_interaction_log_r1962 l
     WHERE l.contact_id = p_contact_id
     ORDER BY l.taken_at DESC
     LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_interactions_r1962(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_interactions_r1962(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_interaction
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_interaction_r1962(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_interaction_r1962(
  p_contact_id uuid,
  p_interaction_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_networking_interaction_log_r1962
    (contact_id, interaction_type, by_email, notes_md)
    VALUES (p_contact_id, p_interaction_type, v_email, p_notes_md)
    RETURNING id INTO v_id;

  UPDATE public.founder_networking_tracker_r1962
     SET last_interaction_at = now(), updated_at = now()
   WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_interaction_r1962',
            jsonb_build_object('contact_id', p_contact_id, 'interaction_type', p_interaction_type, 'interaction_id', v_id));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_interaction_r1962(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_interaction_r1962(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_status_r1962(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r1962(
  p_contact_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_networking_tracker_r1962
     SET status = p_status, updated_at = now()
   WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1962',
            jsonb_build_object('contact_id', p_contact_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1962(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r1962(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: due_followups
-- ============================================================================
DROP FUNCTION IF EXISTS public.due_followups_r1962();
CREATE OR REPLACE FUNCTION public.due_followups_r1962()
RETURNS TABLE (
  id uuid,
  contact_name text,
  contact_organization text,
  relationship_strength text,
  next_followup_due_at timestamptz,
  days_overdue numeric
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
    SELECT c.id, c.contact_name, c.contact_organization, c.relationship_strength,
           c.next_followup_due_at,
           ROUND(EXTRACT(EPOCH FROM (now() - c.next_followup_due_at)) / 86400.0, 1) AS days_overdue
      FROM public.founder_networking_tracker_r1962 c
     WHERE c.status = 'active'
       AND c.next_followup_due_at IS NOT NULL
       AND c.next_followup_due_at <= now()
     ORDER BY c.next_followup_due_at ASC
     LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.due_followups_r1962() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.due_followups_r1962() TO authenticated;

-- ============================================================================
-- RPC 7: recent_interactions
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_interactions_r1962();
CREATE OR REPLACE FUNCTION public.recent_interactions_r1962()
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  contact_name text,
  interaction_type text,
  taken_at timestamptz,
  by_email text
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
    SELECT l.id, l.contact_id, c.contact_name, l.interaction_type, l.taken_at, l.by_email
      FROM public.founder_networking_interaction_log_r1962 l
      JOIN public.founder_networking_tracker_r1962 c ON c.id = l.contact_id
     ORDER BY l.taken_at DESC
     LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_interactions_r1962() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_interactions_r1962() TO authenticated;

COMMIT;
