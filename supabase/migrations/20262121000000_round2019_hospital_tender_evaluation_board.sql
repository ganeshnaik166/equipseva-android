BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_tender_evaluation_r2019 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tender_label text NOT NULL,
  tender_value_rupees bigint NOT NULL DEFAULT 0,
  submitted_date date,
  evaluation_status text NOT NULL DEFAULT 'evaluating' CHECK (evaluation_status IN ('evaluating','won','lost','declined_to_bid','disqualified')),
  won_at timestamptz,
  value_lost_rupees bigint NOT NULL DEFAULT 0,
  competition_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_tender_action_log_r2019 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_id uuid NOT NULL REFERENCES public.hospital_tender_evaluation_r2019(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('evaluated','bid_submitted','won','lost','declined','lessons_learned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_tender_evaluation_r2019 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_tender_action_log_r2019 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tender_eval_r2019 ON public.hospital_tender_evaluation_r2019;
CREATE POLICY founder_all_tender_eval_r2019 ON public.hospital_tender_evaluation_r2019
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_tender_action_r2019 ON public.hospital_tender_action_log_r2019;
CREATE POLICY founder_all_tender_action_r2019 ON public.hospital_tender_action_log_r2019
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_tenders
CREATE OR REPLACE FUNCTION public.list_tenders_r2019()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, tender_label text, tender_value_rupees bigint, submitted_date date, evaluation_status text, won_at timestamptz, value_lost_rupees bigint, competition_count int, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_id, p.full_name, t.tender_label, t.tender_value_rupees, t.submitted_date, t.evaluation_status, t.won_at, t.value_lost_rupees, t.competition_count, t.created_at
  FROM public.hospital_tender_evaluation_r2019 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  ORDER BY t.created_at DESC
  LIMIT 200;
END $$;

-- RPC 2: log_tender
CREATE OR REPLACE FUNCTION public.log_tender_r2019(
  p_hospital_id uuid,
  p_tender_label text,
  p_tender_value_rupees bigint,
  p_submitted_date date,
  p_competition_count int
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_tender_evaluation_r2019(hospital_id, tender_label, tender_value_rupees, submitted_date, competition_count)
  VALUES (p_hospital_id, p_tender_label, COALESCE(p_tender_value_rupees,0), p_submitted_date, COALESCE(p_competition_count,0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_tender_r2019', jsonb_build_object('tender_id', v_id, 'hospital_id', p_hospital_id, 'tender_label', p_tender_label));
  RETURN v_id;
END $$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2019(p_tender_id uuid)
RETURNS TABLE(id uuid, tender_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.tender_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_tender_action_log_r2019 a
  WHERE a.tender_id = p_tender_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_action_r2019(
  p_tender_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_tender_action_log_r2019(tender_id, action_type, by_email, notes_md)
  VALUES (p_tender_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2019', jsonb_build_object('action_id', v_id, 'tender_id', p_tender_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2019(
  p_tender_id uuid,
  p_status text,
  p_value_lost_rupees bigint
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_tender_evaluation_r2019
  SET evaluation_status = p_status,
      won_at = CASE WHEN p_status = 'won' THEN now() ELSE won_at END,
      value_lost_rupees = CASE WHEN p_status IN ('lost','disqualified') THEN COALESCE(p_value_lost_rupees, value_lost_rupees) ELSE value_lost_rupees END,
      updated_at = now()
  WHERE id = p_tender_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2019', jsonb_build_object('tender_id', p_tender_id, 'status', p_status));
END $$;

-- RPC 6: won_tenders
CREATE OR REPLACE FUNCTION public.won_tenders_r2019()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, tender_label text, tender_value_rupees bigint, won_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_id, p.full_name, t.tender_label, t.tender_value_rupees, t.won_at
  FROM public.hospital_tender_evaluation_r2019 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  WHERE t.evaluation_status = 'won'
  ORDER BY t.won_at DESC NULLS LAST
  LIMIT 100;
END $$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2019()
RETURNS TABLE(id uuid, tender_id uuid, tender_label text, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.tender_id, t.tender_label, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_tender_action_log_r2019 a
  LEFT JOIN public.hospital_tender_evaluation_r2019 t ON t.id = a.tender_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_tenders_r2019() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_tender_r2019(uuid, text, bigint, date, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2019(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2019(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2019(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.won_tenders_r2019() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2019() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tenders_r2019() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_tender_r2019(uuid, text, bigint, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2019(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2019(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2019(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.won_tenders_r2019() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2019() TO authenticated;

COMMIT;
