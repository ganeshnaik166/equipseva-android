BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_side_letter_watchdog_r1993 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  letter_label text NOT NULL,
  letter_summary_md text NOT NULL DEFAULT '',
  key_terms_md text NOT NULL DEFAULT '',
  signed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','escalated','disputed','superseded')),
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_side_letter_review_log_r1993 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  letter_id uuid NOT NULL REFERENCES public.investor_side_letter_watchdog_r1993(id) ON DELETE CASCADE,
  review_type text NOT NULL CHECK (review_type IN ('initial_review','quarterly','incident','escalation','superseded')),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL DEFAULT '',
  finding_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_side_letter_watchdog_r1993 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_side_letter_review_log_r1993 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1993_w ON public.investor_side_letter_watchdog_r1993;
CREATE POLICY founder_all_r1993_w ON public.investor_side_letter_watchdog_r1993
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1993_r ON public.investor_side_letter_review_log_r1993;
CREATE POLICY founder_all_r1993_r ON public.investor_side_letter_review_log_r1993
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_letters_r1993()
RETURNS TABLE(id uuid, investor_id uuid, letter_label text, letter_summary_md text, key_terms_md text, signed_at timestamptz, status text, last_reviewed_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT w.id, w.investor_id, w.letter_label, w.letter_summary_md, w.key_terms_md, w.signed_at, w.status, w.last_reviewed_at, w.created_at
  FROM public.investor_side_letter_watchdog_r1993 w
  ORDER BY w.signed_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_letter_r1993(p_investor_id uuid, p_label text, p_summary text, p_terms text, p_signed_at timestamptz)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letter_watchdog_r1993(investor_id, letter_label, letter_summary_md, key_terms_md, signed_at)
  VALUES (p_investor_id, p_label, COALESCE(p_summary,''), COALESCE(p_terms,''), COALESCE(p_signed_at, now()))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_letter_r1993', jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_label), now());
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_reviews_r1993(p_letter_id uuid)
RETURNS TABLE(id uuid, letter_id uuid, review_type text, reviewed_at timestamptz, by_email text, finding_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.letter_id, r.review_type, r.reviewed_at, r.by_email, r.finding_md
  FROM public.investor_side_letter_review_log_r1993 r
  WHERE r.letter_id = p_letter_id
  ORDER BY r.reviewed_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_review_r1993(p_letter_id uuid, p_review_type text, p_by_email text, p_finding text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letter_review_log_r1993(letter_id, review_type, by_email, finding_md)
  VALUES (p_letter_id, p_review_type, COALESCE(p_by_email,''), COALESCE(p_finding,''))
  RETURNING id INTO v_id;
  UPDATE public.investor_side_letter_watchdog_r1993 SET last_reviewed_at = now(), updated_at = now() WHERE id = p_letter_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_review_r1993', jsonb_build_object('id', v_id, 'letter_id', p_letter_id, 'review_type', p_review_type), now());
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1993(p_letter_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_side_letter_watchdog_r1993 SET status = p_status, updated_at = now() WHERE id = p_letter_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1993', jsonb_build_object('letter_id', p_letter_id, 'status', p_status), now());
END; $$;

CREATE OR REPLACE FUNCTION public.active_letters_r1993()
RETURNS TABLE(id uuid, investor_id uuid, letter_label text, signed_at timestamptz, status text, last_reviewed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT w.id, w.investor_id, w.letter_label, w.signed_at, w.status, w.last_reviewed_at
  FROM public.investor_side_letter_watchdog_r1993 w
  WHERE w.status IN ('active','under_review','escalated','disputed')
  ORDER BY w.signed_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_reviews_r1993(p_days integer)
RETURNS TABLE(id uuid, letter_id uuid, review_type text, reviewed_at timestamptz, by_email text, finding_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.letter_id, r.review_type, r.reviewed_at, r.by_email, r.finding_md
  FROM public.investor_side_letter_review_log_r1993 r
  WHERE r.reviewed_at >= now() - (COALESCE(p_days, 30) || ' days')::interval
  ORDER BY r.reviewed_at DESC;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_letters_r1993() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_letter_r1993(uuid, text, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1993(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_review_r1993(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1993(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_letters_r1993() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reviews_r1993(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_letters_r1993() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_letter_r1993(uuid, text, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1993(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_review_r1993(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1993(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_letters_r1993() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reviews_r1993(integer) TO authenticated;

COMMIT;
