BEGIN;

-- Knowledge entries
CREATE TABLE IF NOT EXISTS public.engineer_field_knowledge_r1872 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  knowledge_title text NOT NULL,
  knowledge_category text NOT NULL CHECK (knowledge_category IN ('workaround','calibration_trick','vendor_specific','safety','regulatory')),
  knowledge_md text NOT NULL,
  related_equipment text,
  helpful_score int NOT NULL DEFAULT 5 CHECK (helpful_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','under_review')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efk_r1872_engineer ON public.engineer_field_knowledge_r1872(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efk_r1872_category ON public.engineer_field_knowledge_r1872(knowledge_category);
CREATE INDEX IF NOT EXISTS idx_efk_r1872_status ON public.engineer_field_knowledge_r1872(status);

ALTER TABLE public.engineer_field_knowledge_r1872 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efk_r1872_founder_all ON public.engineer_field_knowledge_r1872;
CREATE POLICY efk_r1872_founder_all ON public.engineer_field_knowledge_r1872
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Endorsements
CREATE TABLE IF NOT EXISTS public.engineer_field_knowledge_endorsements_r1872 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  knowledge_id uuid NOT NULL REFERENCES public.engineer_field_knowledge_r1872(id) ON DELETE CASCADE,
  endorser_email text NOT NULL,
  endorser_role text NOT NULL CHECK (endorser_role IN ('engineer_peer','hospital','founder')),
  endorsement_text text,
  endorsed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efk_end_r1872_knowledge ON public.engineer_field_knowledge_endorsements_r1872(knowledge_id);
CREATE INDEX IF NOT EXISTS idx_efk_end_r1872_role ON public.engineer_field_knowledge_endorsements_r1872(endorser_role);

ALTER TABLE public.engineer_field_knowledge_endorsements_r1872 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efk_end_r1872_founder_all ON public.engineer_field_knowledge_endorsements_r1872;
CREATE POLICY efk_end_r1872_founder_all ON public.engineer_field_knowledge_endorsements_r1872
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_knowledge
DROP FUNCTION IF EXISTS public.list_knowledge_r1872();
CREATE OR REPLACE FUNCTION public.list_knowledge_r1872()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  knowledge_title text,
  knowledge_category text,
  related_equipment text,
  helpful_score int,
  status text,
  endorsement_count int,
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
  SELECT k.id,
         k.engineer_user_id,
         p.email::text,
         k.knowledge_title,
         k.knowledge_category,
         k.related_equipment,
         k.helpful_score,
         k.status,
         (SELECT COUNT(*) FROM public.engineer_field_knowledge_endorsements_r1872 e WHERE e.knowledge_id = k.id)::int,
         k.created_at
  FROM public.engineer_field_knowledge_r1872 k
  LEFT JOIN public.profiles p ON p.id = k.engineer_user_id
  ORDER BY k.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_knowledge_r1872() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_knowledge_r1872() TO authenticated;

-- RPC 2: log_knowledge
DROP FUNCTION IF EXISTS public.log_knowledge_r1872(uuid, text, text, text, text, int);
CREATE OR REPLACE FUNCTION public.log_knowledge_r1872(
  p_engineer_user_id uuid,
  p_title text,
  p_category text,
  p_md text,
  p_related_equipment text,
  p_helpful_score int
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
  INSERT INTO public.engineer_field_knowledge_r1872(
    engineer_user_id, knowledge_title, knowledge_category, knowledge_md, related_equipment, helpful_score
  ) VALUES (
    p_engineer_user_id, p_title, p_category, p_md, p_related_equipment, COALESCE(p_helpful_score, 5)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_knowledge_r1872',
          jsonb_build_object('knowledge_id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_category));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_knowledge_r1872(uuid, text, text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_knowledge_r1872(uuid, text, text, text, text, int) TO authenticated;

-- RPC 3: list_endorsements
DROP FUNCTION IF EXISTS public.list_endorsements_r1872(uuid);
CREATE OR REPLACE FUNCTION public.list_endorsements_r1872(p_knowledge_id uuid)
RETURNS TABLE (
  id uuid,
  knowledge_id uuid,
  endorser_email text,
  endorser_role text,
  endorsement_text text,
  endorsed_at timestamptz
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
  SELECT e.id, e.knowledge_id, e.endorser_email, e.endorser_role, e.endorsement_text, e.endorsed_at
  FROM public.engineer_field_knowledge_endorsements_r1872 e
  WHERE e.knowledge_id = p_knowledge_id
  ORDER BY e.endorsed_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_endorsements_r1872(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_endorsements_r1872(uuid) TO authenticated;

-- RPC 4: add_endorsement
DROP FUNCTION IF EXISTS public.add_endorsement_r1872(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_endorsement_r1872(
  p_knowledge_id uuid,
  p_endorser_email text,
  p_endorser_role text,
  p_endorsement_text text
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
  INSERT INTO public.engineer_field_knowledge_endorsements_r1872(
    knowledge_id, endorser_email, endorser_role, endorsement_text
  ) VALUES (
    p_knowledge_id, p_endorser_email, p_endorser_role, p_endorsement_text
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_endorsement_r1872',
          jsonb_build_object('endorsement_id', v_id, 'knowledge_id', p_knowledge_id, 'role', p_endorser_role));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_endorsement_r1872(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_endorsement_r1872(uuid, text, text, text) TO authenticated;

-- RPC 5: supersede
DROP FUNCTION IF EXISTS public.supersede_r1872(uuid);
CREATE OR REPLACE FUNCTION public.supersede_r1872(p_knowledge_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_field_knowledge_r1872
  SET status = 'superseded', updated_at = now()
  WHERE id = p_knowledge_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'supersede_r1872',
          jsonb_build_object('knowledge_id', p_knowledge_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.supersede_r1872(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supersede_r1872(uuid) TO authenticated;

-- RPC 6: top_helpful
DROP FUNCTION IF EXISTS public.top_helpful_r1872();
CREATE OR REPLACE FUNCTION public.top_helpful_r1872()
RETURNS TABLE (
  id uuid,
  knowledge_title text,
  knowledge_category text,
  helpful_score int,
  endorsement_count int,
  status text
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
  SELECT k.id,
         k.knowledge_title,
         k.knowledge_category,
         k.helpful_score,
         (SELECT COUNT(*) FROM public.engineer_field_knowledge_endorsements_r1872 e WHERE e.knowledge_id = k.id)::int,
         k.status
  FROM public.engineer_field_knowledge_r1872 k
  WHERE k.status = 'active'
  ORDER BY k.helpful_score DESC, k.created_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_helpful_r1872() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_helpful_r1872() TO authenticated;

-- RPC 7: recent_endorsements
DROP FUNCTION IF EXISTS public.recent_endorsements_r1872();
CREATE OR REPLACE FUNCTION public.recent_endorsements_r1872()
RETURNS TABLE (
  id uuid,
  knowledge_id uuid,
  knowledge_title text,
  endorser_email text,
  endorser_role text,
  endorsement_text text,
  endorsed_at timestamptz
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
  SELECT e.id,
         e.knowledge_id,
         k.knowledge_title,
         e.endorser_email,
         e.endorser_role,
         e.endorsement_text,
         e.endorsed_at
  FROM public.engineer_field_knowledge_endorsements_r1872 e
  JOIN public.engineer_field_knowledge_r1872 k ON k.id = e.knowledge_id
  ORDER BY e.endorsed_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_endorsements_r1872() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_endorsements_r1872() TO authenticated;

COMMIT;