BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_whisperer_notes_r1858 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note_topic text NOT NULL CHECK (note_topic IN ('decision_maker_psych','family_circumstances','risk_signal','upsell_path','champion_moment')),
  note_md text NOT NULL,
  sensitivity text NOT NULL DEFAULT 'founder_only' CHECK (sensitivity IN ('public_ok','founder_only','cofounder_only','founder_locked')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_customer_whisperer_links_r1858 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.founder_customer_whisperer_notes_r1858(id) ON DELETE CASCADE,
  linked_note_id uuid NOT NULL REFERENCES public.founder_customer_whisperer_notes_r1858(id) ON DELETE CASCADE,
  link_type text NOT NULL CHECK (link_type IN ('evolved_from','contradicts','supersedes','related')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_whisperer_notes_r1858 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_whisperer_links_r1858 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_notes_r1858 ON public.founder_customer_whisperer_notes_r1858;
CREATE POLICY founder_all_notes_r1858 ON public.founder_customer_whisperer_notes_r1858
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_links_r1858 ON public.founder_customer_whisperer_links_r1858;
CREATE POLICY founder_all_links_r1858 ON public.founder_customer_whisperer_links_r1858
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_notes
CREATE OR REPLACE FUNCTION public.list_notes_r1858()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  note_topic text,
  note_md text,
  sensitivity text,
  recorded_at timestamptz
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
  SELECT n.id, n.hospital_user_id, p.email, n.note_topic, n.note_md, n.sensitivity, n.recorded_at
  FROM public.founder_customer_whisperer_notes_r1858 n
  LEFT JOIN public.profiles p ON p.id = n.hospital_user_id
  ORDER BY n.recorded_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_note
CREATE OR REPLACE FUNCTION public.log_note_r1858(
  p_hospital_user_id uuid,
  p_note_topic text,
  p_note_md text,
  p_sensitivity text
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
  INSERT INTO public.founder_customer_whisperer_notes_r1858 (hospital_user_id, note_topic, note_md, sensitivity)
  VALUES (p_hospital_user_id, p_note_topic, p_note_md, COALESCE(p_sensitivity, 'founder_only'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_note_r1858',
    jsonb_build_object('note_id', v_id, 'hospital_user_id', p_hospital_user_id, 'note_topic', p_note_topic, 'sensitivity', p_sensitivity));

  RETURN v_id;
END;
$$;

-- RPC 3: list_links
CREATE OR REPLACE FUNCTION public.list_links_r1858()
RETURNS TABLE (
  id uuid,
  note_id uuid,
  linked_note_id uuid,
  link_type text,
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
  SELECT l.id, l.note_id, l.linked_note_id, l.link_type, l.created_at
  FROM public.founder_customer_whisperer_links_r1858 l
  ORDER BY l.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: link_notes
CREATE OR REPLACE FUNCTION public.link_notes_r1858(
  p_note_id uuid,
  p_linked_note_id uuid,
  p_link_type text
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
  INSERT INTO public.founder_customer_whisperer_links_r1858 (note_id, linked_note_id, link_type)
  VALUES (p_note_id, p_linked_note_id, p_link_type)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'link_notes_r1858',
    jsonb_build_object('link_id', v_id, 'note_id', p_note_id, 'linked_note_id', p_linked_note_id, 'link_type', p_link_type));

  RETURN v_id;
END;
$$;

-- RPC 5: latest_per_hospital
CREATE OR REPLACE FUNCTION public.latest_per_hospital_r1858()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  note_count int,
  last_recorded_at timestamptz,
  last_topic text,
  last_sensitivity text
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
  WITH ranked AS (
    SELECT n.*, ROW_NUMBER() OVER (PARTITION BY n.hospital_user_id ORDER BY n.recorded_at DESC) AS rn
    FROM public.founder_customer_whisperer_notes_r1858 n
  ),
  counts AS (
    SELECT hospital_user_id, (COUNT(*))::int AS cnt
    FROM public.founder_customer_whisperer_notes_r1858
    GROUP BY hospital_user_id
  )
  SELECT r.hospital_user_id, p.email, c.cnt, r.recorded_at, r.note_topic, r.sensitivity
  FROM ranked r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN counts c ON c.hospital_user_id = r.hospital_user_id
  WHERE r.rn = 1
  ORDER BY r.recorded_at DESC
  LIMIT 200;
END;
$$;

-- RPC 6: sensitivity_distribution
CREATE OR REPLACE FUNCTION public.sensitivity_distribution_r1858()
RETURNS TABLE (
  sensitivity text,
  note_count int,
  topic_breakdown jsonb
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
  SELECT n.sensitivity,
         (COUNT(*))::int,
         jsonb_object_agg(n.note_topic, n.topic_cnt)
  FROM (
    SELECT sensitivity, note_topic, (COUNT(*))::int AS topic_cnt
    FROM public.founder_customer_whisperer_notes_r1858
    GROUP BY sensitivity, note_topic
  ) n
  GROUP BY n.sensitivity
  ORDER BY (COUNT(*))::int DESC;
END;
$$;

-- RPC 7: recent_notes
CREATE OR REPLACE FUNCTION public.recent_notes_r1858()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  note_topic text,
  note_md text,
  sensitivity text,
  recorded_at timestamptz,
  hours_ago numeric
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
  SELECT n.id, n.hospital_user_id, p.email, n.note_topic, n.note_md, n.sensitivity, n.recorded_at,
         (EXTRACT(EPOCH FROM (now() - n.recorded_at)) / 3600.0)::numeric
  FROM public.founder_customer_whisperer_notes_r1858 n
  LEFT JOIN public.profiles p ON p.id = n.hospital_user_id
  WHERE n.recorded_at > now() - interval '14 days'
  ORDER BY n.recorded_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_notes_r1858() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_note_r1858(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_links_r1858() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.link_notes_r1858(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.latest_per_hospital_r1858() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sensitivity_distribution_r1858() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_notes_r1858() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_notes_r1858() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_note_r1858(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_links_r1858() TO authenticated;
GRANT EXECUTE ON FUNCTION public.link_notes_r1858(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.latest_per_hospital_r1858() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sensitivity_distribution_r1858() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_notes_r1858() TO authenticated;

COMMIT;