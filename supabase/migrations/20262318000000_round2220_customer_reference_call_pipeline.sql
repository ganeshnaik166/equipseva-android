BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_reference_requests_r2220 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospect_org_name text NOT NULL,
  prospect_contact_name text NOT NULL,
  prospect_contact_email text NOT NULL,
  prospect_contact_phone text,
  deal_size_rupees bigint NOT NULL DEFAULT 0,
  deal_stage text NOT NULL DEFAULT 'qualified',
  reference_topic text NOT NULL,
  reference_org_pref text,
  status text NOT NULL DEFAULT 'requested',
  requested_at timestamptz NOT NULL DEFAULT now(),
  matched_at timestamptz,
  matched_reference_org text,
  matched_reference_contact text,
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_reference_calls_r2220 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES public.customer_reference_requests_r2220(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  completed_at timestamptz,
  duration_minutes int NOT NULL DEFAULT 0,
  call_outcome text NOT NULL DEFAULT 'scheduled',
  prospect_sentiment text,
  reference_sentiment text,
  conversion_impact text NOT NULL DEFAULT 'pending',
  closed_won_at timestamptz,
  closed_won_amount_rupees bigint NOT NULL DEFAULT 0,
  reference_thank_you_sent boolean NOT NULL DEFAULT false,
  call_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_reference_requests_r2220 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_reference_calls_r2220 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_reference_requests_r2220;
CREATE POLICY founder_all ON public.customer_reference_requests_r2220
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_reference_calls_r2220;
CREATE POLICY founder_all ON public.customer_reference_calls_r2220
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reference_requests_r2220()
RETURNS SETOF public.customer_reference_requests_r2220
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_reference_requests_r2220 ORDER BY requested_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_reference_r2220()
RETURNS TABLE(id bigint, op_name text, actor_email text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT fal.id, fal.op_name, fal.actor_email, fal.created_at
    FROM public.founder_action_log fal
    WHERE fal.op_name LIKE 'op_r2220%'
    ORDER BY fal.created_at DESC LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.top_reference_calls_r2220()
RETURNS SETOF public.customer_reference_calls_r2220
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_reference_calls_r2220
    ORDER BY closed_won_amount_rupees DESC, scheduled_at DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.log_reference_request_r2220(
  p_prospect_org text,
  p_prospect_contact text,
  p_prospect_email text,
  p_deal_size bigint,
  p_topic text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_reference_requests_r2220(
    prospect_org_name, prospect_contact_name, prospect_contact_email,
    deal_size_rupees, reference_topic, created_by
  ) VALUES (
    p_prospect_org, p_prospect_contact, p_prospect_email,
    p_deal_size, p_topic, auth.uid()
  ) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2220_log_request',
    jsonb_build_object('id', v_id, 'org', p_prospect_org));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_reference_call_r2220(
  p_request_id uuid,
  p_scheduled_at timestamptz
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_reference_calls_r2220(request_id, scheduled_at)
  VALUES (p_request_id, p_scheduled_at) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2220_log_call',
    jsonb_build_object('id', v_id, 'request_id', p_request_id));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_reference_request_r2220(
  p_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.customer_reference_requests_r2220
  SET status = p_status, matched_at = CASE WHEN p_status = 'matched' THEN now() ELSE matched_at END
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2220_mark_status',
    jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.aggregate_reference_pipeline_r2220()
RETURNS TABLE(
  total_requests int,
  matched_requests int,
  completed_calls int,
  closed_won_count int,
  closed_won_total_rupees bigint,
  avg_duration_minutes int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.customer_reference_requests_r2220)::int,
      (SELECT COUNT(*) FILTER (WHERE status = 'matched') FROM public.customer_reference_requests_r2220)::int,
      (SELECT COUNT(*) FILTER (WHERE call_outcome = 'completed') FROM public.customer_reference_calls_r2220)::int,
      (SELECT COUNT(*) FILTER (WHERE conversion_impact = 'closed_won') FROM public.customer_reference_calls_r2220)::int,
      (SELECT COALESCE(SUM(closed_won_amount_rupees), 0) FROM public.customer_reference_calls_r2220)::bigint,
      (SELECT COALESCE(AVG(duration_minutes), 0) FROM public.customer_reference_calls_r2220 WHERE duration_minutes > 0)::int;
END $$;

REVOKE ALL ON FUNCTION public.list_reference_requests_r2220() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_reference_r2220() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_reference_calls_r2220() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_reference_request_r2220(text, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_reference_call_r2220(uuid, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_reference_request_r2220(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_reference_pipeline_r2220() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reference_requests_r2220() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_reference_r2220() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_reference_calls_r2220() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reference_request_r2220(text, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_reference_call_r2220(uuid, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_reference_request_r2220(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_reference_pipeline_r2220() TO authenticated;

COMMIT;
