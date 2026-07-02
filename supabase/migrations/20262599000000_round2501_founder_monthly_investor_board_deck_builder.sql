-- Round 2501: founder-monthly-investor-board-deck-builder
-- Monthly investor board deck pipeline: section drafting -> review -> finalize, with anticipated questions tracking.

CREATE TABLE IF NOT EXISTS public.founder_board_deck_sections_r2501 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  section_kind text NOT NULL CHECK (section_kind IN ('business_metrics','financials','customers','team','risks','asks','strategy','competition')),
  draft_at timestamptz,
  reviewed_at timestamptz,
  finalized_at timestamptz,
  owner_email text NOT NULL,
  time_to_final_hours int,
  top_question_anticipated text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','finalized','sent')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_deck_questions_r2501 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_section_id uuid NOT NULL REFERENCES public.founder_board_deck_sections_r2501(id) ON DELETE CASCADE,
  question_text text NOT NULL,
  asked_by text NOT NULL,
  answer_owner_email text NOT NULL,
  answered_at timestamptz,
  answer_md text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','answered','escalated','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_board_deck_sections_r2501 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_deck_questions_r2501 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_board_deck_sections_r2501;
CREATE POLICY founder_all ON public.founder_board_deck_sections_r2501
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.board_deck_questions_r2501;
CREATE POLICY founder_all ON public.board_deck_questions_r2501
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.founder_board_deck_sections_r2501
  (month_label, section_kind, draft_at, reviewed_at, finalized_at, owner_email, time_to_final_hours, top_question_anticipated, status, notes)
VALUES
  ('2026-04', 'business_metrics', '2026-04-25 09:00:00+05:30'::timestamptz, '2026-04-26 14:00:00+05:30'::timestamptz, '2026-04-27 18:00:00+05:30'::timestamptz, 'founder@equipseva.in', 57, 'Why did MRR growth slow vs Q1?', 'sent', 'Finalized for April board meet'),
  ('2026-05', 'financials', '2026-05-24 10:00:00+05:30'::timestamptz, '2026-05-25 16:00:00+05:30'::timestamptz, '2026-05-26 20:00:00+05:30'::timestamptz, 'cfo@equipseva.in', 58, 'What is burn multiple this quarter?', 'finalized', 'Pending send to board'),
  ('2026-06', 'customers', '2026-06-18 11:00:00+05:30'::timestamptz, '2026-06-20 15:00:00+05:30'::timestamptz, NULL, 'founder@equipseva.in', NULL, 'Net revenue retention by hospital tier?', 'in_review', 'Reviewer pushed back on logo churn slide'),
  ('2026-06', 'risks', '2026-06-19 09:30:00+05:30'::timestamptz, NULL, NULL, 'founder@equipseva.in', NULL, 'How exposed are we to Cashfree KYC delays?', 'draft', 'Drafting payments + regulatory risk page'),
  ('2026-06', 'asks', NULL, NULL, NULL, 'founder@equipseva.in', NULL, 'Are intros to hospital chain CFOs available?', 'draft', 'Not yet started');

INSERT INTO public.board_deck_questions_r2501
  (deck_section_id, question_text, asked_by, answer_owner_email, answered_at, answer_md, status, notes)
SELECT id, 'Why did MRR growth slow vs Q1?', 'Lead Investor', 'founder@equipseva.in', '2026-04-27 17:00:00+05:30'::timestamptz, 'Q2 weighted by AMC migration; net new logos up 22%.', 'answered', 'Closed pre-meet'
FROM public.founder_board_deck_sections_r2501 WHERE month_label='2026-04' AND section_kind='business_metrics' LIMIT 1;

INSERT INTO public.board_deck_questions_r2501
  (deck_section_id, question_text, asked_by, answer_owner_email, answered_at, answer_md, status, notes)
SELECT id, 'What is burn multiple this quarter?', 'Board Chair', 'cfo@equipseva.in', '2026-05-26 19:00:00+05:30'::timestamptz, 'Burn multiple 1.4x; trending to 1.1x by Q4.', 'answered', 'Pre-emptive answer'
FROM public.founder_board_deck_sections_r2501 WHERE month_label='2026-05' AND section_kind='financials' LIMIT 1;

INSERT INTO public.board_deck_questions_r2501
  (deck_section_id, question_text, asked_by, answer_owner_email, answered_at, answer_md, status, notes)
SELECT id, 'Net revenue retention by hospital tier?', 'Lead Investor', 'founder@equipseva.in', NULL, NULL, 'open', 'Need to pull tier-segmented NRR'
FROM public.founder_board_deck_sections_r2501 WHERE month_label='2026-06' AND section_kind='customers' LIMIT 1;

