-- Round 2562: Engineer App Feature Adoption Curve
-- Track feature × release version × engineer × first-use × daily-active × stuck × love
-- Founder-only console for measuring adoption curves and helping stuck users

-- ============================================================
-- TABLE 1: engineer_feature_adoption_r2562
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_feature_adoption_r2562 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  feature_name text NOT NULL,
  release_version text NOT NULL,
  first_use_at timestamptz,
  last_use_at timestamptz,
  daily_active boolean NOT NULL DEFAULT false,
  stuck boolean NOT NULL DEFAULT false,
  love_score int NOT NULL DEFAULT 0 CHECK (love_score >= 0 AND love_score <= 10),
  support_ticket_count int NOT NULL DEFAULT 0 CHECK (support_ticket_count >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'not_adopted'
    CHECK (status IN ('not_adopted','onboarding','active','lapsed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efa_r2562_engineer ON public.engineer_feature_adoption_r2562(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efa_r2562_feature ON public.engineer_feature_adoption_r2562(feature_name);
CREATE INDEX IF NOT EXISTS idx_efa_r2562_release ON public.engineer_feature_adoption_r2562(release_version);
CREATE INDEX IF NOT EXISTS idx_efa_r2562_status ON public.engineer_feature_adoption_r2562(status);

ALTER TABLE public.engineer_feature_adoption_r2562 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_feature_adoption_r2562;
CREATE POLICY founder_all ON public.engineer_feature_adoption_r2562
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: feature_stuck_user_help_r2562
-- ============================================================
CREATE TABLE IF NOT EXISTS public.feature_stuck_user_help_r2562 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  adoption_id uuid NOT NULL REFERENCES public.engineer_feature_adoption_r2562(id) ON DELETE CASCADE,
  help_kind text NOT NULL
    CHECK (help_kind IN ('documentation','training','bug_fix','feature_clarification','integration')),
  helped_at timestamptz NOT NULL DEFAULT now(),
  owner_email text,
  outcome text NOT NULL DEFAULT 'pending'
    CHECK (outcome IN ('resolved','escalated','dropped','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsuh_r2562_adoption ON public.feature_stuck_user_help_r2562(adoption_id);
CREATE INDEX IF NOT EXISTS idx_fsuh_r2562_outcome ON public.feature_stuck_user_help_r2562(outcome);
CREATE INDEX IF NOT EXISTS idx_fsuh_r2562_help_kind ON public.feature_stuck_user_help_r2562(help_kind);

ALTER TABLE public.feature_stuck_user_help_r2562 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.feature_stuck_user_help_r2562;
CREATE POLICY founder_all ON public.feature_stuck_user_help_r2562
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEEDS (3-5 rows each)
-- ============================================================
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_ad1 uuid;
  v_ad2 uuid;
  v_ad3 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  IF v_eng1 IS NULL THEN RETURN; END IF;
  IF v_eng2 IS NULL THEN v_eng2 := v_eng1; END IF;
  IF v_eng3 IS NULL THEN v_eng3 := v_eng1; END IF;

  INSERT INTO public.engineer_feature_adoption_r2562 (engineer_user_id, feature_name, release_version, first_use_at, last_use_at, daily_active, stuck, love_score, support_ticket_count, owner_email, status, notes)
  VALUES (v_eng1, 'Bonded Parts Scanner', 'v0.5.2', now() - interval '20 days', now() - interval '1 day', true, false, 9, 0, 'product@equipseva.com', 'active', 'Daily user since launch')
  RETURNING id INTO v_ad1;

  INSERT INTO public.engineer_feature_adoption_r2562 (engineer_user_id, feature_name, release_version, first_use_at, last_use_at, daily_active, stuck, love_score, support_ticket_count, owner_email, status, notes)
  VALUES (v_eng2, 'Supervised Training Mode', 'v0.4.8', now() - interval '15 days', now() - interval '3 days', false, true, 4, 2, 'product@equipseva.com', 'onboarding', 'Stuck on supervisor link step')
  RETURNING id INTO v_ad2;

  INSERT INTO public.engineer_feature_adoption_r2562 (engineer_user_id, feature_name, release_version, first_use_at, last_use_at, daily_active, stuck, love_score, support_ticket_count, owner_email, status, notes)
  VALUES (v_eng3, 'UPI Intent Payout', 'v0.5.0', now() - interval '8 days', now() - interval '6 days', false, false, 7, 0, 'finance@equipseva.com', 'lapsed', 'Used twice then quiet')
  RETURNING id INTO v_ad3;

  INSERT INTO public.engineer_feature_adoption_r2562 (engineer_user_id, feature_name, release_version, first_use_at, last_use_at, daily_active, stuck, love_score, support_ticket_count, owner_email, status, notes)
  VALUES (v_eng1, 'AMC Renewal Reminder', 'v0.5.2', NULL, NULL, false, false, 0, 0, 'product@equipseva.com', 'not_adopted', 'Not yet used');

  INSERT INTO public.feature_stuck_user_help_r2562 (adoption_id, help_kind, helped_at, owner_email, outcome, notes)
  VALUES (v_ad2, 'documentation', now() - interval '2 days', 'product@equipseva.com', 'pending', 'Sent revised supervisor-link doc');

  INSERT INTO public.feature_stuck_user_help_r2562 (adoption_id, help_kind, helped_at, owner_email, outcome, notes)
  VALUES (v_ad2, 'training', now() - interval '1 days', 'product@equipseva.com', 'escalated', 'Booked 1:1 onboarding call');

  INSERT INTO public.feature_stuck_user_help_r2562 (adoption_id, help_kind, helped_at, owner_email, outcome, notes)
  VALUES (v_ad3, 'feature_clarification', now() - interval '4 days', 'finance@equipseva.com', 'resolved', 'Clarified payout cutoff time');

  INSERT INTO public.feature_stuck_user_help_r2562 (adoption_id, help_kind, helped_at, owner_email, outcome, notes)
  VALUES (v_ad1, 'integration', now() - interval '10 days', 'product@equipseva.com', 'resolved', 'Scanner SDK upgrade unblocked workflow');
END
$seed$;

-- ============================================================
-- RPC 1: list_adoption_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_adoption_r2562()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  feature_name text,
  release_version text,
  first_use_at timestamptz,
  last_use_at timestamptz,
  daily_active boolean,
  stuck boolean,
  love_score int,
  support_ticket_count int,
  owner_email text,
  status text,
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
  SELECT a.id, a.engineer_user_id, a.feature_name, a.release_version,
         a.first_use_at, a.last_use_at, a.daily_active, a.stuck, a.love_score,
         a.support_ticket_count, a.owner_email, a.status, a.notes, a.created_at
  FROM public.engineer_feature_adoption_r2562 a
  ORDER BY a.created_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_adoption_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_adoption_r2562() TO authenticated;

-- ============================================================
-- RPC 2: list_stuck_help_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_stuck_help_r2562()
RETURNS TABLE (
  id uuid,
  adoption_id uuid,
  feature_name text,
  help_kind text,
  helped_at timestamptz,
  owner_email text,
  outcome text,
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
  SELECT h.id, h.adoption_id, a.feature_name, h.help_kind, h.helped_at,
         h.owner_email, h.outcome, h.notes, h.created_at
  FROM public.feature_stuck_user_help_r2562 h
  JOIN public.engineer_feature_adoption_r2562 a ON a.id = h.adoption_id
  ORDER BY h.helped_at DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_stuck_help_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stuck_help_r2562() TO authenticated;

-- ============================================================
-- RPC 3: top_loved_features_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_loved_features_r2562()
RETURNS TABLE (
  feature_name text,
  user_count bigint,
  avg_love numeric,
  daily_active_count bigint,
  stuck_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.feature_name,
         COUNT(*)::bigint AS user_count,
         ROUND(AVG(a.love_score)::numeric, 2) AS avg_love,
         COUNT(*) FILTER (WHERE a.daily_active)::bigint AS daily_active_count,
         COUNT(*) FILTER (WHERE a.stuck)::bigint AS stuck_count
  FROM public.engineer_feature_adoption_r2562 a
  GROUP BY a.feature_name
  ORDER BY ROUND(AVG(a.love_score)::numeric, 2) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_loved_features_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loved_features_r2562() TO authenticated;

-- ============================================================
-- RPC 4: stuck_user_focus_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.stuck_user_focus_r2562()
RETURNS TABLE (
  adoption_id uuid,
  feature_name text,
  release_version text,
  engineer_user_id uuid,
  support_ticket_count int,
  help_attempts bigint,
  last_helped_at timestamptz,
  status text,
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
  SELECT a.id AS adoption_id,
         a.feature_name,
         a.release_version,
         a.engineer_user_id,
         a.support_ticket_count,
         COALESCE(COUNT(h.id), 0)::bigint AS help_attempts,
         MAX(h.helped_at) AS last_helped_at,
         a.status,
         a.owner_email
  FROM public.engineer_feature_adoption_r2562 a
  LEFT JOIN public.feature_stuck_user_help_r2562 h ON h.adoption_id = a.id
  WHERE a.stuck = true
  GROUP BY a.id, a.feature_name, a.release_version, a.engineer_user_id,
           a.support_ticket_count, a.status, a.owner_email
  ORDER BY a.support_ticket_count DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.stuck_user_focus_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stuck_user_focus_r2562() TO authenticated;

-- ============================================================
-- RPC 5: feature_adoption_funnel_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.feature_adoption_funnel_r2562()
RETURNS TABLE (
  status text,
  user_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, COUNT(*)::bigint AS user_count
  FROM public.engineer_feature_adoption_r2562 a
  GROUP BY a.status
  ORDER BY COUNT(*) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.feature_adoption_funnel_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feature_adoption_funnel_r2562() TO authenticated;

-- ============================================================
-- RPC 6: weekly_use_trend_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.weekly_use_trend_r2562()
RETURNS TABLE (
  week_start timestamptz,
  first_uses bigint,
  last_uses bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', d.dt)::timestamptz AS week_start,
         COUNT(*) FILTER (WHERE d.kind = 'first')::bigint AS first_uses,
         COUNT(*) FILTER (WHERE d.kind = 'last')::bigint AS last_uses
  FROM (
    SELECT a.first_use_at AS dt, 'first'::text AS kind
    FROM public.engineer_feature_adoption_r2562 a
    WHERE a.first_use_at IS NOT NULL
    UNION ALL
    SELECT a.last_use_at AS dt, 'last'::text AS kind
    FROM public.engineer_feature_adoption_r2562 a
    WHERE a.last_use_at IS NOT NULL
  ) d
  GROUP BY date_trunc('week', d.dt)
  ORDER BY date_trunc('week', d.dt) DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_use_trend_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_use_trend_r2562() TO authenticated;

-- ============================================================
-- RPC 7: release_version_breakdown_r2562
-- ============================================================
CREATE OR REPLACE FUNCTION public.release_version_breakdown_r2562()
RETURNS TABLE (
  release_version text,
  user_count bigint,
  active_count bigint,
  stuck_count bigint,
  avg_love numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.release_version,
         COUNT(*)::bigint AS user_count,
         COUNT(*) FILTER (WHERE a.status = 'active')::bigint AS active_count,
         COUNT(*) FILTER (WHERE a.stuck)::bigint AS stuck_count,
         ROUND(AVG(a.love_score)::numeric, 2) AS avg_love
  FROM public.engineer_feature_adoption_r2562 a
  GROUP BY a.release_version
  ORDER BY a.release_version DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.release_version_breakdown_r2562() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_version_breakdown_r2562() TO authenticated;
