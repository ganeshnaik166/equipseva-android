BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_strategic_bets_r1906 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_label text NOT NULL,
  bet_thesis_md text,
  bet_size text NOT NULL CHECK (bet_size IN ('small','medium','large','company_bet')),
  time_horizon_months int NOT NULL CHECK (time_horizon_months > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','winning','struggling','abandoned','won')),
  started_at timestamptz NOT NULL DEFAULT now(),
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_bet_assessments_r1906 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bets_r1906(id) ON DELETE CASCADE,
  assessment_type text NOT NULL CHECK (assessment_type IN ('weekly','monthly','quarterly','incident')),
  confidence_score int NOT NULL CHECK (confidence_score BETWEEN 0 AND 100),
  evidence_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bets_r1906_status ON public.founder_strategic_bets_r1906(status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_bet_assess_r1906_bet ON public.founder_bet_assessments_r1906(bet_id, recorded_at DESC);

ALTER TABLE public.founder_strategic_bets_r1906 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_bet_assessments_r1906 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_bets_r1906 ON public.founder_strategic_bets_r1906;
CREATE POLICY founder_all_bets_r1906 ON public.founder_strategic_bets_r1906
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_bet_assess_r1906 ON public.founder_bet_assessments_r1906;
CREATE POLICY founder_all_bet_assess_r1906 ON public.founder_bet_assessments_r1906
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_bets_r1906()
RETURNS TABLE(id uuid, bet_label text, bet_size text, time_horizon_months int, status text, started_at timestamptz, last_assessed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.bet_label, b.bet_size, b.time_horizon_months, b.status, b.started_at, b.last_assessed_at
  FROM public.founder_strategic_bets_r1906 b
  ORDER BY b.started_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_bet_r1906(p_label text, p_thesis text, p_size text, p_horizon int)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_strategic_bets_r1906(bet_label, bet_thesis_md, bet_size, time_horizon_months)
  VALUES (p_label, p_thesis, p_size, p_horizon)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_bet_r1906', jsonb_build_object('id', v_id, 'label', p_label, 'size', p_size));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_assessments_r1906(p_bet_id uuid)
RETURNS TABLE(id uuid, assessment_type text, confidence_score int, evidence_md text, recorded_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.assessment_type, a.confidence_score, a.evidence_md, a.recorded_at, a.by_email
  FROM public.founder_bet_assessments_r1906 a
  WHERE a.bet_id = p_bet_id
  ORDER BY a.recorded_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_assessment_r1906(p_bet_id uuid, p_type text, p_confidence int, p_evidence text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_bet_assessments_r1906(bet_id, assessment_type, confidence_score, evidence_md, by_email)
  VALUES (p_bet_id, p_type, p_confidence, p_evidence, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;
  UPDATE public.founder_strategic_bets_r1906 SET last_assessed_at = now(), updated_at = now() WHERE id = p_bet_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_assessment_r1906', jsonb_build_object('id', v_id, 'bet_id', p_bet_id, 'confidence', p_confidence));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1906(p_bet_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_strategic_bets_r1906 SET status = p_status, updated_at = now() WHERE id = p_bet_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1906', jsonb_build_object('bet_id', p_bet_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_bets_by_size_r1906()
RETURNS TABLE(bet_size text, total_bets int, active_count int, winning_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bet_size,
         COUNT(*)::int,
         (COUNT(*) FILTER (WHERE b.status = 'active'))::int,
         (COUNT(*) FILTER (WHERE b.status IN ('winning','won')))::int
  FROM public.founder_strategic_bets_r1906 b
  GROUP BY b.bet_size
  ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_assessments_r1906()
RETURNS TABLE(id uuid, bet_label text, assessment_type text, confidence_score int, recorded_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, b.bet_label, a.assessment_type, a.confidence_score, a.recorded_at, a.by_email
  FROM public.founder_bet_assessments_r1906 a
  JOIN public.founder_strategic_bets_r1906 b ON b.id = a.bet_id
  ORDER BY a.recorded_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_bets_r1906() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_bet_r1906(text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_assessments_r1906(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_assessment_r1906(uuid, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1906(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_bets_by_size_r1906() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_assessments_r1906() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_bets_r1906() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_bet_r1906(text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_assessments_r1906(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_assessment_r1906(uuid, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1906(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_bets_by_size_r1906() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_assessments_r1906() TO authenticated;

COMMIT;
