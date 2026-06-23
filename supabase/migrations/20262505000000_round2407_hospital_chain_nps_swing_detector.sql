BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_nps_quarters_r2407 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id),
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  quarter_start date NOT NULL,
  promoter_count int NOT NULL DEFAULT 0 CHECK (promoter_count >= 0),
  passive_count int NOT NULL DEFAULT 0 CHECK (passive_count >= 0),
  detractor_count int NOT NULL DEFAULT 0 CHECK (detractor_count >= 0),
  total_responses int NOT NULL DEFAULT 0 CHECK (total_responses >= 0),
  nps_score numeric(6,2) NOT NULL DEFAULT 0,
  nps_segment text NOT NULL CHECK (nps_segment IN ('promoter','passive','detractor')),
  arr_rupees bigint NOT NULL DEFAULT 0 CHECK (arr_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_user_id, quarter_start)
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_intervention_plans_r2407 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id),
  detected_quarter_start date NOT NULL,
  swing_kind text NOT NULL CHECK (swing_kind IN ('promoter_to_detractor','promoter_to_passive','passive_to_detractor','recovered')),
  prior_segment text NOT NULL CHECK (prior_segment IN ('promoter','passive','detractor')),
  current_segment text NOT NULL CHECK (current_segment IN ('promoter','passive','detractor')),
  nps_delta numeric(6,2) NOT NULL,
  arr_at_risk_rupees bigint NOT NULL DEFAULT 0 CHECK (arr_at_risk_rupees >= 0),
  intervention_owner_email text,
  intervention_plan text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','recovered','lost','snoozed')),
  due_at timestamptz,
  closed_at timestamptz,
  closed_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_nps_quarters_r2407 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_intervention_plans_r2407 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2407_q ON public.hospital_chain_nps_quarters_r2407;
CREATE POLICY founder_all_r2407_q ON public.hospital_chain_nps_quarters_r2407
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2407_plans ON public.hospital_chain_intervention_plans_r2407;
CREATE POLICY founder_all_r2407_plans ON public.hospital_chain_intervention_plans_r2407
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list quarters
CREATE OR REPLACE FUNCTION public.list_chain_nps_quarters_r2407()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  chain_name text,
  quarter_label text,
  quarter_start date,
  promoter_count int,
  passive_count int,
  detractor_count int,
  total_responses int,
  nps_score numeric,
  nps_segment text,
  arr_rupees bigint,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.id,
    q.hospital_user_id,
    p.email,
    q.chain_name,
    q.quarter_label,
    q.quarter_start,
    q.promoter_count,
    q.passive_count,
    q.detractor_count,
    q.total_responses,
    q.nps_score,
    q.nps_segment,
    q.arr_rupees,
    q.notes
  FROM public.hospital_chain_nps_quarters_r2407 q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  ORDER BY q.quarter_start DESC, q.chain_name ASC
  LIMIT 500;
END;
$$;

