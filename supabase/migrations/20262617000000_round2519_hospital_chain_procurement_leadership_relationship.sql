-- Round 2519: hospital-chain-procurement-leadership-relationship
-- Track procurement leaders at hospital chains, their influence, and touchpoints.

BEGIN;

-- =========================================================================
-- Table: chain_procurement_leaders_r2519
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.chain_procurement_leaders_r2519 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  leader_name text NOT NULL,
  leader_email text,
  leader_role text NOT NULL CHECK (leader_role IN ('procurement_head','cfo','cmo','coo','admin_director')),
  relationship_strength text NOT NULL CHECK (relationship_strength IN ('weak','developing','strong','champion')),
  influence_score int NOT NULL CHECK (influence_score BETWEEN 0 AND 100),
  deal_blockers_md text,
  cycle_preference text NOT NULL CHECK (cycle_preference IN ('weekly','monthly','quarterly')),
  last_touch_at timestamptz,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpl_r2519_chain ON public.chain_procurement_leaders_r2519(chain_name);
CREATE INDEX IF NOT EXISTS idx_cpl_r2519_strength ON public.chain_procurement_leaders_r2519(relationship_strength);
CREATE INDEX IF NOT EXISTS idx_cpl_r2519_influence ON public.chain_procurement_leaders_r2519(influence_score DESC);

ALTER TABLE public.chain_procurement_leaders_r2519 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_procurement_leaders_r2519;
CREATE POLICY founder_all ON public.chain_procurement_leaders_r2519
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Table: procurement_leader_touchpoints_r2519
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.procurement_leader_touchpoints_r2519 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  leader_id uuid NOT NULL REFERENCES public.chain_procurement_leaders_r2519(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL,
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','meeting','dinner','site_visit','conference')),
  agenda text,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_plt_r2519_leader ON public.procurement_leader_touchpoints_r2519(leader_id);
CREATE INDEX IF NOT EXISTS idx_plt_r2519_touch_at ON public.procurement_leader_touchpoints_r2519(touch_at DESC);
CREATE INDEX IF NOT EXISTS idx_plt_r2519_status ON public.procurement_leader_touchpoints_r2519(status);

ALTER TABLE public.procurement_leader_touchpoints_r2519 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.procurement_leader_touchpoints_r2519;
CREATE POLICY founder_all ON public.procurement_leader_touchpoints_r2519
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- Seed data (3-5 leaders + touchpoints)
-- =========================================================================
INSERT INTO public.chain_procurement_leaders_r2519
  (chain_name, leader_name, leader_email, leader_role, relationship_strength, influence_score, deal_blockers_md, cycle_preference, last_touch_at, owner_email, notes)
VALUES
  ('Apollo Hospitals', 'Rakesh Menon', 'rakesh.menon@apollo.example', 'procurement_head', 'champion', 92, '- Wants 3-yr commitment\n- Needs CFO sign-off above 50L', 'monthly', now() - interval '4 days', 'founder@equipseva.com', 'Driving Apollo Bengaluru pilot; quarterly QBR scheduled.'),
  ('Manipal Hospitals', 'Dr. Aparna Krishnan', 'aparna.k@manipal.example', 'cmo', 'strong', 78, '- Clinical preference for OEM AMC', 'quarterly', now() - interval '11 days', 'founder@equipseva.com', 'Champion on uptime SLA; needs Manipal-Hyderabad case study.'),
  ('Fortis Healthcare', 'Vivek Bhatia', 'vivek.b@fortis.example', 'cfo', 'developing', 64, '- AMC pool unit economics unclear\n- Wants 30-day net terms', 'monthly', now() - interval '20 days', 'founder@equipseva.com', 'Warming up; sent unit-economics deck round 1300.'),
  ('Narayana Health', 'Suresh Iyer', 'suresh.iyer@narayanahealth.example', 'admin_director', 'weak', 35, '- No procurement budget alignment\n- Incumbent vendor lock-in', 'quarterly', now() - interval '47 days', 'founder@equipseva.com', 'Cold; need exec sponsor introduction.'),
  ('Max Healthcare', 'Neha Saxena', 'neha.saxena@maxhealthcare.example', 'coo', 'developing', 71, '- Compliance review pending', 'weekly', now() - interval '7 days', 'founder@equipseva.com', 'Engaged on multi-site rollout proposal.')
ON CONFLICT DO NOTHING;

-- Seed touchpoints (single-row inserts to avoid P0003)
DO $seed$
DECLARE
  v_apollo uuid;
  v_manipal uuid;
  v_fortis uuid;
  v_narayana uuid;
  v_max uuid;
BEGIN
  SELECT id INTO v_apollo FROM public.chain_procurement_leaders_r2519 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;
  SELECT id INTO v_manipal FROM public.chain_procurement_leaders_r2519 WHERE chain_name = 'Manipal Hospitals' LIMIT 1;
  SELECT id INTO v_fortis FROM public.chain_procurement_leaders_r2519 WHERE chain_name = 'Fortis Healthcare' LIMIT 1;
  SELECT id INTO v_narayana FROM public.chain_procurement_leaders_r2519 WHERE chain_name = 'Narayana Health' LIMIT 1;
  SELECT id INTO v_max FROM public.chain_procurement_leaders_r2519 WHERE chain_name = 'Max Healthcare' LIMIT 1;

  IF v_apollo IS NOT NULL THEN
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_apollo, now() - interval '4 days', 'meeting', 'QBR review + pilot expansion', 'positive', now() + interval '14 days', 'founder@equipseva.com', 'done', 'Green-lit Bengaluru expansion.');
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_apollo, now() - interval '18 days', 'dinner', 'Relationship build with CFO', 'positive', now() + interval '30 days', 'founder@equipseva.com', 'done', 'CFO now aware of EquipSeva.');
  END IF;

  IF v_manipal IS NOT NULL THEN
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_manipal, now() - interval '11 days', 'call', 'Uptime SLA discussion', 'neutral', now() + interval '10 days', 'founder@equipseva.com', 'open', 'Needs Hyderabad case study by next call.');
  END IF;

  IF v_fortis IS NOT NULL THEN
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_fortis, now() - interval '20 days', 'email', 'Unit economics deck follow-up', 'pending', now() + interval '5 days', 'founder@equipseva.com', 'open', 'Awaiting CFO feedback.');
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_fortis, now() - interval '55 days', 'conference', 'Met at HIMSS India', 'positive', NULL, 'founder@equipseva.com', 'done', 'Warm intro from mutual contact.');
  END IF;

  IF v_narayana IS NOT NULL THEN
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_narayana, now() - interval '47 days', 'email', 'Cold outreach', 'negative', NULL, 'founder@equipseva.com', 'dropped', 'Polite decline; revisit Q4.');
  END IF;

  IF v_max IS NOT NULL THEN
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_max, now() - interval '7 days', 'site_visit', 'Walk Max Saket facility', 'positive', now() + interval '3 days', 'founder@equipseva.com', 'open', 'Strong fit for multi-site.');
    INSERT INTO public.procurement_leader_touchpoints_r2519 (leader_id, touch_at, touch_kind, agenda, outcome, follow_up_at, owner_email, status, notes)
    VALUES (v_max, now() - interval '32 days', 'meeting', 'Initial scoping', 'neutral', now() - interval '7 days', 'founder@equipseva.com', 'done', 'Set up site visit.');
  END IF;
