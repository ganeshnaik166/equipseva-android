BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_newsletter_subscriptions_r2049 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  subscription_type text NOT NULL CHECK (subscription_type IN ('daily','weekly','monthly','quarterly','ad_hoc')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','unsubscribed','bounced')),
  last_sent_at timestamptz,
  subscribed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_subscription_action_log_r2049 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id uuid NOT NULL REFERENCES public.investor_newsletter_subscriptions_r2049(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('subscribed','sent','unsubscribed','paused','resubscribed','bounced')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_newsletter_subscriptions_r2049 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_subscription_action_log_r2049 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_subs_r2049 ON public.investor_newsletter_subscriptions_r2049;
CREATE POLICY founder_all_subs_r2049 ON public.investor_newsletter_subscriptions_r2049
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2049 ON public.investor_subscription_action_log_r2049;
CREATE POLICY founder_all_actions_r2049 ON public.investor_subscription_action_log_r2049
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_subscriptions_r2049()
RETURNS SETOF public.investor_newsletter_subscriptions_r2049
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_newsletter_subscriptions_r2049 ORDER BY subscribed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_subscription_r2049(
  p_investor_id uuid,
  p_subscription_type text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_newsletter_subscriptions_r2049 (investor_id, subscription_type, status)
  VALUES (p_investor_id, p_subscription_type, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_subscription_r2049',
    jsonb_build_object('subscription_id', v_id, 'investor_id', p_investor_id, 'subscription_type', p_subscription_type, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2049()
RETURNS SETOF public.investor_subscription_action_log_r2049
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_subscription_action_log_r2049 ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2049(
  p_subscription_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.investor_subscription_action_log_r2049 (subscription_id, action_type, by_email, notes_md)
  VALUES (p_subscription_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2049',
    jsonb_build_object('action_id', v_id, 'subscription_id', p_subscription_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2049(
  p_subscription_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_newsletter_subscriptions_r2049
  SET status = p_status, updated_at = now()
  WHERE id = p_subscription_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2049',
    jsonb_build_object('subscription_id', p_subscription_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_subscribers_r2049()
RETURNS SETOF public.investor_newsletter_subscriptions_r2049
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_newsletter_subscriptions_r2049
    WHERE status = 'active'
    ORDER BY subscribed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2049(p_limit int DEFAULT 50)
RETURNS SETOF public.investor_subscription_action_log_r2049
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_subscription_action_log_r2049
    ORDER BY taken_at DESC
    LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_subscriptions_r2049() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_subscription_r2049(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2049() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2049(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2049(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_subscribers_r2049() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2049(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_subscriptions_r2049() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_subscription_r2049(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2049() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2049(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2049(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_subscribers_r2049() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2049(int) TO authenticated;

COMMIT;
