BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_dividend_preference_r2189 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_class_label text NOT NULL,
  preference_rate_pct numeric NOT NULL,
  accrual_method text NOT NULL CHECK (accrual_method IN ('simple','compound','cumulative','non_cumulative')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','converted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_dividend_pref_action_log_r2189 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  preference_id uuid NOT NULL REFERENCES public.investor_cap_table_dividend_preference_r2189(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('granted','accrued','paid','converted','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_dividend_preference_r2189 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_dividend_pref_action_log_r2189 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pref_r2189 ON public.investor_cap_table_dividend_preference_r2189;
CREATE POLICY founder_all_pref_r2189 ON public.investor_cap_table_dividend_preference_r2189
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_log_r2189 ON public.investor_dividend_pref_action_log_r2189;
CREATE POLICY founder_all_log_r2189 ON public.investor_dividend_pref_action_log_r2189
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_preferences_r2189();
CREATE FUNCTION public.list_preferences_r2189()
RETURNS TABLE(id uuid, share_class_label text, preference_rate_pct numeric, accrual_method text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.share_class_label, p.preference_rate_pct, p.accrual_method, p.status, p.captured_at
    FROM public.investor_cap_table_dividend_preference_r2189 p
    ORDER BY p.captured_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_preferences_r2189() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_preferences_r2189() TO authenticated;

DROP FUNCTION IF EXISTS public.log_preference_r2189(text, numeric, text);
CREATE FUNCTION public.log_preference_r2189(p_label text, p_rate numeric, p_method text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_dividend_preference_r2189(share_class_label, preference_rate_pct, accrual_method)
    VALUES (p_label, p_rate, p_method) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_preference_r2189', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_preference_r2189(text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_preference_r2189(text, numeric, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_actions_r2189(uuid);
CREATE FUNCTION public.list_actions_r2189(p_pref uuid)
RETURNS TABLE(id uuid, preference_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.preference_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_dividend_pref_action_log_r2189 a
    WHERE a.preference_id = p_pref
    ORDER BY a.taken_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2189(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2189(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_action_r2189(uuid, text, text, bigint, text);
CREATE FUNCTION public.log_action_r2189(p_pref uuid, p_type text, p_email text, p_amount bigint, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_dividend_pref_action_log_r2189(preference_id, action_type, by_email, amount_rupees, notes_md)
    VALUES (p_pref, p_type, p_email, p_amount, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2189', jsonb_build_object('id', v_id, 'pref', p_pref, 'type', p_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2189(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2189(uuid, text, text, bigint, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_status_r2189(uuid, text);
CREATE FUNCTION public.mark_status_r2189(p_pref uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_dividend_preference_r2189
    SET status = p_status, updated_at = now()
    WHERE id = p_pref;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2189', jsonb_build_object('id', p_pref, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2189(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2189(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.active_preferences_r2189();
CREATE FUNCTION public.active_preferences_r2189()
RETURNS TABLE(id uuid, share_class_label text, preference_rate_pct numeric, accrual_method text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.share_class_label, p.preference_rate_pct, p.accrual_method, p.captured_at
    FROM public.investor_cap_table_dividend_preference_r2189 p
    WHERE p.status = 'active'
    ORDER BY p.preference_rate_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.active_preferences_r2189() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_preferences_r2189() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_actions_r2189(integer);
CREATE FUNCTION public.recent_actions_r2189(p_limit integer)
RETURNS TABLE(id uuid, preference_id uuid, share_class_label text, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.preference_id, p.share_class_label, a.action_type, a.taken_at, a.by_email, a.amount_rupees
    FROM public.investor_dividend_pref_action_log_r2189 a
    JOIN public.investor_cap_table_dividend_preference_r2189 p ON p.id = a.preference_id
    ORDER BY a.taken_at DESC
    LIMIT COALESCE(p_limit, 50);
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2189(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2189(integer) TO authenticated;

COMMIT;
