BEGIN;

-- ============================================================
-- Round 2014: Founder Strategy Map Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_strategy_map_r2014 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  map_label text NOT NULL,
  map_md text NOT NULL DEFAULT '',
  map_type text NOT NULL CHECK (map_type IN ('pestel','swot','porter_5','blue_ocean','ansoff')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','superseded','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_strategy_map_revision_log_r2014 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  map_id uuid NOT NULL REFERENCES public.founder_strategy_map_r2014(id) ON DELETE CASCADE,
  revision_md text NOT NULL DEFAULT '',
  reason text NOT NULL CHECK (reason IN ('market_shift','competitive_change','founder_pivot','quarterly_review','external_input')),
  revised_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsm_r2014_type_status ON public.founder_strategy_map_r2014(map_type, status);
CREATE INDEX IF NOT EXISTS idx_fsm_r2014_captured ON public.founder_strategy_map_r2014(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsmrl_r2014_map ON public.founder_strategy_map_revision_log_r2014(map_id, revised_at DESC);

ALTER TABLE public.founder_strategy_map_r2014 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_strategy_map_revision_log_r2014 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fsm_r2014_founder_all ON public.founder_strategy_map_r2014;
CREATE POLICY fsm_r2014_founder_all ON public.founder_strategy_map_r2014
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fsmrl_r2014_founder_all ON public.founder_strategy_map_revision_log_r2014;
CREATE POLICY fsmrl_r2014_founder_all ON public.founder_strategy_map_revision_log_r2014
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.list_strategy_maps_r2014();
CREATE OR REPLACE FUNCTION public.list_strategy_maps_r2014()
RETURNS TABLE (
  id uuid,
  map_label text,
  map_type text,
  status text,
  captured_at timestamptz,
  last_reviewed_at timestamptz
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
  SELECT m.id, m.map_label, m.map_type, m.status, m.captured_at, m.last_reviewed_at
  FROM public.founder_strategy_map_r2014 m
  ORDER BY m.captured_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_strategy_map_r2014(text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_strategy_map_r2014(
  p_label text,
  p_md text,
  p_type text,
  p_status text DEFAULT 'draft'
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
  INSERT INTO public.founder_strategy_map_r2014(map_label, map_md, map_type, status)
  VALUES (p_label, COALESCE(p_md,''), p_type, COALESCE(p_status,'draft'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_strategy_map_r2014',
    jsonb_build_object('id', v_id, 'label', p_label, 'type', p_type, 'status', p_status));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_strategy_map_revisions_r2014(uuid);
CREATE OR REPLACE FUNCTION public.list_strategy_map_revisions_r2014(p_map_id uuid)
RETURNS TABLE (
  id uuid,
  map_id uuid,
  reason text,
  revised_at timestamptz,
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
  SELECT r.id, r.map_id, r.reason, r.revised_at, r.by_email
  FROM public.founder_strategy_map_revision_log_r2014 r
  WHERE r.map_id = p_map_id
  ORDER BY r.revised_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_strategy_map_revision_r2014(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_strategy_map_revision_r2014(
  p_map_id uuid,
  p_revision_md text,
  p_reason text
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
  INSERT INTO public.founder_strategy_map_revision_log_r2014(map_id, revision_md, reason, by_email)
  VALUES (p_map_id, COALESCE(p_revision_md,''), p_reason, v_email)
  RETURNING id INTO v_id;

  UPDATE public.founder_strategy_map_r2014
  SET last_reviewed_at = now(), updated_at = now()
  WHERE id = p_map_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_strategy_map_revision_r2014',
    jsonb_build_object('id', v_id, 'map_id', p_map_id, 'reason', p_reason));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_strategy_map_status_r2014(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_strategy_map_status_r2014(
  p_map_id uuid,
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
  UPDATE public.founder_strategy_map_r2014
  SET status = p_status, updated_at = now()
  WHERE id = p_map_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_strategy_map_status_r2014',
    jsonb_build_object('map_id', p_map_id, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.current_strategy_map_r2014(text);
CREATE OR REPLACE FUNCTION public.current_strategy_map_r2014(p_type text)
RETURNS TABLE (
  id uuid,
  map_label text,
  map_type text,
  status text,
  captured_at timestamptz,
  last_reviewed_at timestamptz
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
  SELECT m.id, m.map_label, m.map_type, m.status, m.captured_at, m.last_reviewed_at
  FROM public.founder_strategy_map_r2014 m
  WHERE m.map_type = p_type AND m.status = 'active'
  ORDER BY m.captured_at DESC
  LIMIT 5;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_strategy_map_revisions_r2014(integer);
CREATE OR REPLACE FUNCTION public.recent_strategy_map_revisions_r2014(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  map_id uuid,
  map_label text,
  map_type text,
  reason text,
  revised_at timestamptz,
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
  SELECT r.id, r.map_id, m.map_label, m.map_type, r.reason, r.revised_at, r.by_email
  FROM public.founder_strategy_map_revision_log_r2014 r
  JOIN public.founder_strategy_map_r2014 m ON m.id = r.map_id
  ORDER BY r.revised_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_strategy_maps_r2014() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_strategy_maps_r2014() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_strategy_map_r2014(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_strategy_map_r2014(text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_strategy_map_revisions_r2014(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_strategy_map_revisions_r2014(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_strategy_map_revision_r2014(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_strategy_map_revision_r2014(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_strategy_map_status_r2014(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_strategy_map_status_r2014(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.current_strategy_map_r2014(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_strategy_map_r2014(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_strategy_map_revisions_r2014(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_strategy_map_revisions_r2014(integer) TO authenticated;

COMMIT;
