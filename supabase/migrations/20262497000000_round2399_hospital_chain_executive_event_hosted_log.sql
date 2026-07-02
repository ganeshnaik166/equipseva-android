BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_chain_exec_events_r2399 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_name text NOT NULL,
  event_type text NOT NULL DEFAULT 'conference' CHECK (event_type IN ('conference','training_day','executive_retreat','board_meeting','vendor_summit','clinical_review','town_hall','other')),
  event_date date NOT NULL,
  venue text,
  city text,
  attendees_count int,
  our_attendees text,
  our_role text NOT NULL DEFAULT 'attendee' CHECK (our_role IN ('attendee','sponsor','speaker','exhibitor','organizer_partner','observer')),
  agenda_summary text,
  key_learnings text,
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','reviewed','followups_open','closed','archived')),
  reviewed_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_chain_event_followups_r2399 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.founder_chain_exec_events_r2399(id) ON DELETE CASCADE,
  followup_type text NOT NULL CHECK (followup_type IN ('intro_request','proposal','demo','quote','site_visit','contract_review','training_invite','other')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date date,
  notes text,
  outcome text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_chain_exec_events_r2399 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_chain_event_followups_r2399 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_chain_exec_events_r2399 ON public.founder_chain_exec_events_r2399;
CREATE POLICY founder_all_chain_exec_events_r2399 ON public.founder_chain_exec_events_r2399
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_chain_event_followups_r2399 ON public.founder_chain_event_followups_r2399;
CREATE POLICY founder_all_chain_event_followups_r2399 ON public.founder_chain_event_followups_r2399
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_chain_exec_events_r2399_chain ON public.founder_chain_exec_events_r2399(chain_user_id);
CREATE INDEX IF NOT EXISTS idx_chain_exec_events_r2399_date ON public.founder_chain_exec_events_r2399(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_chain_exec_events_r2399_status ON public.founder_chain_exec_events_r2399(status);
CREATE INDEX IF NOT EXISTS idx_chain_event_followups_r2399_event ON public.founder_chain_event_followups_r2399(event_id);
CREATE INDEX IF NOT EXISTS idx_chain_event_followups_r2399_status ON public.founder_chain_event_followups_r2399(status);
CREATE INDEX IF NOT EXISTS idx_chain_event_followups_r2399_due ON public.founder_chain_event_followups_r2399(due_date);

DROP FUNCTION IF EXISTS public.list_chain_exec_events_r2399();
CREATE OR REPLACE FUNCTION public.list_chain_exec_events_r2399()
RETURNS TABLE (
  id uuid,
  chain_user_id uuid,
  event_name text,
  event_type text,
  event_date date,
  venue text,
  city text,
  attendees_count int,
  our_attendees text,
  our_role text,
  agenda_summary text,
  key_learnings text,
  status text,
  reviewed_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.chain_user_id, e.event_name, e.event_type, e.event_date,
         e.venue, e.city, e.attendees_count, e.our_attendees, e.our_role,
         e.agenda_summary, e.key_learnings, e.status, e.reviewed_at,
         e.closed_at, e.created_at
  FROM public.founder_chain_exec_events_r2399 e
  ORDER BY e.event_date DESC, e.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_chain_exec_event_r2399(uuid, text, text, date, text, text, int, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_chain_exec_event_r2399(
  p_chain_user_id uuid,
  p_event_name text,
  p_event_type text,
  p_event_date date,
  p_venue text,
  p_city text,
  p_attendees_count int,
  p_our_attendees text,
  p_our_role text,
  p_agenda_summary text,
  p_key_learnings text
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
  INSERT INTO public.founder_chain_exec_events_r2399(
    chain_user_id, event_name, event_type, event_date, venue, city,
    attendees_count, our_attendees, our_role, agenda_summary, key_learnings, status
  ) VALUES (
    p_chain_user_id, p_event_name, p_event_type, p_event_date, p_venue, p_city,
    p_attendees_count, p_our_attendees, p_our_role, p_agenda_summary, p_key_learnings, 'logged'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_chain_exec_event_r2399',
    jsonb_build_object('id', v_id, 'chain_user_id', p_chain_user_id, 'event_name', p_event_name, 'event_date', p_event_date));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_chain_event_reviewed_r2399(uuid);
CREATE OR REPLACE FUNCTION public.mark_chain_event_reviewed_r2399(p_event_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_chain_exec_events_r2399
     SET status = CASE WHEN status = 'logged' THEN 'reviewed' ELSE status END,
         reviewed_at = COALESCE(reviewed_at, now()),
         updated_at = now()
   WHERE id = p_event_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_chain_event_reviewed_r2399',
    jsonb_build_object('id', p_event_id));

  RETURN p_event_id;
END;
$$;

DROP FUNCTION IF EXISTS public.close_chain_event_r2399(uuid);
CREATE OR REPLACE FUNCTION public.close_chain_event_r2399(p_event_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_chain_exec_events_r2399
     SET status = 'closed',
         closed_at = COALESCE(closed_at, now()),
         updated_at = now()
   WHERE id = p_event_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_chain_event_r2399',
    jsonb_build_object('id', p_event_id));

  RETURN p_event_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_chain_event_followups_r2399(uuid);
CREATE OR REPLACE FUNCTION public.list_chain_event_followups_r2399(p_event_id uuid)
RETURNS TABLE (
  id uuid,
  event_id uuid,
  followup_type text,
  owner_user_id uuid,
  due_date date,
  notes text,
  outcome text,
  status text,
  closed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.event_id, f.followup_type, f.owner_user_id, f.due_date,
         f.notes, f.outcome, f.status, f.closed_at, f.created_at
  FROM public.founder_chain_event_followups_r2399 f
  WHERE f.event_id = p_event_id
  ORDER BY (f.status = 'done') ASC, f.due_date ASC NULLS LAST, f.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.add_chain_event_followup_r2399(uuid, text, uuid, date, text);
CREATE OR REPLACE FUNCTION public.add_chain_event_followup_r2399(
  p_event_id uuid,
  p_followup_type text,
  p_owner_user_id uuid,
  p_due_date date,
  p_notes text
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
  INSERT INTO public.founder_chain_event_followups_r2399(
    event_id, followup_type, owner_user_id, due_date, notes, status
  ) VALUES (
    p_event_id, p_followup_type, p_owner_user_id, p_due_date, p_notes, 'open'
  )
  RETURNING id INTO v_id;

  UPDATE public.founder_chain_exec_events_r2399
     SET status = CASE WHEN status IN ('closed','archived') THEN status ELSE 'followups_open' END,
         updated_at = now()
   WHERE id = p_event_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_chain_event_followup_r2399',
    jsonb_build_object('id', v_id, 'event_id', p_event_id, 'followup_type', p_followup_type));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.chain_exec_event_rollup_r2399();
CREATE OR REPLACE FUNCTION public.chain_exec_event_rollup_r2399()
RETURNS TABLE (
  chain_user_id uuid,
  events_count int,
  last_event_date date,
  open_followups bigint,
  done_followups bigint,
  reviewed_count int,
  closed_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.chain_user_id,
         (COUNT(DISTINCT e.id))::int AS events_count,
         MAX(e.event_date) AS last_event_date,
         COALESCE(SUM(CASE WHEN f.status IN ('open','in_progress') THEN 1 ELSE 0 END), 0)::bigint AS open_followups,
         COALESCE(SUM(CASE WHEN f.status = 'done' THEN 1 ELSE 0 END), 0)::bigint AS done_followups,
         (COUNT(DISTINCT CASE WHEN e.status = 'reviewed' THEN e.id END))::int AS reviewed_count,
         (COUNT(DISTINCT CASE WHEN e.status = 'closed' THEN e.id END))::int AS closed_count
  FROM public.founder_chain_exec_events_r2399 e
  LEFT JOIN public.founder_chain_event_followups_r2399 f ON f.event_id = e.id
  GROUP BY e.chain_user_id
  ORDER BY last_event_date DESC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_exec_events_r2399() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_chain_exec_event_r2399(uuid, text, text, date, text, text, int, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_chain_event_reviewed_r2399(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_chain_event_r2399(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_event_followups_r2399(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_event_followup_r2399(uuid, text, uuid, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.chain_exec_event_rollup_r2399() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_exec_events_r2399() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_chain_exec_event_r2399(uuid, text, text, date, text, text, int, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_chain_event_reviewed_r2399(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_chain_event_r2399(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_event_followups_r2399(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_event_followup_r2399(uuid, text, uuid, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chain_exec_event_rollup_r2399() TO authenticated;

COMMIT;
