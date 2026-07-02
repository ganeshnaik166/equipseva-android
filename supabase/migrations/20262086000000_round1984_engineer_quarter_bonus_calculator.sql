BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_quarter_bonus_r1984 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  base_bonus_rupees bigint NOT NULL DEFAULT 0,
  performance_bonus_rupees bigint NOT NULL DEFAULT 0,
  total_bonus_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'calculated' CHECK (status IN ('calculated','approved','paid','disputed','voided')),
  calculated_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eqb_r1984_engineer ON public.engineer_quarter_bonus_r1984(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eqb_r1984_status ON public.engineer_quarter_bonus_r1984(status);
CREATE INDEX IF NOT EXISTS idx_eqb_r1984_quarter ON public.engineer_quarter_bonus_r1984(quarter_label);

ALTER TABLE public.engineer_quarter_bonus_r1984 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eqb_r1984 ON public.engineer_quarter_bonus_r1984;
CREATE POLICY founder_all_eqb_r1984 ON public.engineer_quarter_bonus_r1984
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_bonus_action_log_r1984 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bonus_id uuid NOT NULL REFERENCES public.engineer_quarter_bonus_r1984(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calculated','approved','disputed','adjusted','paid','voided')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ebal_r1984_bonus ON public.engineer_bonus_action_log_r1984(bonus_id);
CREATE INDEX IF NOT EXISTS idx_ebal_r1984_taken ON public.engineer_bonus_action_log_r1984(taken_at DESC);

ALTER TABLE public.engineer_bonus_action_log_r1984 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ebal_r1984 ON public.engineer_bonus_action_log_r1984;
CREATE POLICY founder_all_ebal_r1984 ON public.engineer_bonus_action_log_r1984
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_bonuses_r1984()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  quarter_label text,
  base_bonus_rupees bigint,
  performance_bonus_rupees bigint,
  total_bonus_rupees bigint,
  status text,
  calculated_at timestamptz,
  paid_at timestamptz,
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
  SELECT b.id, b.engineer_user_id, b.quarter_label, b.base_bonus_rupees, b.performance_bonus_rupees,
         b.total_bonus_rupees, b.status, b.calculated_at, b.paid_at, b.created_at
  FROM public.engineer_quarter_bonus_r1984 b
  ORDER BY b.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_bonus_r1984(
  p_engineer_user_id uuid,
  p_quarter_label text,
  p_base bigint,
  p_performance bigint,
  p_status text DEFAULT 'calculated'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_total := COALESCE(p_base, 0) + COALESCE(p_performance, 0);
  INSERT INTO public.engineer_quarter_bonus_r1984(engineer_user_id, quarter_label, base_bonus_rupees, performance_bonus_rupees, total_bonus_rupees, status, calculated_at)
  VALUES (p_engineer_user_id, p_quarter_label, p_base, p_performance, v_total, p_status, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bonus_r1984',
    jsonb_build_object('bonus_id', v_id, 'engineer_user_id', p_engineer_user_id, 'quarter', p_quarter_label, 'total', v_total));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1984(p_bonus_id uuid)
RETURNS TABLE (
  id uuid,
  bonus_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
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
  SELECT a.id, a.bonus_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
  FROM public.engineer_bonus_action_log_r1984 a
  WHERE a.bonus_id = p_bonus_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1984(
  p_bonus_id uuid,
  p_action_type text,
  p_amount_rupees bigint,
  p_notes_md text
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
  INSERT INTO public.engineer_bonus_action_log_r1984(bonus_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_bonus_id, p_action_type, v_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r1984',
    jsonb_build_object('action_id', v_id, 'bonus_id', p_bonus_id, 'action_type', p_action_type, 'amount', p_amount_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1984(
  p_bonus_id uuid,
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
  UPDATE public.engineer_quarter_bonus_r1984
  SET status = p_status,
      paid_at = CASE WHEN p_status = 'paid' THEN now() ELSE paid_at END,
      updated_at = now()
  WHERE id = p_bonus_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1984',
    jsonb_build_object('bonus_id', p_bonus_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_earners_r1984()
RETURNS TABLE (
  engineer_user_id uuid,
  total_paid_rupees bigint,
  bonus_count bigint
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
  SELECT b.engineer_user_id, COALESCE(SUM(b.total_bonus_rupees), 0)::bigint AS total_paid_rupees, COUNT(*)::bigint AS bonus_count
  FROM public.engineer_quarter_bonus_r1984 b
  WHERE b.status IN ('paid','approved')
  GROUP BY b.engineer_user_id
  ORDER BY total_paid_rupees DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1984()
RETURNS TABLE (
  id uuid,
  bonus_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  amount_rupees bigint,
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
  SELECT a.id, a.bonus_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
  FROM public.engineer_bonus_action_log_r1984 a
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_bonuses_r1984() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_bonus_r1984(uuid, text, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1984(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1984(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1984(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_earners_r1984() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1984() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_bonuses_r1984() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_bonus_r1984(uuid, text, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1984(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1984(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1984(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_earners_r1984() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1984() TO authenticated;

COMMIT;