END
$seed$;

-- =========================================================================
-- RPC 1: list_leaders_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_leaders_r2519();
CREATE OR REPLACE FUNCTION public.list_leaders_r2519()
RETURNS TABLE (
  id uuid,
  chain_name text,
  leader_name text,
  leader_email text,
  leader_role text,
  relationship_strength text,
  influence_score int,
  cycle_preference text,
  last_touch_at timestamptz,
  owner_email text,
  deal_blockers_md text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.leader_name, l.leader_email, l.leader_role,
         l.relationship_strength, l.influence_score, l.cycle_preference,
         l.last_touch_at, l.owner_email, l.deal_blockers_md, l.notes, l.created_at
  FROM public.chain_procurement_leaders_r2519 l
  ORDER BY l.influence_score DESC, l.last_touch_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_leaders_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_leaders_r2519() TO authenticated;

-- =========================================================================
-- RPC 2: list_touchpoints_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_touchpoints_r2519();
CREATE OR REPLACE FUNCTION public.list_touchpoints_r2519()
RETURNS TABLE (
  id uuid,
  leader_id uuid,
  chain_name text,
  leader_name text,
  touch_at timestamptz,
  touch_kind text,
  agenda text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.leader_id, l.chain_name, l.leader_name,
         t.touch_at, t.touch_kind, t.agenda, t.outcome,
         t.follow_up_at, t.owner_email, t.status, t.notes
  FROM public.procurement_leader_touchpoints_r2519 t
  JOIN public.chain_procurement_leaders_r2519 l ON l.id = t.leader_id
  ORDER BY t.touch_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_touchpoints_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touchpoints_r2519() TO authenticated;

-- =========================================================================
-- RPC 3: weak_relationship_focus_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.weak_relationship_focus_r2519();
CREATE OR REPLACE FUNCTION public.weak_relationship_focus_r2519()
RETURNS TABLE (
  id uuid,
  chain_name text,
  leader_name text,
  leader_role text,
  relationship_strength text,
  influence_score int,
  days_since_touch int,
  deal_blockers_md text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.leader_name, l.leader_role,
         l.relationship_strength, l.influence_score,
         CASE WHEN l.last_touch_at IS NULL THEN NULL
              ELSE EXTRACT(day FROM (now() - l.last_touch_at))::int
         END AS days_since_touch,
         l.deal_blockers_md
  FROM public.chain_procurement_leaders_r2519 l
  WHERE l.relationship_strength IN ('weak','developing')
  ORDER BY l.influence_score DESC, l.last_touch_at ASC NULLS FIRST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weak_relationship_focus_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weak_relationship_focus_r2519() TO authenticated;

-- =========================================================================
-- RPC 4: top_influence_leaders_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_influence_leaders_r2519();
CREATE OR REPLACE FUNCTION public.top_influence_leaders_r2519()
RETURNS TABLE (
  id uuid,
  chain_name text,
  leader_name text,
  leader_role text,
  influence_score int,
  relationship_strength text,
  cycle_preference text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.chain_name, l.leader_name, l.leader_role,
         l.influence_score, l.relationship_strength, l.cycle_preference, l.owner_email
  FROM public.chain_procurement_leaders_r2519 l
  ORDER BY l.influence_score DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_influence_leaders_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influence_leaders_r2519() TO authenticated;

-- =========================================================================
-- RPC 5: role_breakdown_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.role_breakdown_r2519();
CREATE OR REPLACE FUNCTION public.role_breakdown_r2519()
RETURNS TABLE (
  leader_role text,
  leader_count bigint,
  avg_influence numeric,
  champion_count bigint,
  weak_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.leader_role,
         COUNT(*)::bigint AS leader_count,
         ROUND(AVG(l.influence_score)::numeric, 1) AS avg_influence,
         COUNT(*) FILTER (WHERE l.relationship_strength = 'champion')::bigint AS champion_count,
         COUNT(*) FILTER (WHERE l.relationship_strength = 'weak')::bigint AS weak_count
  FROM public.chain_procurement_leaders_r2519 l
  GROUP BY l.leader_role
  ORDER BY leader_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_breakdown_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_breakdown_r2519() TO authenticated;

-- =========================================================================
-- RPC 6: recent_touch_calendar_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.recent_touch_calendar_r2519();
CREATE OR REPLACE FUNCTION public.recent_touch_calendar_r2519()
RETURNS TABLE (
  touch_at timestamptz,
  chain_name text,
  leader_name text,
  touch_kind text,
  outcome text,
  status text,
  follow_up_at timestamptz,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.touch_at, l.chain_name, l.leader_name,
         t.touch_kind, t.outcome, t.status, t.follow_up_at, t.owner_email
  FROM public.procurement_leader_touchpoints_r2519 t
  JOIN public.chain_procurement_leaders_r2519 l ON l.id = t.leader_id
  WHERE t.touch_at >= now() - interval '60 days'
  ORDER BY t.touch_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_touch_calendar_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_touch_calendar_r2519() TO authenticated;

-- =========================================================================
-- RPC 7: monthly_outcome_trend_r2519
-- =========================================================================
DROP FUNCTION IF EXISTS public.monthly_outcome_trend_r2519();
CREATE OR REPLACE FUNCTION public.monthly_outcome_trend_r2519()
RETURNS TABLE (
  month_start timestamptz,
  touch_count bigint,
  positive_count bigint,
  neutral_count bigint,
  negative_count bigint,
  pending_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', t.touch_at) AS month_start,
         COUNT(*)::bigint AS touch_count,
         COUNT(*) FILTER (WHERE t.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE t.outcome = 'neutral')::bigint AS neutral_count,
         COUNT(*) FILTER (WHERE t.outcome = 'negative')::bigint AS negative_count,
         COUNT(*) FILTER (WHERE t.outcome = 'pending')::bigint AS pending_count
  FROM public.procurement_leader_touchpoints_r2519 t
  GROUP BY date_trunc('month', t.touch_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_outcome_trend_r2519() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_outcome_trend_r2519() TO authenticated;