-- RPC 2: record quarter
CREATE OR REPLACE FUNCTION public.record_chain_nps_quarter_r2407(
  p_hospital_user_id uuid,
  p_chain_name text,
  p_quarter_label text,
  p_quarter_start date,
  p_promoter_count int,
  p_passive_count int,
  p_detractor_count int,
  p_arr_rupees bigint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_total int;
  v_score numeric;
  v_segment text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_total := COALESCE(p_promoter_count,0) + COALESCE(p_passive_count,0) + COALESCE(p_detractor_count,0);
  IF v_total = 0 THEN
    v_score := 0;
  ELSE
    v_score := ROUND(((p_promoter_count::numeric - p_detractor_count::numeric) / v_total::numeric) * 100, 2);
  END IF;
  v_segment := CASE
    WHEN v_score >= 50 THEN 'promoter'
    WHEN v_score >= 0 THEN 'passive'
    ELSE 'detractor'
  END;

  INSERT INTO public.hospital_chain_nps_quarters_r2407(
    hospital_user_id, chain_name, quarter_label, quarter_start,
    promoter_count, passive_count, detractor_count, total_responses,
    nps_score, nps_segment, arr_rupees, notes
  ) VALUES (
    p_hospital_user_id, p_chain_name, p_quarter_label, p_quarter_start,
    p_promoter_count, p_passive_count, p_detractor_count, v_total,
    v_score, v_segment, COALESCE(p_arr_rupees,0), p_notes
  )
  ON CONFLICT (hospital_user_id, quarter_start) DO UPDATE
    SET chain_name = EXCLUDED.chain_name,
        quarter_label = EXCLUDED.quarter_label,
        promoter_count = EXCLUDED.promoter_count,
        passive_count = EXCLUDED.passive_count,
        detractor_count = EXCLUDED.detractor_count,
        total_responses = EXCLUDED.total_responses,
        nps_score = EXCLUDED.nps_score,
        nps_segment = EXCLUDED.nps_segment,
        arr_rupees = EXCLUDED.arr_rupees,
        notes = EXCLUDED.notes,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2407_record_chain_nps_quarter',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'quarter_start', p_quarter_start, 'nps_score', v_score, 'segment', v_segment));
  RETURN v_id;
END;
$$;

-- RPC 3: detect swings (compares latest two quarters per hospital)
CREATE OR REPLACE FUNCTION public.detect_chain_nps_swings_r2407()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  chain_name text,
  prior_quarter_start date,
  prior_segment text,
  prior_nps numeric,
  current_quarter_start date,
  current_segment text,
  current_nps numeric,
  nps_delta numeric,
  swing_kind text,
  arr_at_risk_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ranked AS (
    SELECT
      q.hospital_user_id,
      q.chain_name,
      q.quarter_start,
      q.nps_score,
      q.nps_segment,
      q.arr_rupees,
      ROW_NUMBER() OVER (PARTITION BY q.hospital_user_id ORDER BY q.quarter_start DESC) AS rn
    FROM public.hospital_chain_nps_quarters_r2407 q
  ),
  pairs AS (
    SELECT
      cur.hospital_user_id,
      cur.chain_name,
      prv.quarter_start AS prior_quarter_start,
      prv.nps_segment AS prior_segment,
      prv.nps_score AS prior_nps,
      cur.quarter_start AS current_quarter_start,
      cur.nps_segment AS current_segment,
      cur.nps_score AS current_nps,
      (cur.nps_score - prv.nps_score) AS nps_delta,
      cur.arr_rupees AS arr_at_risk_rupees
    FROM ranked cur
    JOIN ranked prv
      ON cur.hospital_user_id = prv.hospital_user_id
     AND cur.rn = 1
     AND prv.rn = 2
  )
  SELECT
    pr.hospital_user_id,
    p.email,
    pr.chain_name,
    pr.prior_quarter_start,
    pr.prior_segment,
    pr.prior_nps,
    pr.current_quarter_start,
    pr.current_segment,
    pr.current_nps,
    pr.nps_delta,
    CASE
      WHEN pr.prior_segment = 'promoter' AND pr.current_segment = 'detractor' THEN 'promoter_to_detractor'
      WHEN pr.prior_segment = 'promoter' AND pr.current_segment = 'passive' THEN 'promoter_to_passive'
      WHEN pr.prior_segment = 'passive' AND pr.current_segment = 'detractor' THEN 'passive_to_detractor'
      WHEN pr.prior_segment IN ('detractor','passive') AND pr.current_segment = 'promoter' THEN 'recovered'
      ELSE 'no_swing'
    END AS swing_kind,
    pr.arr_at_risk_rupees
  FROM pairs pr
  LEFT JOIN public.profiles p ON p.id = pr.hospital_user_id
  WHERE pr.prior_segment <> pr.current_segment
  ORDER BY pr.nps_delta ASC, pr.arr_at_risk_rupees DESC
  LIMIT 500;
END;
$$;

-- RPC 4: open intervention
CREATE OR REPLACE FUNCTION public.open_chain_intervention_r2407(
  p_hospital_user_id uuid,
  p_detected_quarter_start date,
  p_swing_kind text,
  p_prior_segment text,
  p_current_segment text,
  p_nps_delta numeric,
  p_arr_at_risk_rupees bigint,
  p_intervention_owner_email text,
  p_intervention_plan text,
  p_due_at timestamptz
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
  IF p_swing_kind NOT IN ('promoter_to_detractor','promoter_to_passive','passive_to_detractor','recovered') THEN
    RAISE EXCEPTION 'invalid swing_kind';
  END IF;
  INSERT INTO public.hospital_chain_intervention_plans_r2407(
    hospital_user_id, detected_quarter_start, swing_kind, prior_segment, current_segment,
    nps_delta, arr_at_risk_rupees, intervention_owner_email, intervention_plan, due_at
  ) VALUES (
    p_hospital_user_id, p_detected_quarter_start, p_swing_kind, p_prior_segment, p_current_segment,
    p_nps_delta, COALESCE(p_arr_at_risk_rupees,0), p_intervention_owner_email, p_intervention_plan, p_due_at
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2407_open_chain_intervention',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'swing_kind', p_swing_kind, 'arr_at_risk_rupees', p_arr_at_risk_rupees));
  RETURN v_id;
END;
$$;

-- RPC 5: list interventions
CREATE OR REPLACE FUNCTION public.list_chain_interventions_r2407()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  detected_quarter_start date,
  swing_kind text,
  prior_segment text,
  current_segment text,
  nps_delta numeric,
  arr_at_risk_rupees bigint,
  intervention_owner_email text,
  intervention_plan text,
  status text,
  due_at timestamptz,
  closed_at timestamptz,
  closed_by_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pl.id,
    pl.hospital_user_id,
    p.email,
    pl.detected_quarter_start,
    pl.swing_kind,
    pl.prior_segment,
    pl.current_segment,
    pl.nps_delta,
    pl.arr_at_risk_rupees,
    pl.intervention_owner_email,
    pl.intervention_plan,
    pl.status,
    pl.due_at,
    pl.closed_at,
    pl.closed_by_email,
    pl.created_at
  FROM public.hospital_chain_intervention_plans_r2407 pl
  LEFT JOIN public.profiles p ON p.id = pl.hospital_user_id
  ORDER BY
    CASE pl.status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'snoozed' THEN 2 WHEN 'recovered' THEN 3 ELSE 4 END,
    pl.arr_at_risk_rupees DESC,
    pl.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC 6: close intervention
CREATE OR REPLACE FUNCTION public.close_chain_intervention_r2407(
  p_id uuid,
  p_new_status text,
  p_closed_by_email text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('in_progress','recovered','lost','snoozed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_chain_intervention_plans_r2407
    SET status = p_new_status,
        closed_at = CASE WHEN p_new_status IN ('recovered','lost') THEN now() ELSE closed_at END,
        closed_by_email = CASE WHEN p_new_status IN ('recovered','lost') THEN p_closed_by_email ELSE closed_by_email END,
        updated_at = now()
    WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2407_close_chain_intervention',
    jsonb_build_object('id', p_id, 'new_status', p_new_status));
END;
$$;

-- RPC 7: top ARR at risk (open + in_progress)
CREATE OR REPLACE FUNCTION public.top_chain_arr_at_risk_r2407()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  swing_kind text,
  nps_delta numeric,
  arr_at_risk_rupees bigint,
  intervention_owner_email text,
  due_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pl.id,
    pl.hospital_user_id,
    p.email,
    pl.swing_kind,
    pl.nps_delta,
    pl.arr_at_risk_rupees,
    pl.intervention_owner_email,
    pl.due_at,
    pl.status
  FROM public.hospital_chain_intervention_plans_r2407 pl
  LEFT JOIN public.profiles p ON p.id = pl.hospital_user_id
  WHERE pl.status IN ('open','in_progress')
  ORDER BY pl.arr_at_risk_rupees DESC, pl.nps_delta ASC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_nps_quarters_r2407() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_chain_nps_quarter_r2407(uuid, text, text, date, int, int, int, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.detect_chain_nps_swings_r2407() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_chain_intervention_r2407(uuid, date, text, text, text, numeric, bigint, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_interventions_r2407() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_chain_intervention_r2407(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_chain_arr_at_risk_r2407() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_nps_quarters_r2407() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_chain_nps_quarter_r2407(uuid, text, text, date, int, int, int, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.detect_chain_nps_swings_r2407() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_chain_intervention_r2407(uuid, date, text, text, text, numeric, bigint, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_interventions_r2407() TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_chain_intervention_r2407(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_chain_arr_at_risk_r2407() TO authenticated;

COMMIT;
