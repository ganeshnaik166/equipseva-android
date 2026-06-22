BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_tier_pricing_r2079 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_label text NOT NULL CHECK (tier_label IN ('basic','standard','premium','enterprise','custom')),
  base_monthly_price_rupees bigint NOT NULL DEFAULT 0,
  included_jobs_per_month int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','grandfathered')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_pricing_change_log_r2079 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id uuid REFERENCES public.hospital_service_tier_pricing_r2079(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('price_changed','tier_added','tier_retired','grandfathered','restored')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  price_change_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_tier_pricing_r2079 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_pricing_change_log_r2079 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_tier_r2079 ON public.hospital_service_tier_pricing_r2079;
CREATE POLICY p_tier_r2079 ON public.hospital_service_tier_pricing_r2079
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_log_r2079 ON public.hospital_pricing_change_log_r2079;
CREATE POLICY p_log_r2079 ON public.hospital_pricing_change_log_r2079
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tiers_r2079()
RETURNS SETOF public.hospital_service_tier_pricing_r2079
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_service_tier_pricing_r2079 ORDER BY captured_at DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_tier_r2079(
  p_tier_label text,
  p_base_monthly_price_rupees bigint,
  p_included_jobs_per_month int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_tier_pricing_r2079(tier_label, base_monthly_price_rupees, included_jobs_per_month, status)
  VALUES (p_tier_label, p_base_monthly_price_rupees, p_included_jobs_per_month, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tier_r2079', jsonb_build_object('id', v_id, 'tier_label', p_tier_label, 'price', p_base_monthly_price_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2079()
RETURNS SETOF public.hospital_pricing_change_log_r2079
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_pricing_change_log_r2079 ORDER BY taken_at DESC LIMIT 500;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2079(
  p_tier_id uuid,
  p_action_type text,
  p_by_email text,
  p_price_change_rupees bigint,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_pricing_change_log_r2079(tier_id, action_type, by_email, price_change_rupees, notes_md)
  VALUES (p_tier_id, p_action_type, p_by_email, p_price_change_rupees, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2079', jsonb_build_object('id', v_id, 'action_type', p_action_type, 'tier_id', p_tier_id));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2079(p_tier_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_tier_pricing_r2079 SET status = p_status, updated_at = now() WHERE id = p_tier_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2079', jsonb_build_object('id', p_tier_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.active_tiers_r2079()
RETURNS SETOF public.hospital_service_tier_pricing_r2079
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_service_tier_pricing_r2079 WHERE status = 'active' ORDER BY base_monthly_price_rupees ASC;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2079()
RETURNS SETOF public.hospital_pricing_change_log_r2079
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_pricing_change_log_r2079 WHERE taken_at >= now() - interval '30 days' ORDER BY taken_at DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_tiers_r2079() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tier_r2079(text, bigint, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2079() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2079(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2079(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_tiers_r2079() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2079() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tiers_r2079() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tier_r2079(text, bigint, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2079() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2079(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2079(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_tiers_r2079() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2079() TO authenticated;

COMMIT;
