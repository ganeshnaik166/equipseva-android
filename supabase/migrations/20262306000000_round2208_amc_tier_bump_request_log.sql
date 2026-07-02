BEGIN;

CREATE TABLE IF NOT EXISTS public.amc_tier_bump_requests_r2208 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_email text NOT NULL,
  current_tier text NOT NULL CHECK (current_tier IN ('standard','premium','elite')),
  requested_tier text NOT NULL CHECK (requested_tier IN ('standard','premium','elite')),
  monthly_delta_rupees int NOT NULL DEFAULT 0,
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','converted','expired')),
  approved_by_email text,
  approved_at timestamptz,
  converted_at timestamptz,
  requested_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.amc_tier_bump_events_r2208 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid REFERENCES public.amc_tier_bump_requests_r2208(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','reviewed','approved','rejected','converted','expired','note_added')),
  actor_email text,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.amc_tier_bump_requests_r2208 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amc_tier_bump_events_r2208 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.amc_tier_bump_requests_r2208;
CREATE POLICY founder_all ON public.amc_tier_bump_requests_r2208
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.amc_tier_bump_events_r2208;
CREATE POLICY founder_all ON public.amc_tier_bump_events_r2208
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tier_bump_requests_r2208()
RETURNS TABLE (
  id uuid,
  customer_email text,
  current_tier text,
  requested_tier text,
  monthly_delta_rupees int,
  status text,
  reason text,
  requested_at timestamptz,
  approved_at timestamptz,
  converted_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.customer_email, r.current_tier, r.requested_tier,
         r.monthly_delta_rupees, r.status, r.reason,
         r.requested_at, r.approved_at, r.converted_at
  FROM public.amc_tier_bump_requests_r2208 r
  ORDER BY r.requested_at DESC
  LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2208()
RETURNS TABLE (
  id uuid,
  event_type text,
  actor_email text,
  note text,
  occurred_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_type, e.actor_email, e.note, e.occurred_at
  FROM public.amc_tier_bump_events_r2208 e
  ORDER BY e.occurred_at DESC
  LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.top_tier_pair_r2208()
RETURNS TABLE (
  tier_pair text,
  request_count int,
  converted_count int,
  total_delta_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (r.current_tier || '->' || r.requested_tier) AS tier_pair,
         (COUNT(*))::int AS request_count,
         (COUNT(*) FILTER (WHERE r.status = 'converted'))::int AS converted_count,
         COALESCE(SUM(r.monthly_delta_rupees), 0)::bigint AS total_delta_rupees
  FROM public.amc_tier_bump_requests_r2208 r
  GROUP BY r.current_tier, r.requested_tier
  ORDER BY request_count DESC
  LIMIT 10;
END; $$;

CREATE OR REPLACE FUNCTION public.log_tier_bump_request_r2208(
  p_customer_email text,
  p_current_tier text,
  p_requested_tier text,
  p_monthly_delta_rupees int,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.amc_tier_bump_requests_r2208(
    customer_email, current_tier, requested_tier, monthly_delta_rupees, reason
  ) VALUES (
    p_customer_email, p_current_tier, p_requested_tier, p_monthly_delta_rupees, p_reason
  ) RETURNING id INTO v_id;

  INSERT INTO public.amc_tier_bump_events_r2208(request_id, event_type, actor_email, note)
  VALUES (v_id, 'created', (auth.jwt()->>'email'), 'request logged');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2208_log_request',
          jsonb_build_object('id', v_id, 'customer', p_customer_email,
                             'from', p_current_tier, 'to', p_requested_tier));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2208(
  p_request_id uuid,
  p_event_type text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.amc_tier_bump_events_r2208(request_id, event_type, actor_email, note)
  VALUES (p_request_id, p_event_type, (auth.jwt()->>'email'), p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2208_log_action',
          jsonb_build_object('event_id', v_id, 'request_id', p_request_id, 'type', p_event_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2208(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','approved','rejected','converted','expired') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE public.amc_tier_bump_requests_r2208
  SET status = p_status,
      approved_by_email = CASE WHEN p_status = 'approved' THEN (auth.jwt()->>'email') ELSE approved_by_email END,
      approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END,
      converted_at = CASE WHEN p_status = 'converted' THEN now() ELSE converted_at END
  WHERE id = p_id;

  INSERT INTO public.amc_tier_bump_events_r2208(request_id, event_type, actor_email, note)
  VALUES (p_id, p_status, (auth.jwt()->>'email'), 'status updated');

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2208_mark_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.aggregate_or_search_r2208()
RETURNS TABLE (
  total_requests int,
  pending_count int,
  approved_count int,
  converted_count int,
  rejected_count int,
  conversion_rate_pct numeric,
  total_monthly_delta_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_requests,
    (COUNT(*) FILTER (WHERE r.status = 'pending'))::int AS pending_count,
    (COUNT(*) FILTER (WHERE r.status = 'approved'))::int AS approved_count,
    (COUNT(*) FILTER (WHERE r.status = 'converted'))::int AS converted_count,
    (COUNT(*) FILTER (WHERE r.status = 'rejected'))::int AS rejected_count,
    CASE WHEN COUNT(*) > 0
         THEN ROUND((COUNT(*) FILTER (WHERE r.status = 'converted'))::numeric * 100 / COUNT(*), 2)
         ELSE 0 END AS conversion_rate_pct,
    COALESCE(SUM(r.monthly_delta_rupees) FILTER (WHERE r.status = 'converted'), 0)::bigint AS total_monthly_delta_rupees
  FROM public.amc_tier_bump_requests_r2208 r;
END; $$;

REVOKE ALL ON FUNCTION public.list_tier_bump_requests_r2208() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2208() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_tier_pair_r2208() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_tier_bump_request_r2208(text, text, text, int, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2208(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2208(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_or_search_r2208() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tier_bump_requests_r2208() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2208() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tier_pair_r2208() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tier_bump_request_r2208(text, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2208(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2208(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_or_search_r2208() TO authenticated;

COMMIT;
