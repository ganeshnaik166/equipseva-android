BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_anniversary_dates_r1725 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  first_check_date date NOT NULL,
  anniversary_month int NOT NULL CHECK (anniversary_month BETWEEN 1 AND 12),
  anniversary_day int NOT NULL CHECK (anniversary_day BETWEEN 1 AND 31),
  last_thanked_at timestamptz,
  total_invested_rupees bigint NOT NULL DEFAULT 0,
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_anniversary_outreach_log_r1725 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anniversary_id uuid NOT NULL REFERENCES public.investor_anniversary_dates_r1725(id) ON DELETE CASCADE,
  outreach_type text NOT NULL CHECK (outreach_type IN ('email','gift','personal_call','founder_dinner_invite')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response_received boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_anniversary_dates_r1725 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_anniversary_outreach_log_r1725 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_anniv_r1725 ON public.investor_anniversary_dates_r1725;
CREATE POLICY p_founder_all_anniv_r1725 ON public.investor_anniversary_dates_r1725
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_outreach_r1725 ON public.investor_anniversary_outreach_log_r1725;
CREATE POLICY p_founder_all_outreach_r1725 ON public.investor_anniversary_outreach_log_r1725
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_anniversaries_r1725()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  first_check_date date,
  anniversary_month int,
  anniversary_day int,
  last_thanked_at timestamptz,
  total_invested_rupees bigint,
  founder_note text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.investor_id, a.first_check_date, a.anniversary_month, a.anniversary_day,
           a.last_thanked_at, a.total_invested_rupees, a.founder_note, a.created_at
    FROM public.investor_anniversary_dates_r1725 a
    ORDER BY a.anniversary_month, a.anniversary_day;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_anniversary_r1725(
  p_investor_id uuid,
  p_first_check_date date,
  p_anniversary_month int,
  p_anniversary_day int,
  p_total_invested_rupees bigint,
  p_founder_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_anniversary_dates_r1725
    (investor_id, first_check_date, anniversary_month, anniversary_day, total_invested_rupees, founder_note)
  VALUES (p_investor_id, p_first_check_date, p_anniversary_month, p_anniversary_day, COALESCE(p_total_invested_rupees,0), p_founder_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_anniversary_r1725',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'month', p_anniversary_month, 'day', p_anniversary_day));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_outreach_r1725(p_anniversary_id uuid)
RETURNS TABLE (
  id uuid,
  anniversary_id uuid,
  outreach_type text,
  sent_at timestamptz,
  by_email text,
  response_received boolean,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.anniversary_id, o.outreach_type, o.sent_at, o.by_email, o.response_received, o.created_at
    FROM public.investor_anniversary_outreach_log_r1725 o
    WHERE p_anniversary_id IS NULL OR o.anniversary_id = p_anniversary_id
    ORDER BY o.sent_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_outreach_r1725(
  p_anniversary_id uuid,
  p_outreach_type text,
  p_by_email text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_outreach_type NOT IN ('email','gift','personal_call','founder_dinner_invite') THEN
    RAISE EXCEPTION 'bad_outreach_type';
  END IF;
  INSERT INTO public.investor_anniversary_outreach_log_r1725
    (anniversary_id, outreach_type, by_email)
  VALUES (p_anniversary_id, p_outreach_type, p_by_email)
  RETURNING id INTO v_id;

  UPDATE public.investor_anniversary_dates_r1725
    SET last_thanked_at = now(), updated_at = now()
    WHERE id = p_anniversary_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outreach_r1725',
          jsonb_build_object('id', v_id, 'anniversary_id', p_anniversary_id, 'type', p_outreach_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_response_r1725(p_outreach_id uuid, p_received boolean)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_anniversary_outreach_log_r1725
    SET response_received = COALESCE(p_received,false), updated_at = now()
    WHERE id = p_outreach_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_response_r1725',
          jsonb_build_object('outreach_id', p_outreach_id, 'received', p_received));
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.upcoming_anniversaries_this_month_r1725()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  anniversary_month int,
  anniversary_day int,
  total_invested_rupees bigint,
  last_thanked_at timestamptz,
  founder_note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.investor_id, a.anniversary_month, a.anniversary_day,
           a.total_invested_rupees, a.last_thanked_at, a.founder_note
    FROM public.investor_anniversary_dates_r1725 a
    WHERE a.anniversary_month = EXTRACT(MONTH FROM now())::int
    ORDER BY a.anniversary_day;
END;
$$;

CREATE OR REPLACE FUNCTION public.missed_anniversaries_r1725()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  anniversary_month int,
  anniversary_day int,
  last_thanked_at timestamptz,
  days_overdue int,
  founder_note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.investor_id, a.anniversary_month, a.anniversary_day, a.last_thanked_at,
           GREATEST(0, (EXTRACT(DAY FROM (now() - COALESCE(a.last_thanked_at, a.created_at))))::int - 365) AS days_overdue,
           a.founder_note
    FROM public.investor_anniversary_dates_r1725 a
    WHERE a.last_thanked_at IS NULL
       OR a.last_thanked_at < (now() - INTERVAL '365 days')
    ORDER BY a.last_thanked_at NULLS FIRST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_anniversaries_r1725() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_anniversary_r1725(uuid,date,int,int,bigint,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outreach_r1725(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outreach_r1725(uuid,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_response_r1725(uuid,boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_anniversaries_this_month_r1725() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.missed_anniversaries_r1725() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_anniversaries_r1725() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_anniversary_r1725(uuid,date,int,int,bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outreach_r1725(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outreach_r1725(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_response_r1725(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_anniversaries_this_month_r1725() TO authenticated;
GRANT EXECUTE ON FUNCTION public.missed_anniversaries_r1725() TO authenticated;

COMMIT;