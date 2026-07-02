BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_series_negotiations_r1989 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  series_label text NOT NULL,
  current_valuation_pre_rupees bigint NOT NULL DEFAULT 0,
  target_valuation_pre_rupees bigint NOT NULL DEFAULT 0,
  current_dilution_pct numeric(5,2) NOT NULL DEFAULT 0,
  target_dilution_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active_negotiation'
    CHECK (status IN ('active_negotiation','term_sheet_signed','walked_away','superseded')),
  started_at timestamptz NOT NULL DEFAULT now(),
  signed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_negotiation_action_log_r1989 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id uuid NOT NULL REFERENCES public.investor_series_negotiations_r1989(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('term_changed','counter_offered','walked_away','agreed_to_terms','signed','extended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_series_negotiations_r1989 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_negotiation_action_log_r1989 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_neg_r1989 ON public.investor_series_negotiations_r1989;
CREATE POLICY founder_all_neg_r1989 ON public.investor_series_negotiations_r1989
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_act_r1989 ON public.investor_negotiation_action_log_r1989;
CREATE POLICY founder_all_act_r1989 ON public.investor_negotiation_action_log_r1989
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list_negotiations
CREATE OR REPLACE FUNCTION public.list_negotiations_r1989()
RETURNS TABLE (
  id uuid, investor_id uuid, series_label text,
  current_valuation_pre_rupees bigint, target_valuation_pre_rupees bigint,
  current_dilution_pct numeric, target_dilution_pct numeric,
  status text, started_at timestamptz, signed_at timestamptz, created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT n.id, n.investor_id, n.series_label,
           n.current_valuation_pre_rupees, n.target_valuation_pre_rupees,
           n.current_dilution_pct, n.target_dilution_pct,
           n.status, n.started_at, n.signed_at, n.created_at
    FROM public.investor_series_negotiations_r1989 n
    ORDER BY n.created_at DESC
    LIMIT 200;
END $$;

-- log_negotiation
CREATE OR REPLACE FUNCTION public.log_negotiation_r1989(
  p_investor_id uuid,
  p_series_label text,
  p_current_valuation_pre_rupees bigint,
  p_target_valuation_pre_rupees bigint,
  p_current_dilution_pct numeric,
  p_target_dilution_pct numeric
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_series_negotiations_r1989
    (investor_id, series_label, current_valuation_pre_rupees, target_valuation_pre_rupees,
     current_dilution_pct, target_dilution_pct, status, started_at)
  VALUES
    (p_investor_id, p_series_label, COALESCE(p_current_valuation_pre_rupees,0),
     COALESCE(p_target_valuation_pre_rupees,0),
     COALESCE(p_current_dilution_pct,0), COALESCE(p_target_dilution_pct,0),
     'active_negotiation', now())
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_negotiation_r1989',
          jsonb_build_object('negotiation_id', v_id, 'series_label', p_series_label));
  RETURN v_id;
END $$;

-- list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1989(p_negotiation_id uuid)
RETURNS TABLE (
  id uuid, negotiation_id uuid, action_type text,
  taken_at timestamptz, by_email text, notes_md text, created_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.negotiation_id, a.action_type, a.taken_at, a.by_email, a.notes_md, a.created_at
    FROM public.investor_negotiation_action_log_r1989 a
    WHERE a.negotiation_id = p_negotiation_id
    ORDER BY a.taken_at DESC
    LIMIT 500;
END $$;

-- log_action
CREATE OR REPLACE FUNCTION public.log_action_r1989(
  p_negotiation_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_negotiation_action_log_r1989
    (negotiation_id, action_type, taken_at, by_email, notes_md)
  VALUES (p_negotiation_id, p_action_type, now(), p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1989',
          jsonb_build_object('action_id', v_id, 'negotiation_id', p_negotiation_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1989(p_negotiation_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_series_negotiations_r1989
    SET status = p_status,
        signed_at = CASE WHEN p_status = 'term_sheet_signed' THEN now() ELSE signed_at END,
        updated_at = now()
    WHERE id = p_negotiation_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1989',
          jsonb_build_object('negotiation_id', p_negotiation_id, 'status', p_status));
END $$;

-- active_negotiations
CREATE OR REPLACE FUNCTION public.active_negotiations_r1989()
RETURNS TABLE (
  id uuid, series_label text, current_valuation_pre_rupees bigint,
  target_valuation_pre_rupees bigint, current_dilution_pct numeric,
  target_dilution_pct numeric, started_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT n.id, n.series_label, n.current_valuation_pre_rupees,
           n.target_valuation_pre_rupees, n.current_dilution_pct,
           n.target_dilution_pct, n.started_at
    FROM public.investor_series_negotiations_r1989 n
    WHERE n.status = 'active_negotiation'
    ORDER BY n.started_at DESC
    LIMIT 100;
END $$;

-- recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1989()
RETURNS TABLE (
  id uuid, negotiation_id uuid, action_type text,
  taken_at timestamptz, by_email text, notes_md text
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.negotiation_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_negotiation_action_log_r1989 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_negotiations_r1989() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_negotiation_r1989(uuid, text, bigint, bigint, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1989(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1989(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1989(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_negotiations_r1989() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1989() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_negotiations_r1989() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_negotiation_r1989(uuid, text, bigint, bigint, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1989(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1989(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1989(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_negotiations_r1989() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1989() TO authenticated;

COMMIT;
