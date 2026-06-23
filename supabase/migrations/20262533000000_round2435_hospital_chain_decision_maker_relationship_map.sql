-- Round 2435: hospital-chain-decision-maker-relationship-map

CREATE TABLE IF NOT EXISTS public.chain_decision_makers_r2435 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  person_name text NOT NULL,
  person_title text NOT NULL,
  person_email text,
  person_phone text,
  decision_role text NOT NULL CHECK (decision_role IN ('executive_sponsor','champion','influencer','technical_evaluator','procurement','legal','clinical_user','blocker')),
  influence_score int NOT NULL CHECK (influence_score BETWEEN 0 AND 100),
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('weak','developing','strong','champion')),
  last_touch_at timestamptz,
  last_touch_kind text CHECK (last_touch_kind IN ('call','email','visit','event','meeting')),
  red_flags_md text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.chain_relationship_touchpoints_r2435 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  decision_maker_id uuid NOT NULL REFERENCES public.chain_decision_makers_r2435(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL,
  touch_kind text NOT NULL,
  agenda text,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative')),
  follow_up_required boolean NOT NULL DEFAULT false,
  follow_up_at timestamptz,
  owner_email text,
  notes text
);

ALTER TABLE public.chain_decision_makers_r2435 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_relationship_touchpoints_r2435 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_decision_makers_r2435;
CREATE POLICY founder_all ON public.chain_decision_makers_r2435 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_relationship_touchpoints_r2435;
CREATE POLICY founder_all ON public.chain_relationship_touchpoints_r2435 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed decision makers
INSERT INTO public.chain_decision_makers_r2435 (chain_name, person_name, person_title, person_email, person_phone, decision_role, influence_score, relationship_strength, last_touch_at, last_touch_kind, red_flags_md, notes) VALUES
('Apollo Hospitals', 'Dr Suresh Rao', 'Group CMO', 'suresh.rao@example.com', '+91-9000010001', 'executive_sponsor', 92, 'strong', now() - interval '4 days', 'meeting', NULL, 'Likes annualized ROI decks'),
('Apollo Hospitals', 'Meera Iyer', 'VP Procurement', 'meera.iyer@example.com', '+91-9000010002', 'procurement', 78, 'developing', now() - interval '11 days', 'email', 'Pushing for 12% additional discount', 'Wants vendor consolidation'),
('Fortis Healthcare', 'Rohan Malhotra', 'Biomed Head', 'rohan.malhotra@example.com', '+91-9000010003', 'technical_evaluator', 85, 'champion', now() - interval '2 days', 'visit', NULL, 'Champion since pilot 2025-Q4'),
('Fortis Healthcare', 'Ankita Bose', 'Legal Counsel', NULL, '+91-9000010004', 'legal', 55, 'weak', now() - interval '21 days', 'call', 'Blocking MSA over indemnity cap', 'Need legal escalation'),
('Manipal Hospitals', 'Dr Vikram Sethi', 'Group COO', 'vikram.sethi@example.com', '+91-9000010005', 'blocker', 70, 'weak', now() - interval '40 days', 'event', 'Skeptical of startup vendor risk', 'Need reference call');

-- Seed touchpoints
INSERT INTO public.chain_relationship_touchpoints_r2435 (decision_maker_id, touch_at, touch_kind, agenda, outcome, follow_up_required, follow_up_at, owner_email, notes)
SELECT id, now() - interval '4 days', 'meeting', 'ROI deck review', 'positive', true, now() + interval '7 days', 'founder@equipseva.in', 'Asked for case studies' FROM public.chain_decision_makers_r2435 WHERE person_name = 'Dr Suresh Rao';

INSERT INTO public.chain_relationship_touchpoints_r2435 (decision_maker_id, touch_at, touch_kind, agenda, outcome, follow_up_required, follow_up_at, owner_email, notes)
SELECT id, now() - interval '11 days', 'email', 'Discount negotiation', 'neutral', true, now() + interval '3 days', 'founder@equipseva.in', 'Counter-proposal due' FROM public.chain_decision_makers_r2435 WHERE person_name = 'Meera Iyer';

INSERT INTO public.chain_relationship_touchpoints_r2435 (decision_maker_id, touch_at, touch_kind, agenda, outcome, follow_up_required, follow_up_at, owner_email, notes)
SELECT id, now() - interval '21 days', 'call', 'MSA indemnity clause', 'negative', true, now() + interval '2 days', 'legal@equipseva.in', 'Escalate to GC' FROM public.chain_decision_makers_r2435 WHERE person_name = 'Ankita Bose';

