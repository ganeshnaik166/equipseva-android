BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_quarterly_reviews_r2351 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_code text NOT NULL,
  primary_contact_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  primary_contact_name text NOT NULL,
  primary_contact_email text NOT NULL,
  hospital_count int NOT NULL DEFAULT 1,
  amc_value_inr_lakhs numeric(12,2) NOT NULL DEFAULT 0,
  fiscal_quarter text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  meeting_mode text NOT NULL DEFAULT 'video' CHECK (meeting_mode IN ('video','onsite','hybrid','phone')),
  meeting_location text,
  agenda_template text NOT NULL DEFAULT 'standard' CHECK (agenda_template IN ('standard','renewal','expansion','escalation','strategic')),
  agenda_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','confirmed','completed','rescheduled','cancelled','no_show')),
  meeting_notes text,
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 10),
  renewal_signal text CHECK (renewal_signal IN ('strong','neutral','at_risk','churn_risk')),
  next_review_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_hcqr_r2351_scheduled ON public.hospital_chain_quarterly_reviews_r2351(scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_hcqr_r2351_chain ON public.hospital_chain_quarterly_reviews_r2351(chain_code);
CREATE INDEX IF NOT EXISTS idx_hcqr_r2351_status ON public.hospital_chain_quarterly_reviews_r2351(status);

ALTER TABLE public.hospital_chain_quarterly_reviews_r2351 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcqr_r2351 ON public.hospital_chain_quarterly_reviews_r2351;
CREATE POLICY founder_all_hcqr_r2351 ON public.hospital_chain_quarterly_reviews_r2351
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_chain_review_action_log_r2351 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.hospital_chain_quarterly_reviews_r2351(id) ON DELETE CASCADE,
  action_title text NOT NULL,
  action_description text,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_label text NOT NULL,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','blocked','done','cancelled')),
  due_at timestamptz,
  closed_at timestamptz,
  resolution_notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcral_r2351_review ON public.hospital_chain_review_action_log_r2351(review_id);
CREATE INDEX IF NOT EXISTS idx_hcral_r2351_status ON public.hospital_chain_review_action_log_r2351(status);
CREATE INDEX IF NOT EXISTS idx_hcral_r2351_due ON public.hospital_chain_review_action_log_r2351(due_at);

ALTER TABLE public.hospital_chain_review_action_log_r2351 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcral_r2351 ON public.hospital_chain_review_action_log_r2351;
CREATE POLICY founder_all_hcral_r2351 ON public.hospital_chain_review_action_log_r2351
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list upcoming reviews
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_list_upcoming();
CREATE FUNCTION public.founder_hcqr_r2351_list_upcoming()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_code text,
  primary_contact_name text,
  fiscal_quarter text,
  scheduled_at timestamptz,
  meeting_mode text,
  agenda_template text,
  status text,
  hospital_count int,
  amc_value_inr_lakhs numeric,
  open_actions bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.chain_code, r.primary_contact_name, r.fiscal_quarter,
         r.scheduled_at, r.meeting_mode, r.agenda_template, r.status,
         r.hospital_count, r.amc_value_inr_lakhs,
         COALESCE((SELECT count(*) FROM public.hospital_chain_review_action_log_r2351 a
                   WHERE a.review_id = r.id AND a.status IN ('open','in_progress','blocked')), 0)
  FROM public.hospital_chain_quarterly_reviews_r2351 r
  WHERE r.scheduled_at >= now() - interval '7 days'
  ORDER BY r.scheduled_at ASC;
END;
$$;

-- RPC 2: list completed reviews
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_list_completed();
CREATE FUNCTION public.founder_hcqr_r2351_list_completed()
RETURNS TABLE (
  id uuid,
  chain_name text,
  fiscal_quarter text,
  scheduled_at timestamptz,
  completed_at timestamptz,
  satisfaction_score int,
  renewal_signal text,
  next_review_at timestamptz,
  meeting_notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.fiscal_quarter, r.scheduled_at, r.completed_at,
         r.satisfaction_score, r.renewal_signal, r.next_review_at, r.meeting_notes
  FROM public.hospital_chain_quarterly_reviews_r2351 r
  WHERE r.status = 'completed'
  ORDER BY r.completed_at DESC NULLS LAST
  LIMIT 100;
END;
$$;

-- RPC 3: list action items
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_list_actions();
CREATE FUNCTION public.founder_hcqr_r2351_list_actions()
RETURNS TABLE (
  id uuid,
  review_id uuid,
  chain_name text,
  action_title text,
  owner_label text,
  priority text,
  status text,
  due_at timestamptz,
  days_overdue int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.review_id, r.chain_name, a.action_title, a.owner_label, a.priority, a.status, a.due_at,
         CASE WHEN a.due_at IS NOT NULL AND a.status IN ('open','in_progress','blocked')
              THEN GREATEST(0, EXTRACT(day FROM (now() - a.due_at))::int)
              ELSE 0 END
  FROM public.hospital_chain_review_action_log_r2351 a
  JOIN public.hospital_chain_quarterly_reviews_r2351 r ON r.id = a.review_id
  WHERE a.status IN ('open','in_progress','blocked')
  ORDER BY a.priority DESC, a.due_at ASC NULLS LAST
  LIMIT 200;
END;
$$;

-- RPC 4: schedule review
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_schedule(text, text, text, text, int, numeric, text, timestamptz, text, text);
CREATE FUNCTION public.founder_hcqr_r2351_schedule(
  p_chain_name text,
  p_chain_code text,
  p_contact_name text,
  p_contact_email text,
  p_hospital_count int,
  p_amc_value numeric,
  p_fiscal_quarter text,
  p_scheduled_at timestamptz,
  p_mode text,
  p_template text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_uid FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  INSERT INTO public.hospital_chain_quarterly_reviews_r2351
    (chain_name, chain_code, primary_contact_name, primary_contact_email,
     hospital_count, amc_value_inr_lakhs, fiscal_quarter, scheduled_at,
     meeting_mode, agenda_template, created_by)
  VALUES
    (p_chain_name, p_chain_code, p_contact_name, p_contact_email,
     COALESCE(p_hospital_count,1), COALESCE(p_amc_value,0), p_fiscal_quarter, p_scheduled_at,
     COALESCE(p_mode,'video'), COALESCE(p_template,'standard'), v_uid)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 5: complete review
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_complete(uuid, int, text, text, timestamptz);
CREATE FUNCTION public.founder_hcqr_r2351_complete(
  p_id uuid,
  p_satisfaction int,
  p_renewal_signal text,
  p_notes text,
  p_next_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_chain_quarterly_reviews_r2351
  SET status = 'completed',
      satisfaction_score = p_satisfaction,
      renewal_signal = p_renewal_signal,
      meeting_notes = p_notes,
      next_review_at = p_next_at,
      completed_at = now(),
      updated_at = now()
  WHERE id = p_id;
END;
$$;

-- RPC 6: add action
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_add_action(uuid, text, text, text, text, timestamptz);
CREATE FUNCTION public.founder_hcqr_r2351_add_action(
  p_review_id uuid,
  p_title text,
  p_description text,
  p_owner_label text,
  p_priority text,
  p_due_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_uid FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  INSERT INTO public.hospital_chain_review_action_log_r2351
    (review_id, action_title, action_description, owner_label, priority, due_at, created_by)
  VALUES (p_review_id, p_title, p_description, p_owner_label, COALESCE(p_priority,'medium'), p_due_at, v_uid)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 7: close action
DROP FUNCTION IF EXISTS public.founder_hcqr_r2351_close_action(uuid, text, text);
CREATE FUNCTION public.founder_hcqr_r2351_close_action(
  p_action_id uuid,
  p_status text,
  p_resolution text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_chain_review_action_log_r2351
  SET status = COALESCE(p_status,'done'),
      resolution_notes = p_resolution,
      closed_at = CASE WHEN p_status IN ('done','cancelled') THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_action_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_list_upcoming() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_list_completed() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_list_actions() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_schedule(text, text, text, text, int, numeric, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_complete(uuid, int, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_add_action(uuid, text, text, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hcqr_r2351_close_action(uuid, text, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_list_upcoming() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_list_completed() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_list_actions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_schedule(text, text, text, text, int, numeric, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_complete(uuid, int, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_add_action(uuid, text, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hcqr_r2351_close_action(uuid, text, text) TO authenticated;

COMMIT;
