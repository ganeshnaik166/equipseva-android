BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_cross_sell_opportunities_r1695 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_state text NOT NULL,
  suggested_offer text NOT NULL,
  expected_arr_lift_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','pitched','won','lost')),
  last_outreach_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_opp_r1695_hospital ON public.hospital_cross_sell_opportunities_r1695(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_cs_opp_r1695_status ON public.hospital_cross_sell_opportunities_r1695(status);

ALTER TABLE public.hospital_cross_sell_opportunities_r1695 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_cs_opp_r1695_founder ON public.hospital_cross_sell_opportunities_r1695;
CREATE POLICY p_cs_opp_r1695_founder ON public.hospital_cross_sell_opportunities_r1695
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_cross_sell_outreach_log_r1695 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES public.hospital_cross_sell_opportunities_r1695(id) ON DELETE CASCADE,
  outreach_type text NOT NULL CHECK (outreach_type IN ('email','call','visit','proposal')),
  outreach_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_out_r1695_opp ON public.hospital_cross_sell_outreach_log_r1695(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_cs_out_r1695_at ON public.hospital_cross_sell_outreach_log_r1695(outreach_at);

ALTER TABLE public.hospital_cross_sell_outreach_log_r1695 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_cs_out_r1695_founder ON public.hospital_cross_sell_outreach_log_r1695;
CREATE POLICY p_cs_out_r1695_founder ON public.hospital_cross_sell_outreach_log_r1695
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_opportunities
CREATE OR REPLACE FUNCTION public.list_cross_sell_opportunities_r1695()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  current_state text,
  suggested_offer text,
  expected_arr_lift_rupees bigint,
  owner_email text,
  status text,
  last_outreach_at timestamptz,
  outreach_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id,
         o.hospital_user_id,
         p.email AS hospital_email,
         o.current_state,
         o.suggested_offer,
         o.expected_arr_lift_rupees,
         o.owner_email,
         o.status,
         o.last_outreach_at,
         (SELECT (COUNT(*))::int FROM public.hospital_cross_sell_outreach_log_r1695 l WHERE l.opportunity_id = o.id) AS outreach_count,
         o.created_at
  FROM public.hospital_cross_sell_opportunities_r1695 o
  LEFT JOIN public.profiles p ON p.id = o.hospital_user_id
  ORDER BY
    CASE o.status WHEN 'open' THEN 1 WHEN 'pitched' THEN 2 WHEN 'won' THEN 3 WHEN 'lost' THEN 4 ELSE 5 END,
    o.expected_arr_lift_rupees DESC,
    o.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cross_sell_opportunities_r1695() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cross_sell_opportunities_r1695() TO authenticated;

-- RPC 2: add_opportunity
CREATE OR REPLACE FUNCTION public.add_cross_sell_opportunity_r1695(
  p_hospital_user_id uuid,
  p_current_state text,
  p_suggested_offer text,
  p_expected_arr_lift_rupees bigint,
  p_owner_email text
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

  INSERT INTO public.hospital_cross_sell_opportunities_r1695(
    hospital_user_id, current_state, suggested_offer, expected_arr_lift_rupees, owner_email, status
  )
  VALUES (p_hospital_user_id, p_current_state, p_suggested_offer, COALESCE(p_expected_arr_lift_rupees, 0), p_owner_email, 'open')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_cross_sell_opportunity_r1695',
    jsonb_build_object('opportunity_id', v_id, 'hospital_user_id', p_hospital_user_id, 'arr_lift', p_expected_arr_lift_rupees));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_cross_sell_opportunity_r1695(uuid, text, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_cross_sell_opportunity_r1695(uuid, text, text, bigint, text) TO authenticated;

-- RPC 3: list_outreach
CREATE OR REPLACE FUNCTION public.list_cross_sell_outreach_r1695(p_opportunity_id uuid)
RETURNS TABLE (
  id uuid,
  opportunity_id uuid,
  outreach_type text,
  outreach_at timestamptz,
  by_email text,
  note text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.opportunity_id, l.outreach_type, l.outreach_at, l.by_email, l.note, l.outcome
  FROM public.hospital_cross_sell_outreach_log_r1695 l
  WHERE l.opportunity_id = p_opportunity_id
  ORDER BY l.outreach_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cross_sell_outreach_r1695(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cross_sell_outreach_r1695(uuid) TO authenticated;

-- RPC 4: log_outreach
CREATE OR REPLACE FUNCTION public.log_cross_sell_outreach_r1695(
  p_opportunity_id uuid,
  p_outreach_type text,
  p_note text,
  p_outcome text
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

  INSERT INTO public.hospital_cross_sell_outreach_log_r1695(opportunity_id, outreach_type, by_email, note, outcome)
  VALUES (p_opportunity_id, p_outreach_type, (auth.jwt()->>'email'), p_note, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.hospital_cross_sell_opportunities_r1695
  SET last_outreach_at = now(),
      status = CASE WHEN status = 'open' THEN 'pitched' ELSE status END,
      updated_at = now()
  WHERE id = p_opportunity_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cross_sell_outreach_r1695',
    jsonb_build_object('outreach_id', v_id, 'opportunity_id', p_opportunity_id, 'type', p_outreach_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_cross_sell_outreach_r1695(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_cross_sell_outreach_r1695(uuid, text, text, text) TO authenticated;

-- RPC 5: close_opportunity
CREATE OR REPLACE FUNCTION public.close_cross_sell_opportunity_r1695(
  p_opportunity_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('won','lost') THEN RAISE EXCEPTION 'status must be won or lost'; END IF;

  UPDATE public.hospital_cross_sell_opportunities_r1695
  SET status = p_status, updated_at = now()
  WHERE id = p_opportunity_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_cross_sell_opportunity_r1695',
    jsonb_build_object('opportunity_id', p_opportunity_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.close_cross_sell_opportunity_r1695(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_cross_sell_opportunity_r1695(uuid, text) TO authenticated;

-- RPC 6: total_arr_lift_pipeline
CREATE OR REPLACE FUNCTION public.total_cross_sell_arr_lift_pipeline_r1695()
RETURNS TABLE (
  status text,
  opp_count int,
  total_arr_lift_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.status,
         (COUNT(*))::int AS opp_count,
         COALESCE(SUM(o.expected_arr_lift_rupees), 0)::bigint AS total_arr_lift_rupees
  FROM public.hospital_cross_sell_opportunities_r1695 o
  GROUP BY o.status
  ORDER BY
    CASE o.status WHEN 'open' THEN 1 WHEN 'pitched' THEN 2 WHEN 'won' THEN 3 WHEN 'lost' THEN 4 ELSE 5 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.total_cross_sell_arr_lift_pipeline_r1695() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_cross_sell_arr_lift_pipeline_r1695() TO authenticated;

-- RPC 7: conversion_by_offer
CREATE OR REPLACE FUNCTION public.cross_sell_conversion_by_offer_r1695()
RETURNS TABLE (
  suggested_offer text,
  total_opps int,
  won_count int,
  lost_count int,
  open_count int,
  pitched_count int,
  win_rate_pct numeric,
  total_arr_won_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.suggested_offer,
         (COUNT(*))::int AS total_opps,
         (COUNT(*) FILTER (WHERE o.status = 'won'))::int AS won_count,
         (COUNT(*) FILTER (WHERE o.status = 'lost'))::int AS lost_count,
         (COUNT(*) FILTER (WHERE o.status = 'open'))::int AS open_count,
         (COUNT(*) FILTER (WHERE o.status = 'pitched'))::int AS pitched_count,
         ROUND(
           (COUNT(*) FILTER (WHERE o.status = 'won'))::numeric
           / NULLIF((COUNT(*) FILTER (WHERE o.status IN ('won','lost')))::numeric, 0)
           * 100, 2
         ) AS win_rate_pct,
         COALESCE(SUM(o.expected_arr_lift_rupees) FILTER (WHERE o.status = 'won'), 0)::bigint AS total_arr_won_rupees
  FROM public.hospital_cross_sell_opportunities_r1695 o
  GROUP BY o.suggested_offer
  ORDER BY total_opps DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cross_sell_conversion_by_offer_r1695() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cross_sell_conversion_by_offer_r1695() TO authenticated;

COMMIT;