INSERT INTO public.chain_relationship_touchpoints_r2435 (decision_maker_id, touch_at, touch_kind, agenda, outcome, follow_up_required, follow_up_at, owner_email, notes)
SELECT id, now() - interval '40 days', 'event', 'Industry summit chat', 'negative', true, now() + interval '5 days', 'founder@equipseva.in', 'Send reference call invite' FROM public.chain_decision_makers_r2435 WHERE person_name = 'Dr Vikram Sethi';

-- RPCs
CREATE OR REPLACE FUNCTION public.list_decision_makers_r2435()
RETURNS TABLE(id uuid, chain_name text, person_name text, person_title text, decision_role text, influence_score int, relationship_strength text, last_touch_at timestamptz, last_touch_kind text, red_flags_md text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.person_name, d.person_title, d.decision_role, d.influence_score, d.relationship_strength, d.last_touch_at, d.last_touch_kind, d.red_flags_md
  FROM public.chain_decision_makers_r2435 d
  ORDER BY d.chain_name ASC, d.influence_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_decision_makers_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_makers_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_touchpoints_r2435()
RETURNS TABLE(id uuid, chain_name text, person_name text, touch_at timestamptz, touch_kind text, agenda text, outcome text, follow_up_required boolean, follow_up_at timestamptz, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, d.chain_name, d.person_name, t.touch_at, t.touch_kind, t.agenda, t.outcome, t.follow_up_required, t.follow_up_at, t.owner_email
  FROM public.chain_relationship_touchpoints_r2435 t
  JOIN public.chain_decision_makers_r2435 d ON d.id = t.decision_maker_id
  ORDER BY t.touch_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_touchpoints_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touchpoints_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.blocker_focus_r2435()
RETURNS TABLE(id uuid, chain_name text, person_name text, person_title text, influence_score int, relationship_strength text, red_flags_md text, last_touch_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.person_name, d.person_title, d.influence_score, d.relationship_strength, d.red_flags_md, d.last_touch_at
  FROM public.chain_decision_makers_r2435 d
  WHERE d.decision_role = 'blocker' OR d.red_flags_md IS NOT NULL
  ORDER BY d.influence_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.blocker_focus_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocker_focus_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.weak_relationship_focus_r2435()
RETURNS TABLE(id uuid, chain_name text, person_name text, decision_role text, influence_score int, relationship_strength text, last_touch_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.person_name, d.decision_role, d.influence_score, d.relationship_strength, d.last_touch_at
  FROM public.chain_decision_makers_r2435 d
  WHERE d.relationship_strength IN ('weak','developing') AND d.influence_score >= 50
  ORDER BY d.influence_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.weak_relationship_focus_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weak_relationship_focus_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_influence_chain_summary_r2435()
RETURNS TABLE(chain_name text, decision_makers_count bigint, avg_influence numeric, champions_count bigint, blockers_count bigint, last_touch_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.chain_name,
         count(*)::bigint AS decision_makers_count,
         round(avg(d.influence_score)::numeric, 1) AS avg_influence,
         count(*) FILTER (WHERE d.relationship_strength = 'champion')::bigint AS champions_count,
         count(*) FILTER (WHERE d.decision_role = 'blocker')::bigint AS blockers_count,
         max(d.last_touch_at) AS last_touch_at
  FROM public.chain_decision_makers_r2435 d
  GROUP BY d.chain_name
  ORDER BY avg_influence DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_influence_chain_summary_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influence_chain_summary_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_touch_summary_r2435()
RETURNS TABLE(touch_kind text, total_touches bigint, positive_count bigint, neutral_count bigint, negative_count bigint, last_touch_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.touch_kind,
         count(*)::bigint AS total_touches,
         count(*) FILTER (WHERE t.outcome = 'positive')::bigint AS positive_count,
         count(*) FILTER (WHERE t.outcome = 'neutral')::bigint AS neutral_count,
         count(*) FILTER (WHERE t.outcome = 'negative')::bigint AS negative_count,
         max(t.touch_at) AS last_touch_at
  FROM public.chain_relationship_touchpoints_r2435 t
  GROUP BY t.touch_kind
  ORDER BY total_touches DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_touch_summary_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_touch_summary_r2435() TO authenticated;

CREATE OR REPLACE FUNCTION public.follow_up_calendar_r2435()
RETURNS TABLE(id uuid, chain_name text, person_name text, follow_up_at timestamptz, touch_kind text, agenda text, outcome text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, d.chain_name, d.person_name, t.follow_up_at, t.touch_kind, t.agenda, t.outcome, t.owner_email
  FROM public.chain_relationship_touchpoints_r2435 t
  JOIN public.chain_decision_makers_r2435 d ON d.id = t.decision_maker_id
  WHERE t.follow_up_required = true AND t.follow_up_at IS NOT NULL
  ORDER BY t.follow_up_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.follow_up_calendar_r2435() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.follow_up_calendar_r2435() TO authenticated;
