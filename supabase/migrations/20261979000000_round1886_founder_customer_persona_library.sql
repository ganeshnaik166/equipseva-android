BEGIN;

-- =====================================================================
-- Round 1886: Founder Customer Persona Library
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_customer_personas_r1886 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  persona_name text NOT NULL,
  persona_role text NOT NULL CHECK (persona_role IN ('ceo','cmo','coo','biomed','procurement','board','owner')),
  pain_points_md text,
  motivators_md text,
  common_objections_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_persona_evolution_log_r1886 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  persona_id uuid NOT NULL REFERENCES public.founder_customer_personas_r1886(id) ON DELETE CASCADE,
  change_at timestamptz NOT NULL DEFAULT now(),
  change_type text NOT NULL CHECK (change_type IN ('pain_point','motivator','objection','role')),
  change_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personas_r1886_status ON public.founder_customer_personas_r1886(status);
CREATE INDEX IF NOT EXISTS idx_personas_r1886_role ON public.founder_customer_personas_r1886(persona_role);
CREATE INDEX IF NOT EXISTS idx_evolution_r1886_persona ON public.founder_persona_evolution_log_r1886(persona_id, change_at DESC);

ALTER TABLE public.founder_customer_personas_r1886 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_persona_evolution_log_r1886 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS personas_r1886_founder_all ON public.founder_customer_personas_r1886;
CREATE POLICY personas_r1886_founder_all ON public.founder_customer_personas_r1886
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS evolution_r1886_founder_all ON public.founder_persona_evolution_log_r1886;
CREATE POLICY evolution_r1886_founder_all ON public.founder_persona_evolution_log_r1886
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPCs
-- =====================================================================

CREATE OR REPLACE FUNCTION public.list_personas_r1886()
RETURNS TABLE (
  id uuid,
  persona_name text,
  persona_role text,
  pain_points_md text,
  motivators_md text,
  common_objections_md text,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.persona_name, p.persona_role, p.pain_points_md, p.motivators_md,
         p.common_objections_md, p.status, p.created_at, p.updated_at
  FROM public.founder_customer_personas_r1886 p
  ORDER BY p.updated_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_persona_r1886(
  p_id uuid,
  p_name text,
  p_role text,
  p_pain text,
  p_motiv text,
  p_obj text,
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

  IF p_id IS NULL THEN
    INSERT INTO public.founder_customer_personas_r1886(
      persona_name, persona_role, pain_points_md, motivators_md, common_objections_md, status
    ) VALUES (p_name, p_role, p_pain, p_motiv, p_obj, COALESCE(p_status, 'active'))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.founder_customer_personas_r1886
       SET persona_name = p_name,
           persona_role = p_role,
           pain_points_md = p_pain,
           motivators_md = p_motiv,
           common_objections_md = p_obj,
           status = COALESCE(p_status, status),
           updated_at = now()
     WHERE id = p_id
     RETURNING id INTO v_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'save_persona_r1886',
    jsonb_build_object('id', v_id, 'name', p_name, 'role', p_role, 'status', p_status)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_evolution_r1886(p_persona_id uuid)
RETURNS TABLE (
  id uuid,
  persona_id uuid,
  change_at timestamptz,
  change_type text,
  change_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.persona_id, e.change_at, e.change_type, e.change_text
  FROM public.founder_persona_evolution_log_r1886 e
  WHERE e.persona_id = p_persona_id
  ORDER BY e.change_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_evolution_r1886(
  p_persona_id uuid,
  p_change_type text,
  p_change_text text
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

  INSERT INTO public.founder_persona_evolution_log_r1886(persona_id, change_type, change_text)
  VALUES (p_persona_id, p_change_type, p_change_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_evolution_r1886',
    jsonb_build_object('id', v_id, 'persona_id', p_persona_id, 'type', p_change_type)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_persona_r1886(p_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_customer_personas_r1886
     SET status = 'archived', updated_at = now()
   WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'archive_persona_r1886',
    jsonb_build_object('id', p_id)
  );

  RETURN p_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_role_distribution_r1886()
RETURNS TABLE (
  persona_role text,
  total_count int,
  active_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.persona_role,
         (COUNT(*))::int AS total_count,
         (COUNT(*) FILTER (WHERE p.status = 'active'))::int AS active_count
  FROM public.founder_customer_personas_r1886 p
  GROUP BY p.persona_role
  ORDER BY total_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_changes_r1886()
RETURNS TABLE (
  id uuid,
  persona_id uuid,
  persona_name text,
  persona_role text,
  change_at timestamptz,
  change_type text,
  change_text text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.persona_id, p.persona_name, p.persona_role,
         e.change_at, e.change_type, e.change_text
  FROM public.founder_persona_evolution_log_r1886 e
  JOIN public.founder_customer_personas_r1886 p ON p.id = e.persona_id
  ORDER BY e.change_at DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- Permissions
-- =====================================================================

REVOKE EXECUTE ON FUNCTION public.list_personas_r1886() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_persona_r1886(uuid, text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_evolution_r1886(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_evolution_r1886(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.archive_persona_r1886(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_role_distribution_r1886() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_changes_r1886() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_personas_r1886() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_persona_r1886(uuid, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_evolution_r1886(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_evolution_r1886(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_persona_r1886(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_role_distribution_r1886() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_changes_r1886() TO authenticated;

COMMIT;