BEGIN;

-- =====================================================================
-- r1639 — Engineer Side-Quest Log (HEAVY)
-- Optional skill challenges, certifications, community demos.
-- Per-engineer completion + bonus payouts. Founder-only console.
-- =====================================================================

-- ---------- TABLES ----------

CREATE TABLE IF NOT EXISTS engineer_side_quests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  category text NOT NULL CHECK (category IN ('skill_challenge','certification','community_demo','training','outreach')),
  difficulty text NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy','medium','hard','epic')),
  bonus_rupees integer NOT NULL DEFAULT 0 CHECK (bonus_rupees >= 0),
  tier_minimum text,
  is_active boolean NOT NULL DEFAULT true,
  opens_at timestamptz NOT NULL DEFAULT now(),
  closes_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_side_quests_active ON engineer_side_quests(is_active, closes_at);
CREATE INDEX IF NOT EXISTS idx_engineer_side_quests_category ON engineer_side_quests(category);

CREATE TABLE IF NOT EXISTS engineer_side_quest_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quest_id uuid NOT NULL REFERENCES engineer_side_quests(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'opted_in' CHECK (status IN ('opted_in','submitted','approved','rejected','paid')),
  opted_in_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  approved_at timestamptz,
  paid_at timestamptz,
  bonus_paid_rupees integer DEFAULT 0,
  evidence_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(quest_id, engineer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_esqc_engineer ON engineer_side_quest_completions(engineer_user_id, status);
CREATE INDEX IF NOT EXISTS idx_esqc_quest ON engineer_side_quest_completions(quest_id, status);
CREATE INDEX IF NOT EXISTS idx_esqc_created ON engineer_side_quest_completions(created_at DESC);

ALTER TABLE engineer_side_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_side_quest_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_side_quests ON engineer_side_quests;
CREATE POLICY founder_only_side_quests ON engineer_side_quests
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_side_quest_completions ON engineer_side_quest_completions;
CREATE POLICY founder_only_side_quest_completions ON engineer_side_quest_completions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- AUDIT HELPER ----------

CREATE OR REPLACE FUNCTION log_founder_side_quest_action(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_side_quest_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_side_quest_action(text, jsonb) TO authenticated;

-- ---------- RPC 1: side-quest catalog ----------

CREATE OR REPLACE FUNCTION founder_side_quest_catalog()
RETURNS TABLE (
  quest_id uuid,
  slug text,
  title text,
  category text,
  difficulty text,
  bonus_rupees integer,
  is_active boolean,
  opted_in_count bigint,
  approved_count bigint,
  paid_count bigint,
  total_payout_rupees bigint,
  closes_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    q.id,
    q.slug,
    q.title,
    q.category,
    q.difficulty,
    q.bonus_rupees,
    q.is_active,
    COUNT(c.id) FILTER (WHERE c.status = 'opted_in')::bigint,
    COUNT(c.id) FILTER (WHERE c.status = 'approved')::bigint,
    COUNT(c.id) FILTER (WHERE c.status = 'paid')::bigint,
    COALESCE(SUM(c.bonus_paid_rupees) FILTER (WHERE c.status = 'paid'), 0)::bigint,
    q.closes_at
  FROM engineer_side_quests q
  LEFT JOIN engineer_side_quest_completions c ON c.quest_id = q.id
  GROUP BY q.id
  ORDER BY q.is_active DESC, q.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_catalog() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_catalog() TO authenticated;

-- ---------- RPC 2: pending submissions awaiting approval ----------

CREATE OR REPLACE FUNCTION founder_side_quest_pending_review()
RETURNS TABLE (
  completion_id uuid,
  quest_title text,
  category text,
  engineer_user_id uuid,
  engineer_tier text,
  bonus_rupees integer,
  submitted_at timestamptz,
  hours_waiting numeric,
  evidence_url text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    q.title,
    q.category,
    c.engineer_user_id,
    e.cached_highest_tier,
    q.bonus_rupees,
    c.submitted_at,
    ROUND(EXTRACT(EPOCH FROM (now() - c.submitted_at))/3600.0, 1)::numeric,
    c.evidence_url
  FROM engineer_side_quest_completions c
  JOIN engineer_side_quests q ON q.id = c.quest_id
  LEFT JOIN engineers e ON e.user_id = c.engineer_user_id
  WHERE c.status = 'submitted'
  ORDER BY c.submitted_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_pending_review() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_pending_review() TO authenticated;

-- ---------- RPC 3: per-engineer leaderboard ----------

CREATE OR REPLACE FUNCTION founder_side_quest_engineer_leaderboard()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_tier text,
  quests_opted_in bigint,
  quests_approved bigint,
  quests_paid bigint,
  total_bonus_rupees bigint,
  latest_completion_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.engineer_user_id,
    e.cached_highest_tier,
    COUNT(*) FILTER (WHERE c.status = 'opted_in')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'approved')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'paid')::bigint,
    COALESCE(SUM(c.bonus_paid_rupees) FILTER (WHERE c.status = 'paid'), 0)::bigint,
    MAX(c.approved_at)
  FROM engineer_side_quest_completions c
  LEFT JOIN engineers e ON e.user_id = c.engineer_user_id
  GROUP BY c.engineer_user_id, e.cached_highest_tier
  ORDER BY 6 DESC NULLS LAST, 4 DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_engineer_leaderboard() TO authenticated;

-- ---------- RPC 4: category mix ----------

CREATE OR REPLACE FUNCTION founder_side_quest_category_mix()
RETURNS TABLE (
  category text,
  quest_count bigint,
  total_opt_ins bigint,
  total_approved bigint,
  total_bonus_paid_rupees bigint,
  avg_bonus_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    q.category,
    COUNT(DISTINCT q.id)::bigint,
    COUNT(c.id) FILTER (WHERE c.status IN ('opted_in','submitted','approved','paid'))::bigint,
    COUNT(c.id) FILTER (WHERE c.status IN ('approved','paid'))::bigint,
    COALESCE(SUM(c.bonus_paid_rupees) FILTER (WHERE c.status = 'paid'), 0)::bigint,
    ROUND(AVG(q.bonus_rupees)::numeric, 0)
  FROM engineer_side_quests q
  LEFT JOIN engineer_side_quest_completions c ON c.quest_id = q.id
  GROUP BY q.category
  ORDER BY 5 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_category_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_category_mix() TO authenticated;

-- ---------- RPC 5: stale opt-ins (no submission in 14 days) ----------

CREATE OR REPLACE FUNCTION founder_side_quest_stale_opt_ins()
RETURNS TABLE (
  completion_id uuid,
  quest_title text,
  category text,
  engineer_user_id uuid,
  engineer_tier text,
  opted_in_at timestamptz,
  days_stale integer,
  closes_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    q.title,
    q.category,
    c.engineer_user_id,
    e.cached_highest_tier,
    c.opted_in_at,
    EXTRACT(DAY FROM (now() - c.opted_in_at))::integer,
    q.closes_at
  FROM engineer_side_quest_completions c
  JOIN engineer_side_quests q ON q.id = c.quest_id
  LEFT JOIN engineers e ON e.user_id = c.engineer_user_id
  WHERE c.status = 'opted_in'
    AND c.opted_in_at < now() - interval '14 days'
  ORDER BY c.opted_in_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_stale_opt_ins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_stale_opt_ins() TO authenticated;

-- ---------- RPC 6: payout summary by month ----------

CREATE OR REPLACE FUNCTION founder_side_quest_payout_summary()
RETURNS TABLE (
  month_label text,
  paid_count bigint,
  total_bonus_rupees bigint,
  unique_engineers bigint,
  avg_bonus_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    to_char(date_trunc('month', c.paid_at), 'YYYY-MM'),
    COUNT(*)::bigint,
    COALESCE(SUM(c.bonus_paid_rupees), 0)::bigint,
    COUNT(DISTINCT c.engineer_user_id)::bigint,
    ROUND(AVG(c.bonus_paid_rupees)::numeric, 0)
  FROM engineer_side_quest_completions c
  WHERE c.status = 'paid' AND c.paid_at IS NOT NULL
  GROUP BY date_trunc('month', c.paid_at)
  ORDER BY 1 DESC
  LIMIT 12;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_payout_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_payout_summary() TO authenticated;

-- ---------- RPC 7: approve completion (write) ----------

CREATE OR REPLACE FUNCTION founder_side_quest_approve(
  p_completion_id uuid,
  p_bonus_rupees integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_after jsonb;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE engineer_side_quest_completions
  SET status = 'approved',
      approved_at = now(),
      bonus_paid_rupees = COALESCE(p_bonus_rupees, bonus_paid_rupees, 0)
  WHERE id = p_completion_id
    AND status = 'submitted'
  RETURNING jsonb_build_object(
    'completion_id', id,
    'status', status,
    'bonus_rupees', bonus_paid_rupees,
    'approved_at', approved_at
  ) INTO v_after;

  IF v_after IS NULL THEN
    RAISE EXCEPTION 'completion not found or not in submitted state';
  END IF;

  PERFORM log_founder_side_quest_action('side_quest.approve', v_after);
  RETURN v_after;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_side_quest_approve(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_side_quest_approve(uuid, integer) TO authenticated;

COMMIT;