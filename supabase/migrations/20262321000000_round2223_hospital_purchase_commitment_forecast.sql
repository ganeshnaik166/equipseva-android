BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_purchase_commitments_r2223 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  commitment_type text NOT NULL CHECK (commitment_type IN ('buyback','upgrade','new_purchase','amc_renewal')),
  equipment_category text NOT NULL,
  equipment_description text,
  expected_value_rupees bigint NOT NULL CHECK (expected_value_rupees >= 0),
  expected_close_month date NOT NULL,
  confidence text NOT NULL CHECK (confidence IN ('committed','high','medium','low','exploratory')),
  probability_pct int NOT NULL DEFAULT 50 CHECK (probability_pct BETWEEN 0 AND 100),
  decision_maker_name text,
  decision_maker_role text,
  budget_approval_status text NOT NULL DEFAULT 'pending' CHECK (budget_approval_status IN ('approved','pending','blocked','tentative')),
  last_contact_at timestamptz,
  next_followup_at timestamptz,
  notes text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','won','lost','deferred','cancelled')),
  recorded_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_purchase_commitment_events_r2223 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  commitment_id uuid NOT NULL REFERENCES public.hospital_purchase_commitments_r2223(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','updated','confidence_changed','value_changed','status_changed','contact_made','note_added')),
  prior_value jsonb,
  new_value jsonb,
  event_note text,
  actor_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_purchase_commitments_r2223 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_purchase_commitment_events_r2223 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.hospital_purchase_commitments_r2223
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE POLICY founder_all ON public.hospital_purchase_commitment_events_r2223
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_hospital_purchase_commitments_r2223(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  commitment_type text,
  equipment_category text,
  expected_value_rupees bigint,
  expected_close_month date,
  confidence text,
  probability_pct int,
  budget_approval_status text,
  status text,
  next_followup_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_name, c.commitment_type, c.equipment_category,
         c.expected_value_rupees, c.expected_close_month, c.confidence,
         c.probability_pct, c.budget_approval_status, c.status,
         c.next_followup_at, c.created_at
  FROM public.hospital_purchase_commitments_r2223 c
  WHERE c.expected_close_month <= (CURRENT_DATE + INTERVAL '12 months')
  ORDER BY c.expected_close_month ASC, c.expected_value_rupees DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_hospital_purchase_commitments_r2223(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  commitment_id uuid,
  event_type text,
  event_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.commitment_id, e.event_type, e.event_note, e.created_at
  FROM public.hospital_purchase_commitment_events_r2223 e
  ORDER BY e.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_hospital_purchase_commitments_r2223(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  expected_value_rupees bigint,
  confidence text,
  probability_pct int,
  weighted_value_rupees bigint,
  expected_close_month date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_name, c.expected_value_rupees, c.confidence, c.probability_pct,
         ((c.expected_value_rupees * c.probability_pct) / 100)::bigint AS weighted_value_rupees,
         c.expected_close_month
  FROM public.hospital_purchase_commitments_r2223 c
  WHERE c.status = 'open'
  ORDER BY ((c.expected_value_rupees * c.probability_pct) / 100) DESC
  LIMIT GREATEST(1, LEAST(p_limit, 50));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_hospital_purchase_commitment_r2223(
  p_hospital_name text,
  p_commitment_type text,
  p_equipment_category text,
  p_expected_value_rupees bigint,
  p_expected_close_month date,
  p_confidence text,
  p_probability_pct int
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
  INSERT INTO public.hospital_purchase_commitments_r2223(
    hospital_name, commitment_type, equipment_category,
    expected_value_rupees, expected_close_month, confidence, probability_pct,
    recorded_by
  ) VALUES (
    p_hospital_name, p_commitment_type, p_equipment_category,
    p_expected_value_rupees, p_expected_close_month, p_confidence, p_probability_pct,
    auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.hospital_purchase_commitment_events_r2223(
    commitment_id, event_type, new_value, actor_user_id
  ) VALUES (
    v_id, 'created',
    jsonb_build_object('hospital_name', p_hospital_name, 'value', p_expected_value_rupees, 'confidence', p_confidence),
    auth.uid()
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2223_log_commitment',
    jsonb_build_object('id', v_id, 'hospital', p_hospital_name, 'value_rupees', p_expected_value_rupees));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_hospital_purchase_commitment_r2223(
  p_commitment_id uuid,
  p_event_type text,
  p_event_note text
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
  INSERT INTO public.hospital_purchase_commitment_events_r2223(
    commitment_id, event_type, event_note, actor_user_id
  ) VALUES (
    p_commitment_id, p_event_type, p_event_note, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2223_log_event',
    jsonb_build_object('commitment_id', p_commitment_id, 'event_type', p_event_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_hospital_purchase_commitment_r2223(
  p_commitment_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('open','won','lost','deferred','cancelled') THEN
    RAISE EXCEPTION 'invalid status: %', p_new_status;
  END IF;

  UPDATE public.hospital_purchase_commitments_r2223
  SET status = p_new_status, updated_at = now()
  WHERE id = p_commitment_id;

  INSERT INTO public.hospital_purchase_commitment_events_r2223(
    commitment_id, event_type, new_value, actor_user_id
  ) VALUES (
    p_commitment_id, 'status_changed', jsonb_build_object('status', p_new_status), auth.uid()
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2223_mark_status',
    jsonb_build_object('commitment_id', p_commitment_id, 'status', p_new_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_hospital_purchase_commitments_r2223()
RETURNS TABLE (
  total_commitments int,
  open_commitments int,
  won_commitments int,
  total_pipeline_rupees bigint,
  weighted_pipeline_rupees bigint,
  committed_pipeline_rupees bigint,
  high_confidence_rupees bigint,
  next_quarter_pipeline_rupees bigint,
  hospitals_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_commitments,
    (COUNT(*) FILTER (WHERE status = 'open'))::int AS open_commitments,
    (COUNT(*) FILTER (WHERE status = 'won'))::int AS won_commitments,
    COALESCE(SUM(expected_value_rupees) FILTER (WHERE status = 'open'), 0)::bigint AS total_pipeline_rupees,
    COALESCE(SUM((expected_value_rupees * probability_pct) / 100) FILTER (WHERE status = 'open'), 0)::bigint AS weighted_pipeline_rupees,
    COALESCE(SUM(expected_value_rupees) FILTER (WHERE status = 'open' AND confidence = 'committed'), 0)::bigint AS committed_pipeline_rupees,
    COALESCE(SUM(expected_value_rupees) FILTER (WHERE status = 'open' AND confidence IN ('committed','high')), 0)::bigint AS high_confidence_rupees,
    COALESCE(SUM(expected_value_rupees) FILTER (WHERE status = 'open' AND expected_close_month <= (CURRENT_DATE + INTERVAL '3 months')), 0)::bigint AS next_quarter_pipeline_rupees,
    (COUNT(DISTINCT hospital_name))::int AS hospitals_count
  FROM public.hospital_purchase_commitments_r2223;
END;
$$;

REVOKE ALL ON FUNCTION public.list_hospital_purchase_commitments_r2223(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_hospital_purchase_commitments_r2223(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_hospital_purchase_commitments_r2223(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_hospital_purchase_commitment_r2223(text, text, text, bigint, date, text, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_hospital_purchase_commitment_r2223(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_hospital_purchase_commitment_r2223(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_hospital_purchase_commitments_r2223() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_purchase_commitments_r2223(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_hospital_purchase_commitments_r2223(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_hospital_purchase_commitments_r2223(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hospital_purchase_commitment_r2223(text, text, text, bigint, date, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_hospital_purchase_commitment_r2223(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_hospital_purchase_commitment_r2223(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_hospital_purchase_commitments_r2223() TO authenticated;

COMMIT;
