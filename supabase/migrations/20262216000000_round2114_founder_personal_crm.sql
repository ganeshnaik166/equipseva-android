BEGIN;

-- ============================================================================
-- Round 2114 — Founder Personal CRM
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_personal_crm_r2114 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_name text NOT NULL,
  relationship_type text NOT NULL CHECK (relationship_type IN ('mentor','peer_founder','investor','customer_champion','competitor_friend','journalist','family')),
  last_touch_at timestamptz,
  next_touch_due_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','inactive','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_crm_touch_log_r2114 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.founder_personal_crm_r2114(id) ON DELETE CASCADE,
  touch_type text NOT NULL CHECK (touch_type IN ('call','text','email','coffee','dinner','event','gift')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpc_r2114_status ON public.founder_personal_crm_r2114(status);
CREATE INDEX IF NOT EXISTS idx_fpc_r2114_next_due ON public.founder_personal_crm_r2114(next_touch_due_at);
CREATE INDEX IF NOT EXISTS idx_fct_r2114_contact ON public.founder_crm_touch_log_r2114(contact_id);
CREATE INDEX IF NOT EXISTS idx_fct_r2114_taken ON public.founder_crm_touch_log_r2114(taken_at DESC);

ALTER TABLE public.founder_personal_crm_r2114 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_crm_touch_log_r2114 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_fpc_r2114 ON public.founder_personal_crm_r2114;
CREATE POLICY founder_only_fpc_r2114 ON public.founder_personal_crm_r2114
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_fct_r2114 ON public.founder_crm_touch_log_r2114;
CREATE POLICY founder_only_fct_r2114 ON public.founder_crm_touch_log_r2114
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_contacts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_contacts_r2114()
RETURNS TABLE (
  id uuid,
  contact_name text,
  relationship_type text,
  last_touch_at timestamptz,
  next_touch_due_at timestamptz,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.contact_name, c.relationship_type, c.last_touch_at, c.next_touch_due_at, c.status, c.captured_at
  FROM public.founder_personal_crm_r2114 c
  ORDER BY c.next_touch_due_at NULLS LAST, c.captured_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 2: log_contact
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_contact_r2114(
  p_contact_name text,
  p_relationship_type text,
  p_next_touch_due_at timestamptz DEFAULT NULL
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
  INSERT INTO public.founder_personal_crm_r2114(contact_name, relationship_type, next_touch_due_at)
  VALUES (p_contact_name, p_relationship_type, p_next_touch_due_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_contact_r2114',
          jsonb_build_object('id', v_id, 'contact_name', p_contact_name, 'relationship_type', p_relationship_type));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_touches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_touches_r2114(p_contact_id uuid)
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  touch_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.contact_id, t.touch_type, t.taken_at, t.by_email, t.notes_md
  FROM public.founder_crm_touch_log_r2114 t
  WHERE t.contact_id = p_contact_id
  ORDER BY t.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_touch
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_touch_r2114(
  p_contact_id uuid,
  p_touch_type text,
  p_notes_md text DEFAULT NULL
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
  INSERT INTO public.founder_crm_touch_log_r2114(contact_id, touch_type, by_email, notes_md)
  VALUES (p_contact_id, p_touch_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  UPDATE public.founder_personal_crm_r2114
  SET last_touch_at = now(), updated_at = now()
  WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_touch_r2114',
          jsonb_build_object('id', v_id, 'contact_id', p_contact_id, 'touch_type', p_touch_type));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2114(
  p_contact_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_personal_crm_r2114
  SET status = p_status, updated_at = now()
  WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2114',
          jsonb_build_object('contact_id', p_contact_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: due_touches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.due_touches_r2114()
RETURNS TABLE (
  id uuid,
  contact_name text,
  relationship_type text,
  next_touch_due_at timestamptz,
  days_overdue integer,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.contact_name, c.relationship_type, c.next_touch_due_at,
         GREATEST(0, EXTRACT(DAY FROM (now() - c.next_touch_due_at))::integer) AS days_overdue,
         c.status
  FROM public.founder_personal_crm_r2114 c
  WHERE c.next_touch_due_at IS NOT NULL
    AND c.next_touch_due_at <= now()
    AND c.status = 'active'
  ORDER BY c.next_touch_due_at ASC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 7: recent_touches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_touches_r2114()
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  contact_name text,
  touch_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.contact_id, c.contact_name, t.touch_type, t.taken_at, t.by_email
  FROM public.founder_crm_touch_log_r2114 t
  JOIN public.founder_personal_crm_r2114 c ON c.id = t.contact_id
  ORDER BY t.taken_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_contacts_r2114() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_contact_r2114(text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_touches_r2114(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_touch_r2114(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2114(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.due_touches_r2114() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_touches_r2114() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_contacts_r2114() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_contact_r2114(text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_touches_r2114(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_touch_r2114(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2114(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.due_touches_r2114() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_touches_r2114() TO authenticated;

COMMIT;
