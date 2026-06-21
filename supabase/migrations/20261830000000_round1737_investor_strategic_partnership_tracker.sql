BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_strategic_partnerships_r1737 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  partner_org text NOT NULL,
  partnership_type text NOT NULL CHECK (partnership_type IN ('distribution','technology','customer_referral','co_marketing','joint_venture')),
  signed_date date,
  partnership_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'exploring' CHECK (status IN ('exploring','negotiating','signed','active','terminated')),
  terminated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_partnership_milestones_r1737 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_id uuid NOT NULL REFERENCES public.investor_strategic_partnerships_r1737(id) ON DELETE CASCADE,
  milestone_text text NOT NULL,
  due_date date,
  hit_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','hit','missed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_strategic_partnerships_r1737 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_partnership_milestones_r1737 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_partnerships_r1737 ON public.investor_strategic_partnerships_r1737;
CREATE POLICY founder_all_partnerships_r1737 ON public.investor_strategic_partnerships_r1737
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_milestones_r1737 ON public.investor_partnership_milestones_r1737;
CREATE POLICY founder_all_milestones_r1737 ON public.investor_partnership_milestones_r1737
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_partnerships_r1737()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  partner_org text,
  partnership_type text,
  signed_date date,
  partnership_value_rupees bigint,
  status text,
  terminated_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_id, prof.email, p.partner_org, p.partnership_type,
         p.signed_date, p.partnership_value_rupees, p.status, p.terminated_at, p.created_at
  FROM public.investor_strategic_partnerships_r1737 p
  LEFT JOIN public.profiles prof ON prof.id = p.investor_id
  ORDER BY p.created_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_partnership_r1737(
  p_investor_id uuid,
  p_partner_org text,
  p_partnership_type text,
  p_signed_date date,
  p_partnership_value_rupees bigint,
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
  INSERT INTO public.investor_strategic_partnerships_r1737 (
    investor_id, partner_org, partnership_type, signed_date,
    partnership_value_rupees, status
  ) VALUES (
    p_investor_id, p_partner_org, p_partnership_type, p_signed_date,
    COALESCE(p_partnership_value_rupees, 0), COALESCE(p_status, 'exploring')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_partnership_r1737',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'partner_org', p_partner_org));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_milestones_r1737(p_partnership_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  partnership_id uuid,
  partner_org text,
  milestone_text text,
  due_date date,
  hit_at timestamptz,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.partnership_id, p.partner_org, m.milestone_text, m.due_date,
         m.hit_at, m.status, m.created_at
  FROM public.investor_partnership_milestones_r1737 m
  LEFT JOIN public.investor_strategic_partnerships_r1737 p ON p.id = m.partnership_id
  WHERE p_partnership_id IS NULL OR m.partnership_id = p_partnership_id
  ORDER BY COALESCE(m.due_date, m.created_at::date) ASC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_milestone_r1737(
  p_partnership_id uuid,
  p_milestone_text text,
  p_due_date date
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
  INSERT INTO public.investor_partnership_milestones_r1737 (
    partnership_id, milestone_text, due_date, status
  ) VALUES (
    p_partnership_id, p_milestone_text, p_due_date, 'pending'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_milestone_r1737',
          jsonb_build_object('id', v_id, 'partnership_id', p_partnership_id, 'milestone', p_milestone_text));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.hit_milestone_r1737(p_milestone_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_partnership_milestones_r1737
  SET status = 'hit', hit_at = now(), updated_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hit_milestone_r1737',
          jsonb_build_object('milestone_id', p_milestone_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.partnership_value_summary_r1737()
RETURNS TABLE (
  total_partnerships int,
  active_partnerships int,
  signed_partnerships int,
  exploring_partnerships int,
  terminated_partnerships int,
  total_value_rupees bigint,
  active_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'active'))::int,
    (COUNT(*) FILTER (WHERE status = 'signed'))::int,
    (COUNT(*) FILTER (WHERE status = 'exploring'))::int,
    (COUNT(*) FILTER (WHERE status = 'terminated'))::int,
    COALESCE(SUM(partnership_value_rupees), 0)::bigint,
    COALESCE(SUM(partnership_value_rupees) FILTER (WHERE status IN ('active','signed')), 0)::bigint
  FROM public.investor_strategic_partnerships_r1737;
END;
$$;

CREATE OR REPLACE FUNCTION public.active_partnerships_per_investor_r1737()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  active_count int,
  total_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.investor_id,
    prof.email,
    (COUNT(*) FILTER (WHERE p.status IN ('active','signed')))::int,
    (COUNT(*))::int,
    COALESCE(SUM(p.partnership_value_rupees) FILTER (WHERE p.status IN ('active','signed')), 0)::bigint
  FROM public.investor_strategic_partnerships_r1737 p
  LEFT JOIN public.profiles prof ON prof.id = p.investor_id
  GROUP BY p.investor_id, prof.email
  ORDER BY (COUNT(*) FILTER (WHERE p.status IN ('active','signed'))) DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_partnerships_r1737() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_partnership_r1737(uuid, text, text, date, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r1737(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_milestone_r1737(uuid, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hit_milestone_r1737(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.partnership_value_summary_r1737() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_partnerships_per_investor_r1737() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_partnerships_r1737() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_partnership_r1737(uuid, text, text, date, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1737(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_milestone_r1737(uuid, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hit_milestone_r1737(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.partnership_value_summary_r1737() TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_partnerships_per_investor_r1737() TO authenticated;

COMMIT;