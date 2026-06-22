BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.customer_renewal_nudges_r2200 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid,
  customer_user_id uuid REFERENCES public.profiles(id),
  customer_email text,
  customer_name text,
  amc_tier text,
  monthly_fee_rupees integer,
  expires_at timestamptz NOT NULL,
  days_to_expiry integer NOT NULL,
  bucket text NOT NULL CHECK (bucket IN ('d30','d60','d90')),
  nudge_status text NOT NULL DEFAULT 'queued' CHECK (nudge_status IN ('queued','sent','opened','responded','converted','declined','expired')),
  channel text CHECK (channel IN ('email','sms','whatsapp','call','in_app')),
  last_nudged_at timestamptz,
  nudge_count integer NOT NULL DEFAULT 0,
  converted_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_renewal_nudge_actions_r2200 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nudge_id uuid REFERENCES public.customer_renewal_nudges_r2200(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('queued','sent','opened','responded','converted','declined','expired','noted')),
  channel text,
  outcome text,
  notes text,
  actor_user_id uuid REFERENCES public.profiles(id),
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.customer_renewal_nudges_r2200 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_renewal_nudge_actions_r2200 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_nudges_r2200;
CREATE POLICY founder_all ON public.customer_renewal_nudges_r2200
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_nudge_actions_r2200;
CREATE POLICY founder_all ON public.customer_renewal_nudge_actions_r2200
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list nudges
CREATE OR REPLACE FUNCTION public.list_customer_renewal_nudges_r2200()
RETURNS TABLE (
  id uuid,
  customer_name text,
  customer_email text,
  amc_tier text,
  monthly_fee_rupees integer,
  expires_at timestamptz,
  days_to_expiry integer,
  bucket text,
  nudge_status text,
  channel text,
  last_nudged_at timestamptz,
  nudge_count integer,
  converted_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.customer_name, n.customer_email, n.amc_tier, n.monthly_fee_rupees,
         n.expires_at, n.days_to_expiry, n.bucket, n.nudge_status, n.channel,
         n.last_nudged_at, n.nudge_count, n.converted_at, n.created_at
  FROM public.customer_renewal_nudges_r2200 n
  ORDER BY n.days_to_expiry ASC, n.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: recent actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2200()
RETURNS TABLE (
  id uuid,
  nudge_id uuid,
  action_type text,
  channel text,
  outcome text,
  notes text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.nudge_id, a.action_type, a.channel, a.outcome, a.notes,
         a.actor_email, a.created_at
  FROM public.customer_renewal_nudge_actions_r2200 a
  ORDER BY a.created_at DESC
  LIMIT 100;
END;
$$;

-- RPC 3: top buckets
CREATE OR REPLACE FUNCTION public.top_bucket_r2200()
RETURNS TABLE (
  bucket text,
  total_queued integer,
  total_sent integer,
  total_converted integer,
  total_declined integer,
  avg_days_to_expiry numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.bucket,
         (COUNT(*) FILTER (WHERE n.nudge_status = 'queued'))::int AS total_queued,
         (COUNT(*) FILTER (WHERE n.nudge_status = 'sent'))::int AS total_sent,
         (COUNT(*) FILTER (WHERE n.nudge_status = 'converted'))::int AS total_converted,
         (COUNT(*) FILTER (WHERE n.nudge_status = 'declined'))::int AS total_declined,
         AVG(n.days_to_expiry)::numeric AS avg_days_to_expiry
  FROM public.customer_renewal_nudges_r2200 n
  GROUP BY n.bucket
  ORDER BY n.bucket ASC;
END;
$$;

-- RPC 4: log nudge
CREATE OR REPLACE FUNCTION public.log_customer_renewal_nudge_r2200(
  p_customer_name text,
  p_customer_email text,
  p_amc_tier text,
  p_monthly_fee_rupees integer,
  p_expires_at timestamptz,
  p_bucket text,
  p_channel text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_days int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_days := GREATEST(0, (EXTRACT(EPOCH FROM (p_expires_at - now())) / 86400)::int);
  INSERT INTO public.customer_renewal_nudges_r2200(
    customer_name, customer_email, amc_tier, monthly_fee_rupees,
    expires_at, days_to_expiry, bucket, channel, notes
  ) VALUES (
    p_customer_name, p_customer_email, p_amc_tier, p_monthly_fee_rupees,
    p_expires_at, v_days, p_bucket, p_channel, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2200_log_nudge',
    jsonb_build_object('nudge_id', v_id, 'bucket', p_bucket, 'email', p_customer_email));

  RETURN v_id;
END;
$$;

-- RPC 5: log action
CREATE OR REPLACE FUNCTION public.log_action_r2200(
  p_nudge_id uuid,
  p_action_type text,
  p_channel text,
  p_outcome text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.customer_renewal_nudge_actions_r2200(
    nudge_id, action_type, channel, outcome, notes, actor_user_id, actor_email
  ) VALUES (
    p_nudge_id, p_action_type, p_channel, p_outcome, p_notes,
    auth.uid(), (auth.jwt()->>'email')
  ) RETURNING id INTO v_id;

  UPDATE public.customer_renewal_nudges_r2200
  SET last_nudged_at = CASE WHEN p_action_type = 'sent' THEN now() ELSE last_nudged_at END,
      nudge_count = nudge_count + CASE WHEN p_action_type = 'sent' THEN 1 ELSE 0 END,
      updated_at = now()
  WHERE id = p_nudge_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2200_log_action',
    jsonb_build_object('action_id', v_id, 'nudge_id', p_nudge_id, 'type', p_action_type));

  RETURN v_id;
END;
$$;

-- RPC 6: mark status
CREATE OR REPLACE FUNCTION public.mark_status_r2200(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.customer_renewal_nudges_r2200
  SET nudge_status = p_status,
      converted_at = CASE WHEN p_status = 'converted' THEN now() ELSE converted_at END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2200_mark_status',
    jsonb_build_object('nudge_id', p_id, 'status', p_status));
END;
$$;

-- RPC 7: aggregate conversion funnel
CREATE OR REPLACE FUNCTION public.conversion_funnel_r2200()
RETURNS TABLE (
  total_nudges integer,
  total_sent integer,
  total_opened integer,
  total_responded integer,
  total_converted integer,
  total_declined integer,
  conversion_rate numeric,
  total_revenue_secured_rupees integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int AS total_nudges,
    (COUNT(*) FILTER (WHERE nudge_status IN ('sent','opened','responded','converted','declined')))::int AS total_sent,
    (COUNT(*) FILTER (WHERE nudge_status IN ('opened','responded','converted','declined')))::int AS total_opened,
    (COUNT(*) FILTER (WHERE nudge_status IN ('responded','converted','declined')))::int AS total_responded,
    (COUNT(*) FILTER (WHERE nudge_status = 'converted'))::int AS total_converted,
    (COUNT(*) FILTER (WHERE nudge_status = 'declined'))::int AS total_declined,
    CASE WHEN COUNT(*) > 0
         THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE nudge_status = 'converted'))::numeric / COUNT(*)::numeric, 2)
         ELSE 0 END AS conversion_rate,
    (COALESCE(SUM(monthly_fee_rupees) FILTER (WHERE nudge_status = 'converted'), 0) * 12)::int AS total_revenue_secured_rupees
  FROM public.customer_renewal_nudges_r2200;
END;
$$;

-- Grants
REVOKE ALL ON FUNCTION public.list_customer_renewal_nudges_r2200() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2200() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_bucket_r2200() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_customer_renewal_nudge_r2200(text,text,text,integer,timestamptz,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2200(uuid,text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2200(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.conversion_funnel_r2200() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_customer_renewal_nudges_r2200() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2200() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_bucket_r2200() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_customer_renewal_nudge_r2200(text,text,text,integer,timestamptz,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2200(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2200(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.conversion_funnel_r2200() TO authenticated;

COMMIT;
