BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_co_investor_network_r2033 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  co_investor_id_referenced uuid NOT NULL,
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('strong','medium','weak','conflictive')),
  shared_deals_count int NOT NULL DEFAULT 0 CHECK (shared_deals_count >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','declined')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_co_inv_net_r2033_investor ON public.investor_co_investor_network_r2033(investor_id);
CREATE INDEX IF NOT EXISTS idx_co_inv_net_r2033_status ON public.investor_co_investor_network_r2033(status);
CREATE INDEX IF NOT EXISTS idx_co_inv_net_r2033_strength ON public.investor_co_investor_network_r2033(relationship_strength);

CREATE TABLE IF NOT EXISTS public.investor_co_investor_action_log_r2033 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES public.investor_co_investor_network_r2033(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('intro_received','intro_made','deal_invited','passed','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_co_inv_log_r2033_rel ON public.investor_co_investor_action_log_r2033(relationship_id);
CREATE INDEX IF NOT EXISTS idx_co_inv_log_r2033_taken ON public.investor_co_investor_action_log_r2033(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_co_inv_log_r2033_action ON public.investor_co_investor_action_log_r2033(action_type);

ALTER TABLE public.investor_co_investor_network_r2033 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_co_investor_action_log_r2033 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS co_inv_net_r2033_founder_all ON public.investor_co_investor_network_r2033;
CREATE POLICY co_inv_net_r2033_founder_all ON public.investor_co_investor_network_r2033
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS co_inv_log_r2033_founder_all ON public.investor_co_investor_action_log_r2033;
CREATE POLICY co_inv_log_r2033_founder_all ON public.investor_co_investor_action_log_r2033
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_relationships
CREATE OR REPLACE FUNCTION public.list_co_investor_relationships_r2033()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  co_investor_id_referenced uuid,
  relationship_strength text,
  shared_deals_count int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.investor_id, r.co_investor_id_referenced, r.relationship_strength,
           r.shared_deals_count, r.status, r.captured_at
    FROM public.investor_co_investor_network_r2033 r
    ORDER BY r.captured_at DESC
    LIMIT 500;
END;
$$;

-- 2. log_relationship
CREATE OR REPLACE FUNCTION public.log_co_investor_relationship_r2033(
  p_investor_id uuid,
  p_co_investor_id uuid,
  p_strength text,
  p_shared_deals int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_co_investor_network_r2033(
    investor_id, co_investor_id_referenced, relationship_strength, shared_deals_count, status
  ) VALUES (
    p_investor_id, p_co_investor_id, p_strength, COALESCE(p_shared_deals,0), COALESCE(p_status,'active')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_co_investor_relationship_r2033',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'co_investor_id', p_co_investor_id,
                       'strength', p_strength, 'status', p_status));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_co_investor_actions_r2033(p_relationship_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  relationship_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.relationship_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_co_investor_action_log_r2033 a
    WHERE p_relationship_id IS NULL OR a.relationship_id = p_relationship_id
    ORDER BY a.taken_at DESC
    LIMIT 500;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_co_investor_action_r2033(
  p_relationship_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_co_investor_action_log_r2033(
    relationship_id, action_type, by_email, notes_md
  ) VALUES (
    p_relationship_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_co_investor_action_r2033',
    jsonb_build_object('id', v_id, 'relationship_id', p_relationship_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_co_investor_relationship_status_r2033(
  p_relationship_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_co_investor_network_r2033
     SET status = p_new_status, updated_at = now()
   WHERE id = p_relationship_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_co_investor_relationship_status_r2033',
    jsonb_build_object('id', p_relationship_id, 'status', p_new_status));
END;
$$;

-- 6. strong_relationships
CREATE OR REPLACE FUNCTION public.strong_co_investor_relationships_r2033()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  co_investor_id_referenced uuid,
  shared_deals_count int,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.investor_id, r.co_investor_id_referenced, r.shared_deals_count, r.captured_at
    FROM public.investor_co_investor_network_r2033 r
    WHERE r.relationship_strength = 'strong' AND r.status = 'active'
    ORDER BY r.shared_deals_count DESC, r.captured_at DESC
    LIMIT 200;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_co_investor_actions_r2033(p_days int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  relationship_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.relationship_id, a.action_type, a.taken_at, a.by_email
    FROM public.investor_co_investor_action_log_r2033 a
    WHERE a.taken_at >= now() - make_interval(days => COALESCE(p_days, 30))
    ORDER BY a.taken_at DESC
    LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_co_investor_relationships_r2033() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_co_investor_relationship_r2033(uuid, uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_co_investor_actions_r2033(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_co_investor_action_r2033(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_co_investor_relationship_status_r2033(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.strong_co_investor_relationships_r2033() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_co_investor_actions_r2033(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_co_investor_relationships_r2033() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_co_investor_relationship_r2033(uuid, uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_co_investor_actions_r2033(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_co_investor_action_r2033(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_co_investor_relationship_status_r2033(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.strong_co_investor_relationships_r2033() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_co_investor_actions_r2033(int) TO authenticated;

COMMIT;
