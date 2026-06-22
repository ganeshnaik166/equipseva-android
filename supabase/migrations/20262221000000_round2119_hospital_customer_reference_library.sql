BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_customer_reference_library_r2119 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reference_quote_md text NOT NULL,
  quote_source text NOT NULL CHECK (quote_source IN ('engineer','customer','case_study','testimonial','award_nomination')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','featured','marketing_used','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_reference_use_log_r2119 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_id uuid NOT NULL REFERENCES public.hospital_customer_reference_library_r2119(id) ON DELETE CASCADE,
  use_type text NOT NULL CHECK (use_type IN ('website','pitch_deck','marketing_email','awards','sales_call','social_media')),
  used_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_reference_library_r2119 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_reference_use_log_r2119 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_refs_r2119 ON public.hospital_customer_reference_library_r2119;
CREATE POLICY founder_all_refs_r2119 ON public.hospital_customer_reference_library_r2119
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_uses_r2119 ON public.hospital_reference_use_log_r2119;
CREATE POLICY founder_all_uses_r2119 ON public.hospital_reference_use_log_r2119
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list references
CREATE OR REPLACE FUNCTION public.list_references_r2119()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  reference_quote_md text,
  quote_source text,
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
    SELECT r.id, r.hospital_id, p.email, r.reference_quote_md, r.quote_source, r.status, r.captured_at
    FROM public.hospital_customer_reference_library_r2119 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    ORDER BY r.captured_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log new reference
CREATE OR REPLACE FUNCTION public.log_reference_r2119(
  p_hospital_id uuid,
  p_reference_quote_md text,
  p_quote_source text,
  p_status text DEFAULT 'active'
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
  INSERT INTO public.hospital_customer_reference_library_r2119(hospital_id, reference_quote_md, quote_source, status)
  VALUES (p_hospital_id, p_reference_quote_md, p_quote_source, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reference_r2119',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'quote_source', p_quote_source));
  RETURN v_id;
END;
$$;

-- RPC 3: list uses
CREATE OR REPLACE FUNCTION public.list_uses_r2119(p_reference_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  reference_id uuid,
  use_type text,
  used_at timestamptz,
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
    SELECT u.id, u.reference_id, u.use_type, u.used_at, u.by_email, u.notes_md
    FROM public.hospital_reference_use_log_r2119 u
    WHERE p_reference_id IS NULL OR u.reference_id = p_reference_id
    ORDER BY u.used_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log use
CREATE OR REPLACE FUNCTION public.log_use_r2119(
  p_reference_id uuid,
  p_use_type text,
  p_by_email text DEFAULT NULL,
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
  INSERT INTO public.hospital_reference_use_log_r2119(reference_id, use_type, by_email, notes_md)
  VALUES (p_reference_id, p_use_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_use_r2119',
    jsonb_build_object('id', v_id, 'reference_id', p_reference_id, 'use_type', p_use_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark status
CREATE OR REPLACE FUNCTION public.mark_status_r2119(
  p_reference_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_reference_library_r2119
  SET status = p_status, updated_at = now()
  WHERE id = p_reference_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2119',
    jsonb_build_object('reference_id', p_reference_id, 'status', p_status));
END;
$$;

-- RPC 6: featured refs
CREATE OR REPLACE FUNCTION public.featured_r2119()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  reference_quote_md text,
  quote_source text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_id, r.reference_quote_md, r.quote_source, r.captured_at
    FROM public.hospital_customer_reference_library_r2119 r
    WHERE r.status = 'featured'
    ORDER BY r.captured_at DESC
    LIMIT 50;
END;
$$;

-- RPC 7: recent uses
CREATE OR REPLACE FUNCTION public.recent_uses_r2119(p_days int DEFAULT 30)
RETURNS TABLE (
  use_type text,
  use_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT u.use_type, count(*)::bigint AS use_count
    FROM public.hospital_reference_use_log_r2119 u
    WHERE u.used_at >= now() - make_interval(days => p_days)
    GROUP BY u.use_type
    ORDER BY use_count DESC;
END;
$$;

-- Lock down grants
REVOKE EXECUTE ON FUNCTION public.list_references_r2119() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reference_r2119(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_uses_r2119(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_use_r2119(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2119(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.featured_r2119() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_uses_r2119(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_references_r2119() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reference_r2119(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_uses_r2119(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_use_r2119(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2119(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.featured_r2119() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_uses_r2119(int) TO authenticated;

COMMIT;
