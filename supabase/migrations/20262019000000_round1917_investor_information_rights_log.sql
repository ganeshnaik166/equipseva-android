BEGIN;

-- =====================================================================
-- Round 1917: Investor Information Rights Log
-- Track what info rights each investor has and when packets sent
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_information_rights_r1917 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  right_type text NOT NULL CHECK (right_type IN ('monthly_update','quarterly_update','annual_audit','board_minutes','financials_quarterly','all_documents')),
  frequency text NOT NULL CHECK (frequency IN ('monthly','quarterly','annual','on_request')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','expired')),
  started_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iir_r1917_investor ON public.investor_information_rights_r1917(investor_id);
CREATE INDEX IF NOT EXISTS idx_iir_r1917_status ON public.investor_information_rights_r1917(status);
CREATE INDEX IF NOT EXISTS idx_iir_r1917_expires ON public.investor_information_rights_r1917(expires_at);

CREATE TABLE IF NOT EXISTS public.investor_info_packet_log_r1917 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  right_id uuid NOT NULL REFERENCES public.investor_information_rights_r1917(id) ON DELETE CASCADE,
  sent_at timestamptz NOT NULL DEFAULT now(),
  packet_type text NOT NULL,
  packet_url text,
  by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iipl_r1917_right ON public.investor_info_packet_log_r1917(right_id);
CREATE INDEX IF NOT EXISTS idx_iipl_r1917_sent ON public.investor_info_packet_log_r1917(sent_at DESC);

ALTER TABLE public.investor_information_rights_r1917 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_info_packet_log_r1917 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iir_r1917 ON public.investor_information_rights_r1917;
CREATE POLICY founder_all_iir_r1917 ON public.investor_information_rights_r1917
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_iipl_r1917 ON public.investor_info_packet_log_r1917;
CREATE POLICY founder_all_iipl_r1917 ON public.investor_info_packet_log_r1917
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_rights
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_investor_info_rights_r1917()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  right_type text,
  frequency text,
  status text,
  started_at timestamptz,
  expires_at timestamptz,
  notes text,
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
    SELECT r.id, r.investor_id, r.right_type, r.frequency, r.status,
           r.started_at, r.expires_at, r.notes, r.created_at
    FROM public.investor_information_rights_r1917 r
    ORDER BY r.created_at DESC
    LIMIT 500;
END;
$$;

-- =====================================================================
-- RPC 2: log_right (write)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_investor_info_right_r1917(
  p_investor_id uuid,
  p_right_type text,
  p_frequency text,
  p_expires_at timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.investor_information_rights_r1917
    (investor_id, right_type, frequency, expires_at, notes)
  VALUES (p_investor_id, p_right_type, p_frequency, p_expires_at, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_investor_info_right_r1917',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'right_type', p_right_type, 'frequency', p_frequency)
  );

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_packets
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_investor_info_packets_r1917()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  sent_at timestamptz,
  packet_type text,
  packet_url text,
  by_email text,
  notes text,
  right_type text,
  investor_id uuid
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
    SELECT p.id, p.right_id, p.sent_at, p.packet_type, p.packet_url,
           p.by_email, p.notes, r.right_type, r.investor_id
    FROM public.investor_info_packet_log_r1917 p
    LEFT JOIN public.investor_information_rights_r1917 r ON r.id = p.right_id
    ORDER BY p.sent_at DESC
    LIMIT 500;
END;
$$;

-- =====================================================================
-- RPC 4: log_packet (write)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_investor_info_packet_r1917(
  p_right_id uuid,
  p_packet_type text,
  p_packet_url text DEFAULT NULL,
  p_by_email text DEFAULT NULL,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.investor_info_packet_log_r1917
    (right_id, packet_type, packet_url, by_email, notes)
  VALUES (p_right_id, p_packet_type, p_packet_url, p_by_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_investor_info_packet_r1917',
    jsonb_build_object('id', v_id, 'right_id', p_right_id, 'packet_type', p_packet_type)
  );

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_status (write)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_investor_info_right_status_r1917(
  p_right_id uuid,
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
  IF p_status NOT IN ('active','paused','expired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_information_rights_r1917
    SET status = p_status, updated_at = now()
    WHERE id = p_right_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_investor_info_right_status_r1917',
    jsonb_build_object('right_id', p_right_id, 'status', p_status)
  );
END;
$$;

-- =====================================================================
-- RPC 6: due_soon — rights with expires_at within 30 days
-- =====================================================================
CREATE OR REPLACE FUNCTION public.due_soon_investor_info_rights_r1917()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  right_type text,
  frequency text,
  status text,
  expires_at timestamptz,
  days_until int
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
    SELECT r.id, r.investor_id, r.right_type, r.frequency, r.status,
           r.expires_at,
           EXTRACT(DAY FROM (r.expires_at - now()))::int AS days_until
    FROM public.investor_information_rights_r1917 r
    WHERE r.status = 'active'
      AND r.expires_at IS NOT NULL
      AND r.expires_at <= now() + interval '30 days'
      AND r.expires_at >= now()
    ORDER BY r.expires_at ASC
    LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 7: recent_packets — last 14 days
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_investor_info_packets_r1917()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  sent_at timestamptz,
  packet_type text,
  packet_url text,
  by_email text,
  right_type text,
  investor_id uuid
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
    SELECT p.id, p.right_id, p.sent_at, p.packet_type, p.packet_url,
           p.by_email, r.right_type, r.investor_id
    FROM public.investor_info_packet_log_r1917 p
    LEFT JOIN public.investor_information_rights_r1917 r ON r.id = p.right_id
    WHERE p.sent_at >= now() - interval '14 days'
    ORDER BY p.sent_at DESC
    LIMIT 200;
END;
$$;

-- =====================================================================
-- REVOKE + GRANT all 7 functions
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_investor_info_rights_r1917() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_info_rights_r1917() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_info_right_r1917(uuid, text, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_info_right_r1917(uuid, text, text, timestamptz, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_info_packets_r1917() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_info_packets_r1917() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_info_packet_r1917(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_info_packet_r1917(uuid, text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_investor_info_right_status_r1917(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_investor_info_right_status_r1917(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.due_soon_investor_info_rights_r1917() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.due_soon_investor_info_rights_r1917() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_investor_info_packets_r1917() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_investor_info_packets_r1917() TO authenticated;

COMMIT;
