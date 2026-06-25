BEGIN;

-- ============================================================
-- Round 2682 — Engineer Monthly Customer Net Promoter Individual
-- Tables: engineer_customer_nps_scores_r2682, engineer_customer_nps_actions_r2682
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_customer_nps_scores_r2682 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  customer_name text NOT NULL,
  customer_org text NOT NULL,
  nps_score integer NOT NULL CHECK (nps_score BETWEEN 0 AND 10),
  nps_bucket text NOT NULL CHECK (nps_bucket IN ('promoter','passive','detractor')),
  verbatim_quote text NOT NULL,
  theme text NOT NULL CHECK (theme IN ('punctuality','communication','technical_skill','attitude','followup','pricing')),
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  job_count integer NOT NULL CHECK (job_count >= 0),
  response_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_nps_scores_r2682 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_nps_scores_r2682;
CREATE POLICY founder_all ON public.engineer_customer_nps_scores_r2682
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_customer_nps_actions_r2682 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  action_title text NOT NULL,
  action_owner text NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('coaching','recognition','retraining','reassignment','recovery_call','no_action')),
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  status text NOT NULL CHECK (status IN ('open','in_progress','done','skipped')),
  due_at timestamptz NOT NULL,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_nps_actions_r2682 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_customer_nps_actions_r2682;
CREATE POLICY founder_all ON public.engineer_customer_nps_actions_r2682
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed scores
INSERT INTO public.engineer_customer_nps_scores_r2682
  (month_label, engineer_name, engineer_code, customer_name, customer_org, nps_score, nps_bucket, verbatim_quote, theme, sentiment, job_count, response_at)
VALUES
  ('2026-06','Ravi Kumar','ENG-RK-014','Dr Anita Desai','Apollo Jubilee Hills',10,'promoter','Arrived 10 min early and fixed the ventilator coupling without disturbing the night shift.','punctuality','positive',3, now() - interval '2 days'),
  ('2026-06','Ravi Kumar','ENG-RK-014','Mr Suresh Iyer','Yashoda Secunderabad',9,'promoter','Explained the spare-part substitution clearly. Saved us a re-call.','communication','positive',2, now() - interval '4 days'),
  ('2026-06','Pooja Nair','ENG-PN-022','Dr Vikram Rao','KIMS Kondapur',7,'passive','Job was done but the follow-up SMS never landed.','followup','neutral',1, now() - interval '6 days'),
  ('2026-06','Pooja Nair','ENG-PN-022','Mrs Latha Reddy','Care Banjara',6,'passive','Technically fine but quoted higher than the previous engineer.','pricing','neutral',1, now() - interval '7 days'),
  ('2026-06','Arjun Mehta','ENG-AM-031','Dr Prakash Joshi','Rainbow Hyderguda',3,'detractor','Showed up two hours late and was rude to the ICU nurse.','attitude','negative',1, now() - interval '8 days'),
  ('2026-06','Arjun Mehta','ENG-AM-031','Mrs Geeta Sharma','Continental Gachibowli',2,'detractor','Could not diagnose the autoclave fault and left without escalating.','technical_skill','negative',1, now() - interval '9 days'),
  ('2026-06','Kavita Singh','ENG-KS-008','Dr Rohan Gupta','Sunshine Begumpet',10,'promoter','Best engineer we have had. Trained two of our biomeds for free.','technical_skill','positive',4, now() - interval '3 days');

-- Seed actions
INSERT INTO public.engineer_customer_nps_actions_r2682
  (month_label, engineer_name, action_title, action_owner, action_kind, priority, status, due_at, notes)
