BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_loyalty_tiers_r1951 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('bronze','silver','gold','platinum','founder_circle')),
  lifetime_value_rupees bigint NOT NULL DEFAULT 0,
  jobs_completed int NOT NULL DEFAULT 0,
  current_streak_days int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lapsed','upgraded','excluded')),
  last_activity_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_loyalty_action_log_r1951 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id uuid NOT NULL REFERENCES public.hospital_loyalty_tiers_r1951(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('upgrade','downgrade','reward_sent','benefit_activated','communication_sent')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  benefit_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_loyalty_tiers_r1951 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_loyalty_action_log_r1951 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tiers_r1951 ON public.hospital_loyalty_tiers_r1951;
CREATE POLICY founder_all_tiers_r1951 ON public.hospital_loyalty_tiers_r1951
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r1951 ON public.hospital_loyalty_action_log_r1951;
CREATE POLICY founder_all_actions_r1951 ON public.hospital_loyalty_action_log_r1951
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_tiers_r1951()
RETURNS TABLE(id uuid, hospital_id uuid, tier text, lifetime_value_rupees bigint, jobs_completed int, current_streak_days int, status text, last_activity_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.hospital_id, t.tier, t.lifetime_value_rupees, t.jobs_completed, t.current_streak_days, t.status, t.last_activity_at, t.created_at
    FROM public.hospital_loyalty_tiers_r1951 t ORDER BY t.lifetime_value_rupees DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_tier_r1951(p_hospital_id uuid, p_tier text, p_ltv bigint, p_jobs int, p_streak int)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_loyalty_tiers_r1951(hospital_id, tier, lifetime_value_rupees, jobs_completed, current_streak_days, last_activity_at)
    VALUES (p_hospital_id, p_tier, p_ltv, p_jobs, p_streak, now()) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tier_r1951', jsonb_build_object('tier_id', v_id, 'hospital_id', p_hospital_id, 'tier', p_tier));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1951(p_tier_id uuid)
RETURNS TABLE(id uuid, tier_id uuid, action_type text, taken_at timestamptz, by_email text, benefit_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.tier_id, a.action_type, a.taken_at, a.by_email, a.benefit_md
    FROM public.hospital_loyalty_action_log_r1951 a WHERE a.tier_id = p_tier_id ORDER BY a.taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r1951(p_tier_id uuid, p_action_type text, p_benefit_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_loyalty_action_log_r1951(tier_id, action_type, by_email, benefit_md)
    VALUES (p_tier_id, p_action_type, (auth.jwt()->>'email'), p_benefit_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1951', jsonb_build_object('action_id', v_id, 'tier_id', p_tier_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1951(p_tier_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_loyalty_tiers_r1951 SET status = p_status, updated_at = now() WHERE id = p_tier_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1951', jsonb_build_object('tier_id', p_tier_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.top_tier_hospitals_r1951()
RETURNS TABLE(id uuid, hospital_id uuid, tier text, lifetime_value_rupees bigint, jobs_completed int, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.hospital_id, t.tier, t.lifetime_value_rupees, t.jobs_completed, t.status
    FROM public.hospital_loyalty_tiers_r1951 t WHERE t.tier IN ('platinum','founder_circle') AND t.status = 'active'
    ORDER BY t.lifetime_value_rupees DESC LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1951()
RETURNS TABLE(id uuid, tier_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.tier_id, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_loyalty_action_log_r1951 a ORDER BY a.taken_at DESC LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_tiers_r1951() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tier_r1951(uuid, text, bigint, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1951(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1951(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1951(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_tier_hospitals_r1951() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1951() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tiers_r1951() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tier_r1951(uuid, text, bigint, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1951(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1951(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1951(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_tier_hospitals_r1951() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1951() TO authenticated;

COMMIT;
