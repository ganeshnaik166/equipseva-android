BEGIN;

-- Round 2012 — Engineer Customer-Direct Tip Tracker
-- Two tables with _r2012 suffix, RLS + founder policy, 7 SECDEF RPCs gated by is_founder()

CREATE TABLE IF NOT EXISTS public.engineer_customer_tip_tracker_r2012 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  tip_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (tip_amount_rupees >= 0),
  tip_type text NOT NULL CHECK (tip_type IN ('direct_cash','digital_transfer','gift','postpaid')),
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','disputed','forwarded_to_co','charity')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_customer_tip_tracker_r2012_engineer_idx
  ON public.engineer_customer_tip_tracker_r2012(engineer_user_id);
CREATE INDEX IF NOT EXISTS engineer_customer_tip_tracker_r2012_status_idx
  ON public.engineer_customer_tip_tracker_r2012(status);
CREATE INDEX IF NOT EXISTS engineer_customer_tip_tracker_r2012_captured_idx
  ON public.engineer_customer_tip_tracker_r2012(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_tip_action_log_r2012 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tip_id uuid NOT NULL REFERENCES public.engineer_customer_tip_tracker_r2012(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('received_confirmed','disputed','forwarded_to_co','charity_action')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_tip_action_log_r2012_tip_idx
  ON public.engineer_tip_action_log_r2012(tip_id);
CREATE INDEX IF NOT EXISTS engineer_tip_action_log_r2012_taken_idx
  ON public.engineer_tip_action_log_r2012(taken_at DESC);

ALTER TABLE public.engineer_customer_tip_tracker_r2012 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_tip_action_log_r2012 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_customer_tip_tracker_r2012_founder_all ON public.engineer_customer_tip_tracker_r2012;
CREATE POLICY engineer_customer_tip_tracker_r2012_founder_all
  ON public.engineer_customer_tip_tracker_r2012
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS engineer_tip_action_log_r2012_founder_all ON public.engineer_tip_action_log_r2012;
CREATE POLICY engineer_tip_action_log_r2012_founder_all
  ON public.engineer_tip_action_log_r2012
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_tips
CREATE OR REPLACE FUNCTION public.list_tips_r2012()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  repair_job_id uuid,
  tip_amount_rupees bigint,
  tip_type text,
  status text,
  captured_at timestamptz,
  notes_md text
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
  SELECT
    t.id,
    t.engineer_user_id,
    p.email::text,
    t.hospital_id,
    o.name::text,
    t.repair_job_id,
    t.tip_amount_rupees,
    t.tip_type,
    t.status,
    t.captured_at,
    t.notes_md
  FROM public.engineer_customer_tip_tracker_r2012 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = t.hospital_id
  ORDER BY t.captured_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log_tip
CREATE OR REPLACE FUNCTION public.log_tip_r2012(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_repair_job_id uuid,
  p_amount bigint,
  p_tip_type text,
  p_notes text
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
  INSERT INTO public.engineer_customer_tip_tracker_r2012(
    engineer_user_id, hospital_id, repair_job_id, tip_amount_rupees, tip_type, notes_md
  ) VALUES (
    p_engineer_user_id, p_hospital_id, p_repair_job_id, p_amount, p_tip_type, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_tip_r2012',
    jsonb_build_object('tip_id', v_id, 'engineer_user_id', p_engineer_user_id, 'amount', p_amount, 'tip_type', p_tip_type)
  );
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_tip_actions_r2012(p_tip_id uuid)
RETURNS TABLE (
  id uuid,
  tip_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
  SELECT a.id, a.tip_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_tip_action_log_r2012 a
  WHERE (p_tip_id IS NULL OR a.tip_id = p_tip_id)
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_tip_action_r2012(
  p_tip_id uuid,
  p_action_type text,
  p_notes text
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
  INSERT INTO public.engineer_tip_action_log_r2012(tip_id, action_type, by_email, notes_md)
  VALUES (p_tip_id, p_action_type, (auth.jwt()->>'email'), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_tip_action_r2012',
    jsonb_build_object('tip_id', p_tip_id, 'action_type', p_action_type, 'action_id', v_id)
  );
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_tip_status_r2012(
  p_tip_id uuid,
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
  UPDATE public.engineer_customer_tip_tracker_r2012
     SET status = p_status, updated_at = now()
   WHERE id = p_tip_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_tip_status_r2012',
    jsonb_build_object('tip_id', p_tip_id, 'status', p_status)
  );
END;
$$;

-- RPC 6: top_tipped
CREATE OR REPLACE FUNCTION public.top_tipped_engineers_r2012()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_tips_rupees bigint,
  tip_count bigint
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
  SELECT
    t.engineer_user_id,
    p.email::text,
    COALESCE(SUM(t.tip_amount_rupees), 0)::bigint AS total_tips_rupees,
    COUNT(*)::bigint AS tip_count
  FROM public.engineer_customer_tip_tracker_r2012 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  GROUP BY t.engineer_user_id, p.email
  ORDER BY total_tips_rupees DESC
  LIMIT 50;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_tip_actions_r2012()
RETURNS TABLE (
  id uuid,
  tip_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
  SELECT a.id, a.tip_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_tip_action_log_r2012 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tips_r2012() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tip_r2012(uuid, uuid, uuid, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_tip_actions_r2012(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tip_action_r2012(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_tip_status_r2012(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_tipped_engineers_r2012() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_tip_actions_r2012() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tips_r2012() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tip_r2012(uuid, uuid, uuid, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tip_actions_r2012(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tip_action_r2012(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_tip_status_r2012(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tipped_engineers_r2012() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_tip_actions_r2012() TO authenticated;

COMMIT;
