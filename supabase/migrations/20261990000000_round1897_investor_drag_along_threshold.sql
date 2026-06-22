BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_drag_along_thresholds_r1897 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  threshold_label text NOT NULL,
  total_shares_required bigint NOT NULL DEFAULT 0,
  current_consenting_shares bigint NOT NULL DEFAULT 0,
  threshold_pct numeric NOT NULL DEFAULT 0,
  current_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'below_threshold' CHECK (status IN ('below_threshold','at_threshold','above_threshold')),
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_drag_along_consents_r1897 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  threshold_id uuid NOT NULL REFERENCES public.investor_drag_along_thresholds_r1897(id) ON DELETE CASCADE,
  investor_id uuid NOT NULL,
  shares_consented bigint NOT NULL DEFAULT 0,
  consent_given_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','granted','withdrawn')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_drag_along_thresholds_r1897 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_drag_along_consents_r1897 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_thresholds_r1897 ON public.investor_drag_along_thresholds_r1897;
CREATE POLICY founder_all_thresholds_r1897 ON public.investor_drag_along_thresholds_r1897
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_consents_r1897 ON public.investor_drag_along_consents_r1897;
CREATE POLICY founder_all_consents_r1897 ON public.investor_drag_along_consents_r1897
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_thresholds_r1897()
RETURNS TABLE (
  id uuid,
  threshold_label text,
  total_shares_required bigint,
  current_consenting_shares bigint,
  threshold_pct numeric,
  current_pct numeric,
  status text,
  last_assessed_at timestamptz,
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
  SELECT t.id, t.threshold_label, t.total_shares_required, t.current_consenting_shares,
         t.threshold_pct, t.current_pct, t.status, t.last_assessed_at, t.created_at
  FROM public.investor_drag_along_thresholds_r1897 t
  ORDER BY t.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_threshold_r1897(
  p_label text,
  p_total_shares bigint,
  p_threshold_pct numeric
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
  INSERT INTO public.investor_drag_along_thresholds_r1897(
    threshold_label, total_shares_required, threshold_pct, last_assessed_at
  ) VALUES (p_label, p_total_shares, p_threshold_pct, now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_threshold_r1897',
    jsonb_build_object('id', v_id, 'label', p_label, 'total_shares', p_total_shares, 'pct', p_threshold_pct));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_consents_r1897(p_threshold_id uuid)
RETURNS TABLE (
  id uuid,
  threshold_id uuid,
  investor_id uuid,
  shares_consented bigint,
  consent_given_at timestamptz,
  status text,
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
  SELECT c.id, c.threshold_id, c.investor_id, c.shares_consented, c.consent_given_at, c.status, c.created_at
  FROM public.investor_drag_along_consents_r1897 c
  WHERE c.threshold_id = p_threshold_id
  ORDER BY c.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_consent_r1897(
  p_threshold_id uuid,
  p_investor_id uuid,
  p_shares bigint,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('pending','granted','withdrawn') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  INSERT INTO public.investor_drag_along_consents_r1897(
    threshold_id, investor_id, shares_consented, consent_given_at, status
  ) VALUES (
    p_threshold_id, p_investor_id, p_shares,
    CASE WHEN p_status = 'granted' THEN now() ELSE NULL END,
    p_status
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_consent_r1897',
    jsonb_build_object('id', v_id, 'threshold_id', p_threshold_id, 'investor_id', p_investor_id, 'shares', p_shares, 'status', p_status));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.recompute_thresholds_r1897()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_drag_along_thresholds_r1897 t
  SET current_consenting_shares = COALESCE(sub.s, 0),
      current_pct = CASE WHEN t.total_shares_required > 0
                         THEN ROUND((COALESCE(sub.s,0)::numeric / t.total_shares_required::numeric) * 100, 2)
                         ELSE 0 END,
      status = CASE
        WHEN t.total_shares_required = 0 THEN 'below_threshold'
        WHEN (COALESCE(sub.s,0)::numeric / t.total_shares_required::numeric) * 100 >= t.threshold_pct THEN 'above_threshold'
        WHEN (COALESCE(sub.s,0)::numeric / t.total_shares_required::numeric) * 100 = t.threshold_pct THEN 'at_threshold'
        ELSE 'below_threshold'
      END,
      last_assessed_at = now(),
      updated_at = now()
  FROM (
    SELECT threshold_id, SUM(shares_consented)::bigint AS s
    FROM public.investor_drag_along_consents_r1897
    WHERE status = 'granted'
    GROUP BY threshold_id
  ) sub
  WHERE t.id = sub.threshold_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'recompute_thresholds_r1897',
    jsonb_build_object('updated', v_count));
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.thresholds_above_r1897()
RETURNS TABLE (
  id uuid,
  threshold_label text,
  threshold_pct numeric,
  current_pct numeric,
  status text,
  last_assessed_at timestamptz
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
  SELECT t.id, t.threshold_label, t.threshold_pct, t.current_pct, t.status, t.last_assessed_at
  FROM public.investor_drag_along_thresholds_r1897 t
  WHERE t.status IN ('at_threshold','above_threshold')
  ORDER BY t.current_pct DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_consents_r1897(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  threshold_id uuid,
  investor_id uuid,
  shares_consented bigint,
  status text,
  consent_given_at timestamptz,
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
  SELECT c.id, c.threshold_id, c.investor_id, c.shares_consented, c.status, c.consent_given_at, c.created_at
  FROM public.investor_drag_along_consents_r1897 c
  ORDER BY c.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_thresholds_r1897() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_threshold_r1897(text, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_consents_r1897(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_consent_r1897(uuid, uuid, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recompute_thresholds_r1897() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.thresholds_above_r1897() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_consents_r1897(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_thresholds_r1897() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_threshold_r1897(text, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_consents_r1897(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_consent_r1897(uuid, uuid, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_thresholds_r1897() TO authenticated;
GRANT EXECUTE ON FUNCTION public.thresholds_above_r1897() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_consents_r1897(int) TO authenticated;

COMMIT;