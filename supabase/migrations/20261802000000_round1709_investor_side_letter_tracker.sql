BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_side_letters_r1709 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  letter_title text NOT NULL,
  executed_on date NOT NULL,
  key_terms_md text NOT NULL DEFAULT '',
  expiry_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','superseded')),
  supersedes_letter_id uuid REFERENCES public.investor_side_letters_r1709(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_side_letter_obligations_r1709 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_side_letters_r1709(id) ON DELETE CASCADE,
  obligation_text text NOT NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','met','in_progress','overdue')),
  met_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_side_letters_r1709 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_side_letter_obligations_r1709 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_letters_r1709 ON public.investor_side_letters_r1709;
CREATE POLICY founder_all_letters_r1709 ON public.investor_side_letters_r1709
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_oblig_r1709 ON public.investor_side_letter_obligations_r1709;
CREATE POLICY founder_all_oblig_r1709 ON public.investor_side_letter_obligations_r1709
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_letters
CREATE OR REPLACE FUNCTION public.list_letters_r1709()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  letter_title text,
  executed_on date,
  expiry_date date,
  status text,
  obligation_count int,
  open_obligation_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.investor_id, l.letter_title, l.executed_on, l.expiry_date, l.status,
    (SELECT (COUNT(*))::int FROM public.investor_side_letter_obligations_r1709 o WHERE o.letter_id = l.id) AS obligation_count,
    (SELECT (COUNT(*))::int FROM public.investor_side_letter_obligations_r1709 o WHERE o.letter_id = l.id AND o.status IN ('open','in_progress','overdue')) AS open_obligation_count
  FROM public.investor_side_letters_r1709 l
  ORDER BY l.executed_on DESC;
END;
$$;

-- RPC 2: add_letter
CREATE OR REPLACE FUNCTION public.add_letter_r1709(
  p_investor_id uuid,
  p_letter_title text,
  p_executed_on date,
  p_key_terms_md text,
  p_expiry_date date,
  p_supersedes_letter_id uuid
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letters_r1709 (investor_id, letter_title, executed_on, key_terms_md, expiry_date, supersedes_letter_id)
  VALUES (p_investor_id, p_letter_title, p_executed_on, COALESCE(p_key_terms_md,''), p_expiry_date, p_supersedes_letter_id)
  RETURNING id INTO v_id;
  IF p_supersedes_letter_id IS NOT NULL THEN
    UPDATE public.investor_side_letters_r1709 SET status='superseded', updated_at=now() WHERE id = p_supersedes_letter_id;
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_letter_r1709', jsonb_build_object('letter_id', v_id, 'investor_id', p_investor_id, 'title', p_letter_title));
  RETURN v_id;
END;
$$;

-- RPC 3: list_obligations
CREATE OR REPLACE FUNCTION public.list_obligations_r1709(p_letter_id uuid)
RETURNS TABLE (
  id uuid,
  letter_id uuid,
  obligation_text text,
  due_date date,
  status text,
  met_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.letter_id, o.obligation_text, o.due_date, o.status, o.met_at
  FROM public.investor_side_letter_obligations_r1709 o
  WHERE o.letter_id = p_letter_id
  ORDER BY COALESCE(o.due_date, '9999-12-31'::date) ASC;
END;
$$;

-- RPC 4: add_obligation
CREATE OR REPLACE FUNCTION public.add_obligation_r1709(
  p_letter_id uuid,
  p_obligation_text text,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letter_obligations_r1709 (letter_id, obligation_text, due_date)
  VALUES (p_letter_id, p_obligation_text, p_due_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_obligation_r1709', jsonb_build_object('obligation_id', v_id, 'letter_id', p_letter_id));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_obligation_met
CREATE OR REPLACE FUNCTION public.mark_obligation_met_r1709(p_obligation_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_side_letter_obligations_r1709
  SET status='met', met_at=now(), updated_at=now()
  WHERE id = p_obligation_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_obligation_met_r1709', jsonb_build_object('obligation_id', p_obligation_id));
END;
$$;

-- RPC 6: overdue_obligations
CREATE OR REPLACE FUNCTION public.overdue_obligations_r1709()
RETURNS TABLE (
  id uuid,
  letter_id uuid,
  letter_title text,
  investor_id uuid,
  obligation_text text,
  due_date date,
  days_overdue int,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.letter_id, l.letter_title, l.investor_id, o.obligation_text, o.due_date,
    GREATEST(0, (CURRENT_DATE - o.due_date))::int AS days_overdue,
    o.status
  FROM public.investor_side_letter_obligations_r1709 o
  JOIN public.investor_side_letters_r1709 l ON l.id = o.letter_id
  WHERE o.due_date IS NOT NULL
    AND o.due_date < CURRENT_DATE
    AND o.status IN ('open','in_progress','overdue')
  ORDER BY o.due_date ASC;
END;
$$;

-- RPC 7: letter_summary_per_investor
CREATE OR REPLACE FUNCTION public.letter_summary_per_investor_r1709()
RETURNS TABLE (
  investor_id uuid,
  active_letters int,
  expired_letters int,
  superseded_letters int,
  total_obligations int,
  open_obligations int,
  overdue_obligations int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.investor_id,
    (COUNT(*) FILTER (WHERE l.status='active'))::int AS active_letters,
    (COUNT(*) FILTER (WHERE l.status='expired'))::int AS expired_letters,
    (COUNT(*) FILTER (WHERE l.status='superseded'))::int AS superseded_letters,
    (SELECT (COUNT(*))::int FROM public.investor_side_letter_obligations_r1709 o
      WHERE o.letter_id IN (SELECT id FROM public.investor_side_letters_r1709 WHERE investor_id = l.investor_id)) AS total_obligations,
    (SELECT (COUNT(*))::int FROM public.investor_side_letter_obligations_r1709 o
      WHERE o.letter_id IN (SELECT id FROM public.investor_side_letters_r1709 WHERE investor_id = l.investor_id)
        AND o.status IN ('open','in_progress','overdue')) AS open_obligations,
    (SELECT (COUNT(*))::int FROM public.investor_side_letter_obligations_r1709 o
      WHERE o.letter_id IN (SELECT id FROM public.investor_side_letters_r1709 WHERE investor_id = l.investor_id)
        AND o.due_date IS NOT NULL AND o.due_date < CURRENT_DATE
        AND o.status IN ('open','in_progress','overdue')) AS overdue_obligations
  FROM public.investor_side_letters_r1709 l
  GROUP BY l.investor_id
  ORDER BY l.investor_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_letters_r1709() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_letter_r1709(uuid, text, date, text, date, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_obligations_r1709(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_obligation_r1709(uuid, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_obligation_met_r1709(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_obligations_r1709() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.letter_summary_per_investor_r1709() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r1709() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_letter_r1709(uuid, text, date, text, date, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_obligations_r1709(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_obligation_r1709(uuid, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_obligation_met_r1709(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_obligations_r1709() TO authenticated;
GRANT EXECUTE ON FUNCTION public.letter_summary_per_investor_r1709() TO authenticated;

COMMIT;