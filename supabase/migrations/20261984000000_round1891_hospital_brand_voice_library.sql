BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_brand_voice_r1891 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voice_style text NOT NULL CHECK (voice_style IN ('formal','casual','medical','peer','founder')),
  preferred_topics text[] NOT NULL DEFAULT '{}',
  avoid_topics text[] NOT NULL DEFAULT '{}',
  style_examples_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded')),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hbv_r1891_hospital ON public.hospital_brand_voice_r1891(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hbv_r1891_status ON public.hospital_brand_voice_r1891(status);
CREATE INDEX IF NOT EXISTS idx_hbv_r1891_style ON public.hospital_brand_voice_r1891(voice_style);

CREATE TABLE IF NOT EXISTS public.hospital_voice_evolution_r1891 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_id uuid NOT NULL REFERENCES public.hospital_brand_voice_r1891(id) ON DELETE CASCADE,
  old_style text,
  new_style text,
  change_reason text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hve_r1891_voice ON public.hospital_voice_evolution_r1891(voice_id);
CREATE INDEX IF NOT EXISTS idx_hve_r1891_changed ON public.hospital_voice_evolution_r1891(changed_at DESC);

ALTER TABLE public.hospital_brand_voice_r1891 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_voice_evolution_r1891 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hbv_r1891_founder_all ON public.hospital_brand_voice_r1891;
CREATE POLICY hbv_r1891_founder_all ON public.hospital_brand_voice_r1891
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hve_r1891_founder_all ON public.hospital_voice_evolution_r1891;
CREATE POLICY hve_r1891_founder_all ON public.hospital_voice_evolution_r1891
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_voices_r1891()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  voice_style text,
  preferred_topics text[],
  avoid_topics text[],
  style_examples_md text,
  status text,
  last_updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_user_id, p.email::text AS hospital_email,
         v.voice_style, v.preferred_topics, v.avoid_topics, v.style_examples_md,
         v.status, v.last_updated_at
  FROM public.hospital_brand_voice_r1891 v
  LEFT JOIN public.profiles p ON p.id = v.hospital_user_id
  ORDER BY v.last_updated_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.set_voice_r1891(
  p_hospital_user_id uuid,
  p_voice_style text,
  p_preferred_topics text[],
  p_avoid_topics text[],
  p_style_examples_md text
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
  UPDATE public.hospital_brand_voice_r1891
     SET status = 'superseded', updated_at = now()
   WHERE hospital_user_id = p_hospital_user_id AND status = 'active';

  INSERT INTO public.hospital_brand_voice_r1891(
    hospital_user_id, voice_style, preferred_topics, avoid_topics, style_examples_md, status, last_updated_at
  ) VALUES (
    p_hospital_user_id, p_voice_style,
    COALESCE(p_preferred_topics,'{}'), COALESCE(p_avoid_topics,'{}'),
    p_style_examples_md, 'active', now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_voice_r1891',
          jsonb_build_object('hospital_user_id', p_hospital_user_id, 'voice_style', p_voice_style, 'voice_id', v_id));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_evolution_r1891(p_voice_id uuid)
RETURNS TABLE(
  id uuid,
  voice_id uuid,
  old_style text,
  new_style text,
  change_reason text,
  changed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.voice_id, e.old_style, e.new_style, e.change_reason, e.changed_at
  FROM public.hospital_voice_evolution_r1891 e
  WHERE e.voice_id = p_voice_id
  ORDER BY e.changed_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_evolution_r1891(
  p_voice_id uuid,
  p_old_style text,
  p_new_style text,
  p_change_reason text
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
  INSERT INTO public.hospital_voice_evolution_r1891(voice_id, old_style, new_style, change_reason, changed_at)
  VALUES (p_voice_id, p_old_style, p_new_style, p_change_reason, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_evolution_r1891',
          jsonb_build_object('voice_id', p_voice_id, 'old_style', p_old_style, 'new_style', p_new_style));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.top_styles_r1891()
RETURNS TABLE(voice_style text, hospital_count int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.voice_style, COUNT(*)::int AS hospital_count
  FROM public.hospital_brand_voice_r1891 v
  WHERE v.status = 'active'
  GROUP BY v.voice_style
  ORDER BY hospital_count DESC;
END $$;

CREATE OR REPLACE FUNCTION public.hospitals_needing_update_r1891()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  voice_style text,
  last_updated_at timestamptz,
  days_stale int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_user_id, p.email::text AS hospital_email,
         v.voice_style, v.last_updated_at,
         EXTRACT(DAY FROM (now() - v.last_updated_at))::int AS days_stale
  FROM public.hospital_brand_voice_r1891 v
  LEFT JOIN public.profiles p ON p.id = v.hospital_user_id
  WHERE v.status = 'active' AND v.last_updated_at < now() - interval '90 days'
  ORDER BY v.last_updated_at ASC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_changes_r1891()
RETURNS TABLE(
  id uuid,
  voice_id uuid,
  hospital_email text,
  old_style text,
  new_style text,
  change_reason text,
  changed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.voice_id, p.email::text AS hospital_email,
         e.old_style, e.new_style, e.change_reason, e.changed_at
  FROM public.hospital_voice_evolution_r1891 e
  JOIN public.hospital_brand_voice_r1891 v ON v.id = e.voice_id
  LEFT JOIN public.profiles p ON p.id = v.hospital_user_id
  ORDER BY e.changed_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_voices_r1891() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_voice_r1891(uuid, text, text[], text[], text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_evolution_r1891(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_evolution_r1891(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_styles_r1891() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hospitals_needing_update_r1891() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_changes_r1891() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_voices_r1891() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_voice_r1891(uuid, text, text[], text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_evolution_r1891(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_evolution_r1891(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_styles_r1891() TO authenticated;
GRANT EXECUTE ON FUNCTION public.hospitals_needing_update_r1891() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_changes_r1891() TO authenticated;

COMMIT;