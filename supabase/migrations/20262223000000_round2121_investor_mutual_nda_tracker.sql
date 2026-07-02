BEGIN;

-- ============================================================
-- Round 2121 — Investor Mutual NDA Tracker
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_mutual_nda_tracker_r2121 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  nda_label text NOT NULL,
  signed_date date,
  expires_at date,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','expired','extended','terminated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_nda_r2121_investor
  ON public.investor_mutual_nda_tracker_r2121(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_nda_r2121_status
  ON public.investor_mutual_nda_tracker_r2121(status);
CREATE INDEX IF NOT EXISTS idx_inv_nda_r2121_expires
  ON public.investor_mutual_nda_tracker_r2121(expires_at);

ALTER TABLE public.investor_mutual_nda_tracker_r2121 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_nda_r2121 ON public.investor_mutual_nda_tracker_r2121;
CREATE POLICY p_founder_all_nda_r2121 ON public.investor_mutual_nda_tracker_r2121
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_nda_action_log_r2121 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nda_id uuid NOT NULL REFERENCES public.investor_mutual_nda_tracker_r2121(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('signed','extended','terminated','violated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_nda_act_r2121_nda
  ON public.investor_nda_action_log_r2121(nda_id);
CREATE INDEX IF NOT EXISTS idx_inv_nda_act_r2121_taken
  ON public.investor_nda_action_log_r2121(taken_at DESC);

ALTER TABLE public.investor_nda_action_log_r2121 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_nda_act_r2121 ON public.investor_nda_action_log_r2121;
CREATE POLICY p_founder_all_nda_act_r2121 ON public.investor_nda_action_log_r2121
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.list_ndas_r2121();
CREATE OR REPLACE FUNCTION public.list_ndas_r2121()
RETURNS TABLE(id uuid, investor_id uuid, nda_label text, signed_date date, expires_at date, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_id, t.nda_label, t.signed_date, t.expires_at, t.status, t.captured_at
    FROM public.investor_mutual_nda_tracker_r2121 t
    ORDER BY t.captured_at DESC
    LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_nda_r2121(uuid, text, date, date, text);
CREATE OR REPLACE FUNCTION public.log_nda_r2121(
  p_investor_id uuid,
  p_nda_label text,
  p_signed_date date,
  p_expires_at date,
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
  INSERT INTO public.investor_mutual_nda_tracker_r2121(investor_id, nda_label, signed_date, expires_at, status)
  VALUES (p_investor_id, p_nda_label, p_signed_date, p_expires_at, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_nda_r2121',
          jsonb_build_object('nda_id', v_id, 'investor_id', p_investor_id, 'label', p_nda_label), now());

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r2121(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2121(p_nda_id uuid)
RETURNS TABLE(id uuid, nda_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.nda_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_nda_action_log_r2121 a
    WHERE a.nda_id = p_nda_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r2121(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2121(
  p_nda_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.investor_nda_action_log_r2121(nda_id, action_type, by_email, notes_md)
  VALUES (p_nda_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2121',
          jsonb_build_object('action_id', v_id, 'nda_id', p_nda_id, 'action_type', p_action_type), now());

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r2121(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2121(p_nda_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_mutual_nda_tracker_r2121
    SET status = p_status, updated_at = now()
    WHERE id = p_nda_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2121',
          jsonb_build_object('nda_id', p_nda_id, 'status', p_status), now());
END;
$$;

DROP FUNCTION IF EXISTS public.expiring_soon_r2121(int);
CREATE OR REPLACE FUNCTION public.expiring_soon_r2121(p_days int DEFAULT 30)
RETURNS TABLE(id uuid, investor_id uuid, nda_label text, expires_at date, status text, days_left int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.investor_id, t.nda_label, t.expires_at, t.status,
           (t.expires_at - CURRENT_DATE)::int AS days_left
    FROM public.investor_mutual_nda_tracker_r2121 t
    WHERE t.expires_at IS NOT NULL
      AND t.status IN ('active','extended')
      AND t.expires_at <= (CURRENT_DATE + (COALESCE(p_days, 30) || ' days')::interval)
    ORDER BY t.expires_at ASC
    LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r2121(int);
CREATE OR REPLACE FUNCTION public.recent_actions_r2121(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, nda_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.nda_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_nda_action_log_r2121 a
    ORDER BY a.taken_at DESC
    LIMIT LEAST(COALESCE(p_limit, 50), 200);
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_ndas_r2121() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ndas_r2121() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_nda_r2121(uuid, text, date, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_nda_r2121(uuid, text, date, date, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2121(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2121(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r2121(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2121(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2121(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2121(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2121(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2121(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2121(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2121(int) TO authenticated;

COMMIT;
