-- Round r2579: Hospital chain board of trustees relations
-- Tables: chain_board_trustee_relations_r2579, trustee_touch_events_r2579
-- 7 RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.chain_board_trustee_relations_r2579 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  trustee_name text NOT NULL,
  trustee_email text,
  trustee_role text NOT NULL CHECK (trustee_role IN ('chair','vice_chair','treasurer','secretary','independent_director')),
  relationship_strength text NOT NULL DEFAULT 'developing' CHECK (relationship_strength IN ('weak','developing','strong','champion')),
  influence_score int NOT NULL DEFAULT 50 CHECK (influence_score BETWEEN 0 AND 100),
  deal_accelerator_kind text NOT NULL DEFAULT 'marginal' CHECK (deal_accelerator_kind IN ('strong','marginal','none','blocker')),
  tension_flags_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','strained','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trustee_touch_events_r2579 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trustee_id uuid NOT NULL REFERENCES public.chain_board_trustee_relations_r2579(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL DEFAULT now(),
  touch_kind text NOT NULL CHECK (touch_kind IN ('board_meeting','dinner','call','conference','intro')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_board_trustee_relations_r2579 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trustee_touch_events_r2579 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_board_trustee_relations_r2579;
CREATE POLICY founder_all ON public.chain_board_trustee_relations_r2579
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.trustee_touch_events_r2579;
CREATE POLICY founder_all ON public.trustee_touch_events_r2579
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed trustee relations
INSERT INTO public.chain_board_trustee_relations_r2579
  (id, chain_name, trustee_name, trustee_email, trustee_role, relationship_strength, influence_score, deal_accelerator_kind, tension_flags_md, owner_email, status, notes)
VALUES
  ('33333333-3333-3333-3333-333333333301', 'Apollo Chain', 'Dr. Suresh Reddy', 'sreddy@apollo-board.example', 'chair', 'champion', 92, 'strong', NULL, 'founder@equipseva.in', 'active', 'Top advocate; introd CFO directly'),
  ('33333333-3333-3333-3333-333333333302', 'Apollo Chain', 'Mrs. Kavitha Iyer', 'kiyer@apollo-board.example', 'treasurer', 'developing', 65, 'marginal', '- Pushes back on capex requests\n- Wants 18-month payback proof', 'founder@equipseva.in', 'active', 'Needs ROI deck for next meeting'),
  ('33333333-3333-3333-3333-333333333303', 'Fortis Network', 'Mr. Arvind Mehta', 'amehta@fortis-board.example', 'vice_chair', 'strong', 78, 'strong', NULL, 'cofounder@equipseva.in', 'active', 'Met at HIMSS; warm follow-up'),
  ('33333333-3333-3333-3333-333333333304', 'Fortis Network', 'Dr. Anjali Sharma', 'asharma@fortis-board.example', 'independent_director', 'weak', 38, 'blocker', '- Skeptical of startups\n- Vocal critic in last 2 board meetings', 'cofounder@equipseva.in', 'strained', 'Needs founder direct engagement'),
  ('33333333-3333-3333-3333-333333333305', 'Manipal Group', 'Mr. Rajesh Pai', 'rpai@manipal-board.example', 'secretary', 'developing', 55, 'none', NULL, 'founder@equipseva.in', 'dormant', 'No touch in 90 days')
ON CONFLICT (id) DO NOTHING;

-- Seed touch events
INSERT INTO public.trustee_touch_events_r2579
  (trustee_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
VALUES
  ('33333333-3333-3333-3333-333333333301', '2026-06-05 10:00:00+05:30', 'board_meeting', 'positive', '2026-07-05 10:00:00+05:30', 'founder@equipseva.in', 'done', 'Endorsed expansion proposal'),
  ('33333333-3333-3333-3333-333333333301', '2026-06-15 19:00:00+05:30', 'dinner', 'positive', '2026-07-15 19:00:00+05:30', 'founder@equipseva.in', 'done', 'Champion deepening'),
  ('33333333-3333-3333-3333-333333333302', '2026-06-10 14:00:00+05:30', 'call', 'neutral', '2026-06-30 14:00:00+05:30', 'founder@equipseva.in', 'open', 'Sent ROI memo as follow-up'),
  ('33333333-3333-3333-3333-333333333303', '2026-05-20 11:00:00+05:30', 'conference', 'positive', '2026-06-25 11:00:00+05:30', 'cofounder@equipseva.in', 'done', 'HIMSS booth visit'),
  ('33333333-3333-3333-3333-333333333304', '2026-06-12 15:00:00+05:30', 'board_meeting', 'negative', '2026-06-26 15:00:00+05:30', 'cofounder@equipseva.in', 'open', 'Pushed back on bulk PO; needs reference visit'),
  ('33333333-3333-3333-3333-333333333305', '2026-03-15 10:00:00+05:30', 'intro', 'neutral', NULL, 'founder@equipseva.in', 'dropped', 'Initial intro; no follow-up momentum')
ON CONFLICT (id) DO NOTHING;

-- RPC 1: list trustee relations
CREATE OR REPLACE FUNCTION public.list_trustee_relations_r2579()
RETURNS TABLE (
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  trustee_name text,
  trustee_email text,
  trustee_role text,
  relationship_strength text,
  influence_score int,
  deal_accelerator_kind text,
  tension_flags_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.chain_name, t.hospital_user_id, t.trustee_name, t.trustee_email, t.trustee_role,
         t.relationship_strength, t.influence_score, t.deal_accelerator_kind, t.tension_flags_md,
         t.owner_email, t.status, t.notes, t.created_at
  FROM public.chain_board_trustee_relations_r2579 t
  ORDER BY t.influence_score DESC NULLS LAST, t.chain_name ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_trustee_relations_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trustee_relations_r2579() TO authenticated;

-- RPC 2: list touch events
CREATE OR REPLACE FUNCTION public.list_touch_events_r2579()
RETURNS TABLE (
  id uuid,
  trustee_id uuid,
  trustee_name text,
  chain_name text,
  touch_at timestamptz,
  touch_kind text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.trustee_id, t.trustee_name, t.chain_name, e.touch_at, e.touch_kind, e.outcome,
         e.follow_up_at, e.owner_email, e.status, e.notes
  FROM public.trustee_touch_events_r2579 e
  JOIN public.chain_board_trustee_relations_r2579 t ON t.id = e.trustee_id
  ORDER BY e.touch_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_touch_events_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touch_events_r2579() TO authenticated;

-- RPC 3: top influence trustees
CREATE OR REPLACE FUNCTION public.top_influence_trustees_r2579()
RETURNS TABLE (
  trustee_name text,
  chain_name text,
  trustee_role text,
  relationship_strength text,
  influence_score int,
  deal_accelerator_kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trustee_name, t.chain_name, t.trustee_role, t.relationship_strength,
         t.influence_score, t.deal_accelerator_kind, t.status
  FROM public.chain_board_trustee_relations_r2579 t
  ORDER BY t.influence_score DESC NULLS LAST
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_influence_trustees_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influence_trustees_r2579() TO authenticated;

-- RPC 4: role distribution
CREATE OR REPLACE FUNCTION public.role_distribution_r2579()
RETURNS TABLE (
  trustee_role text,
  total_count bigint,
  champion_count bigint,
  strong_count bigint,
  developing_count bigint,
  weak_count bigint,
  avg_influence numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trustee_role,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE t.relationship_strength = 'champion')::bigint AS champion_count,
         COUNT(*) FILTER (WHERE t.relationship_strength = 'strong')::bigint AS strong_count,
         COUNT(*) FILTER (WHERE t.relationship_strength = 'developing')::bigint AS developing_count,
         COUNT(*) FILTER (WHERE t.relationship_strength = 'weak')::bigint AS weak_count,
         AVG(t.influence_score)::numeric AS avg_influence
  FROM public.chain_board_trustee_relations_r2579 t
  GROUP BY t.trustee_role
  ORDER BY avg_influence DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_distribution_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_distribution_r2579() TO authenticated;

-- RPC 5: strained focus
CREATE OR REPLACE FUNCTION public.strained_focus_r2579()
RETURNS TABLE (
  trustee_name text,
  chain_name text,
  trustee_role text,
  relationship_strength text,
  influence_score int,
  deal_accelerator_kind text,
  tension_flags_md text,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trustee_name, t.chain_name, t.trustee_role, t.relationship_strength,
         t.influence_score, t.deal_accelerator_kind, t.tension_flags_md, t.owner_email, t.status
  FROM public.chain_board_trustee_relations_r2579 t
  WHERE t.status IN ('strained','lost')
     OR t.deal_accelerator_kind = 'blocker'
     OR t.relationship_strength = 'weak'
     OR (t.tension_flags_md IS NOT NULL AND length(t.tension_flags_md) > 0)
  ORDER BY t.influence_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.strained_focus_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.strained_focus_r2579() TO authenticated;

-- RPC 6: monthly touch trend
CREATE OR REPLACE FUNCTION public.monthly_touch_trend_r2579()
RETURNS TABLE (
  month_label text,
  total_touches bigint,
  positive_count bigint,
  neutral_count bigint,
  negative_count bigint,
  pending_count bigint,
  unique_trustees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', e.touch_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS total_touches,
         COUNT(*) FILTER (WHERE e.outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE e.outcome = 'neutral')::bigint AS neutral_count,
         COUNT(*) FILTER (WHERE e.outcome = 'negative')::bigint AS negative_count,
         COUNT(*) FILTER (WHERE e.outcome = 'pending')::bigint AS pending_count,
         COUNT(DISTINCT e.trustee_id)::bigint AS unique_trustees
  FROM public.trustee_touch_events_r2579 e
  GROUP BY to_char(date_trunc('month', e.touch_at), 'YYYY-MM')
  ORDER BY month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_touch_trend_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_touch_trend_r2579() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2579()
RETURNS TABLE (
  owner_email text,
  trustee_count bigint,
  champion_count bigint,
  strained_count bigint,
  open_touches bigint,
  avg_influence numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(t.owner_email, 'unassigned') AS owner_email,
         COUNT(*)::bigint AS trustee_count,
         COUNT(*) FILTER (WHERE t.relationship_strength = 'champion')::bigint AS champion_count,
         COUNT(*) FILTER (WHERE t.status = 'strained' OR t.deal_accelerator_kind = 'blocker')::bigint AS strained_count,
         (SELECT COUNT(*)::bigint FROM public.trustee_touch_events_r2579 e
           JOIN public.chain_board_trustee_relations_r2579 t2 ON t2.id = e.trustee_id
           WHERE COALESCE(t2.owner_email, 'unassigned') = COALESCE(t.owner_email, 'unassigned')
             AND e.status = 'open') AS open_touches,
         AVG(t.influence_score)::numeric AS avg_influence
  FROM public.chain_board_trustee_relations_r2579 t
  GROUP BY COALESCE(t.owner_email, 'unassigned')
  ORDER BY trustee_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2579() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2579() TO authenticated;