INSERT INTO public.board_deck_questions_r2501
  (deck_section_id, question_text, asked_by, answer_owner_email, answered_at, answer_md, status, notes)
SELECT id, 'How exposed are we to Cashfree KYC delays?', 'Board Observer', 'founder@equipseva.in', NULL, NULL, 'escalated', 'Escalated to legal counsel'
FROM public.founder_board_deck_sections_r2501 WHERE month_label='2026-06' AND section_kind='risks' LIMIT 1;

INSERT INTO public.board_deck_questions_r2501
  (deck_section_id, question_text, asked_by, answer_owner_email, answered_at, answer_md, status, notes)
SELECT id, 'Why did churn spike in March?', 'Lead Investor', 'founder@equipseva.in', NULL, NULL, 'dropped', 'No longer relevant; April data resolves'
FROM public.founder_board_deck_sections_r2501 WHERE month_label='2026-04' AND section_kind='business_metrics' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_deck_sections_r2501()
RETURNS TABLE(id uuid, month_label text, section_kind text, owner_email text, status text, draft_at timestamptz, reviewed_at timestamptz, finalized_at timestamptz, time_to_final_hours int, top_question_anticipated text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.month_label, s.section_kind, s.owner_email, s.status,
           s.draft_at, s.reviewed_at, s.finalized_at, s.time_to_final_hours,
           s.top_question_anticipated, s.notes
    FROM public.founder_board_deck_sections_r2501 s
    ORDER BY s.month_label DESC, s.section_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_deck_sections_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deck_sections_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_questions_r2501()
RETURNS TABLE(id uuid, deck_section_id uuid, month_label text, section_kind text, question_text text, asked_by text, answer_owner_email text, answered_at timestamptz, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.id, q.deck_section_id, s.month_label, s.section_kind,
           q.question_text, q.asked_by, q.answer_owner_email, q.answered_at,
           q.status, q.notes
    FROM public.board_deck_questions_r2501 q
    JOIN public.founder_board_deck_sections_r2501 s ON s.id = q.deck_section_id
    ORDER BY s.month_label DESC, q.status ASC, q.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_questions_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_questions_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2501()
RETURNS TABLE(status text, section_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.status, COUNT(*)::bigint AS section_count
    FROM public.founder_board_deck_sections_r2501 s
    GROUP BY s.status
    ORDER BY section_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_open_questions_r2501()
RETURNS TABLE(id uuid, month_label text, section_kind text, question_text text, asked_by text, answer_owner_email text, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT q.id, s.month_label, s.section_kind, q.question_text, q.asked_by, q.answer_owner_email, q.status
    FROM public.board_deck_questions_r2501 q
    JOIN public.founder_board_deck_sections_r2501 s ON s.id = q.deck_section_id
    WHERE q.status IN ('open','escalated')
    ORDER BY q.status DESC, q.created_at ASC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_open_questions_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_open_questions_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_time_to_final_trend_r2501()
RETURNS TABLE(month_label text, avg_hours numeric, finalized_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.month_label,
           ROUND(AVG(s.time_to_final_hours)::numeric, 1) AS avg_hours,
           COUNT(*)::bigint AS finalized_count
    FROM public.founder_board_deck_sections_r2501 s
    WHERE s.time_to_final_hours IS NOT NULL
    GROUP BY s.month_label
    ORDER BY s.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_time_to_final_trend_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_time_to_final_trend_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.section_kind_breakdown_r2501()
RETURNS TABLE(section_kind text, total_sections bigint, finalized bigint, in_review bigint, draft bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_kind,
           COUNT(*)::bigint AS total_sections,
           COUNT(*) FILTER (WHERE s.status IN ('finalized','sent'))::bigint AS finalized,
           COUNT(*) FILTER (WHERE s.status = 'in_review')::bigint AS in_review,
           COUNT(*) FILTER (WHERE s.status = 'draft')::bigint AS draft
    FROM public.founder_board_deck_sections_r2501 s
    GROUP BY s.section_kind
    ORDER BY total_sections DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.section_kind_breakdown_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.section_kind_breakdown_r2501() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2501()
RETURNS TABLE(owner_email text, sections_owned bigint, open_questions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.owner_email,
           COUNT(DISTINCT s.id)::bigint AS sections_owned,
           COUNT(q.id) FILTER (WHERE q.status IN ('open','escalated'))::bigint AS open_questions
    FROM public.founder_board_deck_sections_r2501 s
    LEFT JOIN public.board_deck_questions_r2501 q ON q.deck_section_id = s.id
    GROUP BY s.owner_email
    ORDER BY sections_owned DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2501() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2501() TO authenticated;