VALUES
  ('2026-06','Arjun Mehta','Mandatory attitude coaching session','Ops Lead Priya','coaching','p0','open', now() + interval '3 days','Two detractor responses in same month — block from ICU jobs until done'),
  ('2026-06','Arjun Mehta','Recovery call to Dr Prakash Joshi','Founder','recovery_call','p0','in_progress', now() + interval '1 day','CSAT save call before AMC renewal window closes'),
  ('2026-06','Pooja Nair','SMS follow-up workflow retraining','Training Lead','retraining','p2','open', now() + interval '7 days','Walk through the new auto-SMS template'),
  ('2026-06','Ravi Kumar','Engineer of the Month recognition','Founder','recognition','p1','done', now() - interval '1 day','Bonus credited and LinkedIn post drafted'),
  ('2026-06','Kavita Singh','Promote to Tier-2 lead engineer','Ops Lead Priya','recognition','p1','open', now() + interval '5 days','Two promoter quotes this month — fast-track tier review'),
  ('2026-06','Arjun Mehta','Reassign autoclave jobs until recertified','Dispatcher','reassignment','p1','in_progress', now() + interval '2 days','Route to Kavita Singh queue meanwhile');

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.engineer_customer_nps_kpis_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_kpis_r2682()
RETURNS TABLE(total_responses bigint, avg_nps numeric, promoter_count bigint, detractor_count bigint, nps_value numeric, engineers_covered bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    round(avg(nps_score)::numeric, 2),
    count(*) FILTER (WHERE nps_bucket = 'promoter')::bigint,
    count(*) FILTER (WHERE nps_bucket = 'detractor')::bigint,
    round((100.0 * (count(*) FILTER (WHERE nps_bucket = 'promoter') - count(*) FILTER (WHERE nps_bucket = 'detractor'))::numeric / NULLIF(count(*),0))::numeric, 1),
    count(DISTINCT engineer_code)::bigint
  FROM public.engineer_customer_nps_scores_r2682;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_kpis_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_kpis_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_per_engineer_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_per_engineer_r2682()
RETURNS TABLE(engineer_name text, engineer_code text, responses bigint, avg_score numeric, promoters bigint, detractors bigint, nps_value numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.engineer_code, count(*)::bigint,
    round(avg(s.nps_score)::numeric, 2),
    count(*) FILTER (WHERE s.nps_bucket = 'promoter')::bigint,
    count(*) FILTER (WHERE s.nps_bucket = 'detractor')::bigint,
    round((100.0 * (count(*) FILTER (WHERE s.nps_bucket = 'promoter') - count(*) FILTER (WHERE s.nps_bucket = 'detractor'))::numeric / NULLIF(count(*),0))::numeric, 1)
  FROM public.engineer_customer_nps_scores_r2682 s
  GROUP BY s.engineer_name, s.engineer_code
  ORDER BY avg(s.nps_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_per_engineer_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_per_engineer_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_recent_verbatims_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_recent_verbatims_r2682()
RETURNS TABLE(engineer_name text, customer_name text, customer_org text, nps_score integer, nps_bucket text, theme text, verbatim_quote text, response_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.customer_name, s.customer_org, s.nps_score, s.nps_bucket, s.theme, s.verbatim_quote, s.response_at
  FROM public.engineer_customer_nps_scores_r2682 s
  ORDER BY s.response_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_recent_verbatims_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_recent_verbatims_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_by_theme_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_by_theme_r2682()
RETURNS TABLE(theme text, mentions bigint, avg_score numeric, negative_share numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.theme, count(*)::bigint,
    round(avg(s.nps_score)::numeric, 2),
    round((100.0 * count(*) FILTER (WHERE s.sentiment = 'negative')::numeric / NULLIF(count(*),0))::numeric, 1)
  FROM public.engineer_customer_nps_scores_r2682 s
  GROUP BY s.theme
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_by_theme_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_by_theme_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_detractors_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_detractors_r2682()
RETURNS TABLE(engineer_name text, customer_name text, customer_org text, nps_score integer, theme text, verbatim_quote text, response_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.customer_name, s.customer_org, s.nps_score, s.theme, s.verbatim_quote, s.response_at
  FROM public.engineer_customer_nps_scores_r2682 s
  WHERE s.nps_bucket = 'detractor'
  ORDER BY s.response_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_detractors_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_detractors_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_open_actions_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_open_actions_r2682()
RETURNS TABLE(engineer_name text, action_title text, action_owner text, action_kind text, priority text, status text, due_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_name, a.action_title, a.action_owner, a.action_kind, a.priority, a.status, a.due_at
  FROM public.engineer_customer_nps_actions_r2682 a
  WHERE a.status IN ('open','in_progress')
  ORDER BY CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END, a.due_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_open_actions_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_open_actions_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_bucket_mix_r2682();
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_bucket_mix_r2682()
RETURNS TABLE(nps_bucket text, responses bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM public.engineer_customer_nps_scores_r2682;
  RETURN QUERY
  SELECT s.nps_bucket, count(*)::bigint,
    round((100.0 * count(*)::numeric / NULLIF(total,0))::numeric, 1)
  FROM public.engineer_customer_nps_scores_r2682 s
  GROUP BY s.nps_bucket
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_bucket_mix_r2682() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_bucket_mix_r2682() TO authenticated;

DROP FUNCTION IF EXISTS public.engineer_customer_nps_log_action_r2682(text, text, text, text, text, text, timestamptz, text);
CREATE OR REPLACE FUNCTION public.engineer_customer_nps_log_action_r2682(
  p_month_label text, p_engineer_name text, p_action_title text, p_action_owner text,
  p_action_kind text, p_priority text, p_due_at timestamptz, p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_nps_actions_r2682
    (month_label, engineer_name, action_title, action_owner, action_kind, priority, status, due_at, notes)
  VALUES (p_month_label, p_engineer_name, p_action_title, p_action_owner, p_action_kind, p_priority, 'open', p_due_at, p_notes)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_customer_nps_log_action_r2682(text, text, text, text, text, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_customer_nps_log_action_r2682(text, text, text, text, text, text, timestamptz, text) TO authenticated;

COMMIT;
