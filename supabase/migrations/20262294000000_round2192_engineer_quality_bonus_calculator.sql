BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_quality_bonus_calculator_r2192 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  quality_score int NOT NULL CHECK (quality_score BETWEEN 0 AND 100),
  bonus_multiplier numeric(6,3) NOT NULL DEFAULT 1.000,
  bonus_amount_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'calculated' CHECK (status IN ('calculated','approved','paid','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eqbc_r2192_engineer ON public.engineer_quality_bonus_calculator_r2192(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eqbc_r2192_status ON public.engineer_quality_bonus_calculator_r2192(status);
CREATE INDEX IF NOT EXISTS idx_eqbc_r2192_captured ON public.engineer_quality_bonus_calculator_r2192(captured_at DESC);

ALTER TABLE public.engineer_quality_bonus_calculator_r2192 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eqbc_r2192 ON public.engineer_quality_bonus_calculator_r2192;
CREATE POLICY founder_all_eqbc_r2192 ON public.engineer_quality_bonus_calculator_r2192
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_bonus_action_log_r2192 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bonus_id uuid NOT NULL REFERENCES public.engineer_quality_bonus_calculator_r2192(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calculated','approved','paid','disputed','adjusted')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ebal_r2192_bonus ON public.engineer_bonus_action_log_r2192(bonus_id);
CREATE INDEX IF NOT EXISTS idx_ebal_r2192_taken ON public.engineer_bonus_action_log_r2192(taken_at DESC);

ALTER TABLE public.engineer_bonus_action_log_r2192 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ebal_r2192 ON public.engineer_bonus_action_log_r2192;
CREATE POLICY founder_all_ebal_r2192 ON public.engineer_bonus_action_log_r2192
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_bonuses_r2192()
RETURNS TABLE(id uuid, engineer_user_id uuid, period_label text, quality_score int, bonus_multiplier numeric, bonus_amount_rupees bigint, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT b.id, b.engineer_user_id, b.period_label, b.quality_score, b.bonus_multiplier, b.bonus_amount_rupees, b.status, b.captured_at
    FROM public.engineer_quality_bonus_calculator_r2192 b
    ORDER BY b.captured_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bonuses_r2192() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bonuses_r2192() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_bonus_r2192(p_engineer_user_id uuid, p_period_label text, p_quality_score int, p_bonus_multiplier numeric, p_bonus_amount_rupees bigint)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_quality_bonus_calculator_r2192(engineer_user_id, period_label, quality_score, bonus_multiplier, bonus_amount_rupees)
    VALUES (p_engineer_user_id, p_period_label, p_quality_score, p_bonus_multiplier, p_bonus_amount_rupees)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bonus_r2192', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'period_label', p_period_label, 'amount', p_bonus_amount_rupees), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_bonus_r2192(uuid, text, int, numeric, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_bonus_r2192(uuid, text, int, numeric, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2192(p_bonus_id uuid)
RETURNS TABLE(id uuid, bonus_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.bonus_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.engineer_bonus_action_log_r2192 a
    WHERE a.bonus_id = p_bonus_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2192(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2192(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2192(p_bonus_id uuid, p_action_type text, p_by_email text, p_amount_rupees bigint, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_bonus_action_log_r2192(bonus_id, action_type, by_email, amount_rupees, notes_md)
    VALUES (p_bonus_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2192', jsonb_build_object('id', v_id, 'bonus_id', p_bonus_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2192(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2192(uuid, text, text, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2192(p_bonus_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_quality_bonus_calculator_r2192 SET status = p_status, updated_at = now() WHERE id = p_bonus_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2192', jsonb_build_object('bonus_id', p_bonus_id, 'status', p_status), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2192(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2192(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.top_bonuses_r2192()
RETURNS TABLE(id uuid, engineer_user_id uuid, period_label text, quality_score int, bonus_amount_rupees bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT b.id, b.engineer_user_id, b.period_label, b.quality_score, b.bonus_amount_rupees, b.status
    FROM public.engineer_quality_bonus_calculator_r2192 b
    ORDER BY b.bonus_amount_rupees DESC
    LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_bonuses_r2192() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_bonuses_r2192() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2192()
RETURNS TABLE(id uuid, bonus_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.bonus_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.engineer_bonus_action_log_r2192 a
    ORDER BY a.taken_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2192() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2192() TO authenticated;

COMMIT;
