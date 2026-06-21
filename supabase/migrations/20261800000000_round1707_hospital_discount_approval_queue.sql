BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_discount_requests_r1707 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id),
  request_type text NOT NULL CHECK (request_type IN ('amc_renewal','repair_quote','spare_part','multi_year')),
  list_price_rupees bigint NOT NULL CHECK (list_price_rupees >= 0),
  discount_pct numeric(5,2) NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100),
  requested_by_email text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  justification text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','expired')),
  decided_at timestamptz,
  decided_by_email text,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_discount_review_notes_r1707 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.hospital_discount_requests_r1707(id) ON DELETE CASCADE,
  note text NOT NULL,
  by_email text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_discount_requests_r1707 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_discount_review_notes_r1707 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1707_req ON public.hospital_discount_requests_r1707;
CREATE POLICY founder_all_r1707_req ON public.hospital_discount_requests_r1707
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1707_notes ON public.hospital_discount_review_notes_r1707;
CREATE POLICY founder_all_r1707_notes ON public.hospital_discount_review_notes_r1707
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_requests
CREATE OR REPLACE FUNCTION public.list_discount_requests_r1707()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  request_type text,
  list_price_rupees bigint,
  discount_pct numeric,
  discount_value_rupees bigint,
  requested_by_email text,
  requested_at timestamptz,
  justification text,
  status text,
  decided_at timestamptz,
  decided_by_email text,
  expires_at timestamptz,
  note_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.hospital_user_id,
    p.email,
    r.request_type,
    r.list_price_rupees,
    r.discount_pct,
    (r.list_price_rupees * r.discount_pct / 100)::bigint AS discount_value_rupees,
    r.requested_by_email,
    r.requested_at,
    r.justification,
    r.status,
    r.decided_at,
    r.decided_by_email,
    r.expires_at,
    (SELECT (COUNT(*))::int FROM public.hospital_discount_review_notes_r1707 n WHERE n.request_id = r.id)
  FROM public.hospital_discount_requests_r1707 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  ORDER BY
    CASE r.status WHEN 'pending' THEN 0 WHEN 'approved' THEN 1 WHEN 'rejected' THEN 2 ELSE 3 END,
    r.requested_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: submit_request
CREATE OR REPLACE FUNCTION public.submit_discount_request_r1707(
  p_hospital_user_id uuid,
  p_request_type text,
  p_list_price_rupees bigint,
  p_discount_pct numeric,
  p_requested_by_email text,
  p_justification text,
  p_expires_at timestamptz
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
  INSERT INTO public.hospital_discount_requests_r1707(
    hospital_user_id, request_type, list_price_rupees, discount_pct,
    requested_by_email, justification, expires_at
  ) VALUES (
    p_hospital_user_id, p_request_type, p_list_price_rupees, p_discount_pct,
    p_requested_by_email, p_justification, p_expires_at
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1707_submit_discount_request',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'discount_pct', p_discount_pct));
  RETURN v_id;
END;
$$;

-- RPC 3: list_notes
CREATE OR REPLACE FUNCTION public.list_discount_request_notes_r1707(p_request_id uuid)
RETURNS TABLE (
  id uuid,
  request_id uuid,
  note text,
  by_email text,
  at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.request_id, n.note, n.by_email, n.at
  FROM public.hospital_discount_review_notes_r1707 n
  WHERE n.request_id = p_request_id
  ORDER BY n.at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: add_note
CREATE OR REPLACE FUNCTION public.add_discount_request_note_r1707(
  p_request_id uuid,
  p_note text,
  p_by_email text
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
  INSERT INTO public.hospital_discount_review_notes_r1707(request_id, note, by_email)
  VALUES (p_request_id, p_note, p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1707_add_discount_note',
    jsonb_build_object('id', v_id, 'request_id', p_request_id));
  RETURN v_id;
END;
$$;

-- RPC 5: decide_request
CREATE OR REPLACE FUNCTION public.decide_discount_request_r1707(
  p_request_id uuid,
  p_decision text,
  p_decided_by_email text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;
  UPDATE public.hospital_discount_requests_r1707
    SET status = p_decision,
        decided_at = now(),
        decided_by_email = p_decided_by_email,
        updated_at = now()
    WHERE id = p_request_id
      AND status = 'pending';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1707_decide_discount_request',
    jsonb_build_object('request_id', p_request_id, 'decision', p_decision));
END;
$$;

-- RPC 6: top_pending_value
CREATE OR REPLACE FUNCTION public.top_pending_discount_value_r1707()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  request_type text,
  list_price_rupees bigint,
  discount_pct numeric,
  discount_value_rupees bigint,
  requested_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.hospital_user_id,
    p.email,
    r.request_type,
    r.list_price_rupees,
    r.discount_pct,
    (r.list_price_rupees * r.discount_pct / 100)::bigint AS discount_value_rupees,
    r.requested_at
  FROM public.hospital_discount_requests_r1707 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE r.status = 'pending'
  ORDER BY (r.list_price_rupees * r.discount_pct / 100) DESC
  LIMIT 20;
END;
$$;

-- RPC 7: expired_requests
CREATE OR REPLACE FUNCTION public.expired_discount_requests_r1707()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  request_type text,
  list_price_rupees bigint,
  discount_pct numeric,
  requested_at timestamptz,
  expires_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.hospital_user_id,
    p.email,
    r.request_type,
    r.list_price_rupees,
    r.discount_pct,
    r.requested_at,
    r.expires_at,
    r.status
  FROM public.hospital_discount_requests_r1707 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE r.expires_at IS NOT NULL
    AND r.expires_at < now()
    AND r.status IN ('pending','expired')
  ORDER BY r.expires_at ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_discount_requests_r1707() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_discount_request_r1707(uuid, text, bigint, numeric, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_discount_request_notes_r1707(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_discount_request_note_r1707(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_discount_request_r1707(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_pending_discount_value_r1707() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expired_discount_requests_r1707() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_discount_requests_r1707() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_discount_request_r1707(uuid, text, bigint, numeric, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_discount_request_notes_r1707(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_discount_request_note_r1707(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_discount_request_r1707(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_pending_discount_value_r1707() TO authenticated;
GRANT EXECUTE ON FUNCTION public.expired_discount_requests_r1707() TO authenticated;

COMMIT;