-- Round 2599: Hospital Chain C-Suite Language & Tone Tracker
-- Two tables tracking C-suite communication styles and adjustment actions.

CREATE TABLE IF NOT EXISTS public.chain_c_suite_communication_style_r2599 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  c_suite_role text NOT NULL CHECK (c_suite_role IN ('ceo','coo','cfo','cmo','cio','chief_medical_officer','owner')),
  communication_style_kind text NOT NULL CHECK (communication_style_kind IN ('direct','formal','relational','data_driven','visionary')),
  tone_preference_kind text NOT NULL CHECK (tone_preference_kind IN ('brief','detailed','numbers_first','story_first','diplomatic')),
  misalignment_risk_kind text NOT NULL CHECK (misalignment_risk_kind IN ('low','medium','high','critical')),
  adjustment_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'aligned' CHECK (status IN ('aligned','adjusting','in_review','strained')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_c_suite_communication_style_r2599 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_c_suite_communication_style_r2599;
CREATE POLICY founder_all ON public.chain_c_suite_communication_style_r2599
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.c_suite_tone_adjustment_actions_r2599 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  style_id uuid NOT NULL REFERENCES public.chain_c_suite_communication_style_r2599(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('rephrase','coach','swap_owner','email_template','deck_redesign')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.c_suite_tone_adjustment_actions_r2599 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.c_suite_tone_adjustment_actions_r2599;
CREATE POLICY founder_all ON public.c_suite_tone_adjustment_actions_r2599
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_c_suite_communication_style_r2599
  (chain_name, c_suite_role, communication_style_kind, tone_preference_kind, misalignment_risk_kind, adjustment_md, owner_email, status, notes)
VALUES
  ('Apollo North', 'ceo', 'direct', 'brief', 'medium', 'Keep updates under 3 bullets; lead with the ask.', 'founder@equipseva.in', 'adjusting', 'CEO cuts off long preambles'),
  ('Manipal South', 'cfo', 'data_driven', 'numbers_first', 'high', 'Always lead with ROI table; no anecdotes first.', 'cs@equipseva.in', 'in_review', 'CFO pushed back on last narrative deck'),
  ('Yashoda Group', 'coo', 'formal', 'detailed', 'low', 'Use formal salutation; full context in body.', 'ops@equipseva.in', 'aligned', 'Stable cadence'),
  ('Care Hospitals', 'cmo', 'relational', 'story_first', 'critical', 'Open with a patient story; numbers in appendix.', 'founder@equipseva.in', 'strained', 'Last review session went cold'),
  ('Continental Group', 'owner', 'visionary', 'diplomatic', 'medium', 'Tie every ask to 3-year vision; soft phrasing.', 'founder@equipseva.in', 'adjusting', 'Owner prefers vision framing');

INSERT INTO public.c_suite_tone_adjustment_actions_r2599
  (style_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'email_template', 'positive', 'founder@equipseva.in', 'done', 'Shipped 3-bullet template'
FROM public.chain_c_suite_communication_style_r2599 WHERE chain_name='Apollo North' LIMIT 1;

INSERT INTO public.c_suite_tone_adjustment_actions_r2599
  (style_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'deck_redesign', 'pending', 'cs@equipseva.in', 'open', 'ROI table moved to slide 1'
FROM public.chain_c_suite_communication_style_r2599 WHERE chain_name='Manipal South' LIMIT 1;

INSERT INTO public.c_suite_tone_adjustment_actions_r2599
  (style_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'coach', 'neutral', 'founder@equipseva.in', 'open', 'Coached AM on story framing'
FROM public.chain_c_suite_communication_style_r2599 WHERE chain_name='Care Hospitals' LIMIT 1;

INSERT INTO public.c_suite_tone_adjustment_actions_r2599
  (style_id, action_kind, outcome, owner_email, status, notes)
SELECT id, 'swap_owner', 'positive', 'founder@equipseva.in', 'done', 'Reassigned to senior AM'
FROM public.chain_c_suite_communication_style_r2599 WHERE chain_name='Continental Group' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_communication_style_r2599()
RETURNS TABLE (
  id uuid,
  chain_name text,
  c_suite_role text,
  communication_style_kind text,
  tone_preference_kind text,
  misalignment_risk_kind text,
  status text,
  owner_email text,
  adjustment_md text,
  notes text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.c_suite_role, s.communication_style_kind,
           s.tone_preference_kind, s.misalignment_risk_kind, s.status,
           s.owner_email, s.adjustment_md, s.notes, s.created_at
    FROM public.chain_c_suite_communication_style_r2599 s
    ORDER BY s.created_at DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_communication_style_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_communication_style_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_tone_adjustment_actions_r2599()
RETURNS TABLE (
  id uuid,
  chain_name text,
  c_suite_role text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  status text,
  owner_email text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, s.chain_name, s.c_suite_role, a.action_at, a.action_kind,
           a.outcome, a.status, a.owner_email, a.notes
    FROM public.c_suite_tone_adjustment_actions_r2599 a
    JOIN public.chain_c_suite_communication_style_r2599 s ON s.id = a.style_id
    ORDER BY a.action_at DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_tone_adjustment_actions_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_tone_adjustment_actions_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.high_risk_misalignment_focus_r2599()
RETURNS TABLE (
  id uuid,
  chain_name text,
  c_suite_role text,
  misalignment_risk_kind text,
  status text,
  adjustment_md text,
  owner_email text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.chain_name, s.c_suite_role, s.misalignment_risk_kind,
           s.status, s.adjustment_md, s.owner_email
    FROM public.chain_c_suite_communication_style_r2599 s
    WHERE s.misalignment_risk_kind IN ('high','critical')
    ORDER BY
      CASE s.misalignment_risk_kind WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END ASC,
      s.created_at DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.high_risk_misalignment_focus_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.high_risk_misalignment_focus_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.style_distribution_r2599()
RETURNS TABLE (
  communication_style_kind text,
  total bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.communication_style_kind, COUNT(*)::bigint AS total
    FROM public.chain_c_suite_communication_style_r2599 s
    GROUP BY s.communication_style_kind
    ORDER BY total DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.style_distribution_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.style_distribution_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.role_breakdown_r2599()
RETURNS TABLE (
  c_suite_role text,
  total bigint,
  high_risk bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.c_suite_role,
           COUNT(*)::bigint AS total,
           COUNT(*) FILTER (WHERE s.misalignment_risk_kind IN ('high','critical'))::bigint AS high_risk
    FROM public.chain_c_suite_communication_style_r2599 s
    GROUP BY s.c_suite_role
    ORDER BY total DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.role_breakdown_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_breakdown_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_action_trend_r2599()
RETURNS TABLE (
  month_start timestamptz,
  total bigint,
  positive_outcome bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', a.action_at) AS month_start,
           COUNT(*)::bigint AS total,
           COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_outcome
    FROM public.c_suite_tone_adjustment_actions_r2599 a
    GROUP BY date_trunc('month', a.action_at)
    ORDER BY month_start DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_action_trend_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_action_trend_r2599() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2599()
RETURNS TABLE (
  owner_email text,
  styles_owned bigint,
  open_actions bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(s.owner_email,'(unassigned)') AS owner_email,
           COUNT(DISTINCT s.id)::bigint AS styles_owned,
           COUNT(a.id) FILTER (WHERE a.status = 'open')::bigint AS open_actions
    FROM public.chain_c_suite_communication_style_r2599 s
    LEFT JOIN public.c_suite_tone_adjustment_actions_r2599 a ON a.style_id = s.id
    GROUP BY COALESCE(s.owner_email,'(unassigned)')
    ORDER BY styles_owned DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2599() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2599() TO authenticated;
