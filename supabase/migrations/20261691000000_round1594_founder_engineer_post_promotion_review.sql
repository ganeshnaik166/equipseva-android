BEGIN;

-- =====================================================================
-- r1594 — Founder Engineer Post-Promotion Review (T+90 day audit)
-- =====================================================================
-- When an engineer is promoted (tier upgrade), founder reviews at T+90
-- whether the promotion was right. Per-engineer scorecard + demotion
-- trigger flag. Two new tables, 7 SECDEF read RPCs, 3 write RPCs,
-- 4 log helpers. Founder-only.
-- =====================================================================

-- --- Table 1: promotion review windows ----------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_promotion_reviews_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  promoted_at timestamptz NOT NULL,
  promoted_from_tier text NOT NULL CHECK (promoted_from_tier IN ('none','aadhaar','pan','gst','bgc','pro')),
  promoted_to_tier text NOT NULL CHECK (promoted_to_tier IN ('none','aadhaar','pan','gst','bgc','pro')),
  review_due_at timestamptz NOT NULL,
  review_status text NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending','approved','flagged_demote','flagged_hold','completed')),
  reviewed_at timestamptz,
  reviewer_user_id uuid REFERENCES auth.users(id),
  reviewer_email text,
  scorecard_jobs_completed int NOT NULL DEFAULT 0,
  scorecard_avg_rating numeric(3,2),
  scorecard_disputes int NOT NULL DEFAULT 0,
  scorecard_payout_rupees bigint NOT NULL DEFAULT 0,
  demotion_recommended boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fepr_v2_engineer ON founder_engineer_promotion_reviews_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_fepr_v2_due ON founder_engineer_promotion_reviews_v2(review_due_at);
CREATE INDEX IF NOT EXISTS idx_fepr_v2_status ON founder_engineer_promotion_reviews_v2(review_status);

ALTER TABLE founder_engineer_promotion_reviews_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fepr_v2_founder_only ON founder_engineer_promotion_reviews_v2;
CREATE POLICY fepr_v2_founder_only ON founder_engineer_promotion_reviews_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- --- Table 2: review decisions audit trail ------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_promotion_decisions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES founder_engineer_promotion_reviews_v2(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('approve','demote','hold','re_review')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  decided_by uuid REFERENCES auth.users(id),
  decided_by_email text,
  rationale text,
  payload jsonb
);

CREATE INDEX IF NOT EXISTS idx_fepd_v2_review ON founder_engineer_promotion_decisions_v2(review_id);
CREATE INDEX IF NOT EXISTS idx_fepd_v2_when ON founder_engineer_promotion_decisions_v2(decided_at DESC);

ALTER TABLE founder_engineer_promotion_decisions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fepd_v2_founder_only ON founder_engineer_promotion_decisions_v2;
CREATE POLICY fepd_v2_founder_only ON founder_engineer_promotion_decisions_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- Log helpers (VOLATILE SECDEF)
-- =====================================================================
CREATE OR REPLACE FUNCTION log_founder_promotion_review_open(p_review_id uuid, p_engineer_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'promotion_review_open',
          jsonb_build_object('review_id', p_review_id, 'engineer_id', p_engineer_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_promotion_review_open(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_promotion_review_open(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_promotion_review_decide(p_review_id uuid, p_decision text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'promotion_review_decide',
          jsonb_build_object('review_id', p_review_id, 'decision', p_decision));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_promotion_review_decide(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_promotion_review_decide(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_promotion_demote_flag(p_review_id uuid, p_flagged boolean)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'promotion_demote_flag',
          jsonb_build_object('review_id', p_review_id, 'flagged', p_flagged));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_promotion_demote_flag(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_promotion_demote_flag(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_promotion_review_seed(p_count int)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'promotion_review_seed',
          jsonb_build_object('seeded_count', p_count));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_promotion_review_seed(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_promotion_review_seed(int) TO authenticated;

-- =====================================================================
-- Read RPCs (STABLE SECDEF)
-- =====================================================================

-- 1) KPI summary
CREATE OR REPLACE FUNCTION founder_promotion_review_kpis()
RETURNS TABLE(
  total_reviews int,
  pending_reviews int,
  overdue_reviews int,
  approved_reviews int,
  demote_flagged int,
  hold_flagged int,
  completed_reviews int,
  due_next_7d int,
  due_next_30d int,
  total_engineers_reviewed int,
  avg_scorecard_rating numeric,
  total_jobs_completed bigint,
  total_payout_rupees bigint,
  total_disputes bigint,
  demote_rate_pct numeric,
  approve_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE review_status='pending')::int,
    COUNT(*) FILTER (WHERE review_status='pending' AND review_due_at < now())::int,
    COUNT(*) FILTER (WHERE review_status='approved')::int,
    COUNT(*) FILTER (WHERE review_status='flagged_demote')::int,
    COUNT(*) FILTER (WHERE review_status='flagged_hold')::int,
    COUNT(*) FILTER (WHERE review_status='completed')::int,
    COUNT(*) FILTER (WHERE review_status='pending' AND review_due_at BETWEEN now() AND now()+interval '7 days')::int,
    COUNT(*) FILTER (WHERE review_status='pending' AND review_due_at BETWEEN now() AND now()+interval '30 days')::int,
    COUNT(DISTINCT engineer_id)::int,
    ROUND(AVG(scorecard_avg_rating)::numeric, 2),
    COALESCE(SUM(scorecard_jobs_completed),0)::bigint,
    COALESCE(SUM(scorecard_payout_rupees),0)::bigint,
    COALESCE(SUM(scorecard_disputes),0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE review_status IN ('approved','flagged_demote','flagged_hold','completed')) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE review_status='flagged_demote')::numeric
                 / NULLIF(COUNT(*) FILTER (WHERE review_status IN ('approved','flagged_demote','flagged_hold','completed')),0), 2)
      ELSE 0 END,
    CASE WHEN COUNT(*) FILTER (WHERE review_status IN ('approved','flagged_demote','flagged_hold','completed')) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE review_status='approved')::numeric
                 / NULLIF(COUNT(*) FILTER (WHERE review_status IN ('approved','flagged_demote','flagged_hold','completed')),0), 2)
      ELSE 0 END
  FROM founder_engineer_promotion_reviews_v2;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_kpis() TO authenticated;

-- 2) Pending reviews list
CREATE OR REPLACE FUNCTION founder_promotion_review_pending()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_email text,
  promoted_from_tier text,
  promoted_to_tier text,
  promoted_at timestamptz,
  review_due_at timestamptz,
  days_until_due numeric,
  scorecard_jobs_completed int,
  scorecard_avg_rating numeric,
  scorecard_disputes int,
  demotion_recommended boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_id,
    p.email::text,
    r.promoted_from_tier, r.promoted_to_tier, r.promoted_at, r.review_due_at,
    ROUND(EXTRACT(EPOCH FROM (r.review_due_at - now()))/86400.0, 1),
    r.scorecard_jobs_completed, r.scorecard_avg_rating, r.scorecard_disputes,
    r.demotion_recommended
  FROM founder_engineer_promotion_reviews_v2 r
  JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE r.review_status='pending'
  ORDER BY r.review_due_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_pending() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_pending() TO authenticated;

-- 3) Demote-flagged engineers
CREATE OR REPLACE FUNCTION founder_promotion_review_demote_flagged()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_email text,
  promoted_to_tier text,
  scorecard_avg_rating numeric,
  scorecard_disputes int,
  notes text,
  flagged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_id,
    p.email::text,
    r.promoted_to_tier, r.scorecard_avg_rating, r.scorecard_disputes,
    r.notes, r.reviewed_at
  FROM founder_engineer_promotion_reviews_v2 r
  JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE r.review_status='flagged_demote' OR r.demotion_recommended=true
  ORDER BY COALESCE(r.reviewed_at, r.created_at) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_demote_flagged() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_demote_flagged() TO authenticated;

-- 4) Per-engineer scorecard
CREATE OR REPLACE FUNCTION founder_promotion_review_scorecard()
RETURNS TABLE(
  engineer_id uuid,
  engineer_email text,
  cached_highest_tier text,
  jobs_last_90d bigint,
  avg_rating_last_90d numeric,
  disputes_last_90d bigint,
  payout_last_90d_rupees bigint,
  review_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id,
    p.email::text,
    e.cached_highest_tier,
    COUNT(rj.id) FILTER (WHERE rj.completed_at >= now() - interval '90 days')::bigint,
    ROUND(AVG(rj.hospital_rating) FILTER (WHERE rj.completed_at >= now() - interval '90 days')::numeric, 2),
    COUNT(rj.id) FILTER (WHERE rj.completed_at >= now() - interval '90 days' AND rj.hospital_rating IS NOT NULL AND rj.hospital_rating <= 2)::bigint,
    COALESCE(SUM(ep.amount_rupees) FILTER (WHERE ep.created_at >= now() - interval '90 days'),0)::bigint,
    COALESCE(r.review_status,'none')
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN repair_jobs rj ON rj.engineer_id = e.id
  LEFT JOIN engineer_payouts ep ON ep.engineer_user_id = e.user_id
  LEFT JOIN LATERAL (
    SELECT review_status FROM founder_engineer_promotion_reviews_v2 fr
    WHERE fr.engineer_id = e.id ORDER BY fr.created_at DESC LIMIT 1
  ) r ON true
  WHERE e.cached_highest_tier IN ('pro','bgc','gst')
  GROUP BY e.id, p.email, e.cached_highest_tier, r.review_status
  ORDER BY COUNT(rj.id) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_scorecard() TO authenticated;

-- 5) Recent decisions
CREATE OR REPLACE FUNCTION founder_promotion_review_recent_decisions()
RETURNS TABLE(
  id uuid,
  review_id uuid,
  engineer_id uuid,
  decision text,
  decided_at timestamptz,
  decided_by_email text,
  rationale text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.review_id, r.engineer_id, d.decision, d.decided_at,
    d.decided_by_email, d.rationale
  FROM founder_engineer_promotion_decisions_v2 d
  JOIN founder_engineer_promotion_reviews_v2 r ON r.id = d.review_id
  ORDER BY d.decided_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_recent_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_recent_decisions() TO authenticated;

-- 6) Tier transition stats
CREATE OR REPLACE FUNCTION founder_promotion_review_tier_stats()
RETURNS TABLE(
  promoted_from_tier text,
  promoted_to_tier text,
  total_reviews int,
  approved_count int,
  demoted_count int,
  hold_count int,
  approve_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.promoted_from_tier, r.promoted_to_tier,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE r.review_status='approved')::int,
    COUNT(*) FILTER (WHERE r.review_status='flagged_demote')::int,
    COUNT(*) FILTER (WHERE r.review_status='flagged_hold')::int,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_status='approved')::numeric / COUNT(*), 2)
      ELSE 0 END
  FROM founder_engineer_promotion_reviews_v2 r
  GROUP BY r.promoted_from_tier, r.promoted_to_tier
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_tier_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_tier_stats() TO authenticated;

-- 7) Overdue reviews
CREATE OR REPLACE FUNCTION founder_promotion_review_overdue()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_email text,
  promoted_to_tier text,
  review_due_at timestamptz,
  days_overdue numeric,
  scorecard_avg_rating numeric,
  scorecard_disputes int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_id,
    p.email::text,
    r.promoted_to_tier, r.review_due_at,
    ROUND(EXTRACT(EPOCH FROM (now() - r.review_due_at))/86400.0, 1),
    r.scorecard_avg_rating, r.scorecard_disputes
  FROM founder_engineer_promotion_reviews_v2 r
  JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE r.review_status='pending' AND r.review_due_at < now()
  ORDER BY r.review_due_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_overdue() TO authenticated;

-- =====================================================================
-- Write RPCs (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_promotion_review_decide(p_review_id uuid, p_decision text, p_rationale text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid; v_status text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_status := CASE p_decision
    WHEN 'approve' THEN 'approved'
    WHEN 'demote' THEN 'flagged_demote'
    WHEN 'hold' THEN 'flagged_hold'
    ELSE 'pending' END;
  UPDATE founder_engineer_promotion_reviews_v2
    SET review_status = v_status,
        reviewed_at = now(),
        reviewer_user_id = auth.uid(),
        reviewer_email = (auth.jwt()->>'email'),
        notes = COALESCE(p_rationale, notes),
        updated_at = now()
    WHERE id = p_review_id;
  INSERT INTO founder_engineer_promotion_decisions_v2(review_id, decision, decided_by, decided_by_email, rationale)
    VALUES (p_review_id, p_decision, auth.uid(), (auth.jwt()->>'email'), p_rationale)
    RETURNING id INTO v_id;
  PERFORM log_founder_promotion_review_decide(p_review_id, p_decision);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_decide(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_decide(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_promotion_review_set_demote_flag(p_review_id uuid, p_flagged boolean)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_engineer_promotion_reviews_v2
    SET demotion_recommended = p_flagged, updated_at = now()
    WHERE id = p_review_id;
  PERFORM log_founder_promotion_demote_flag(p_review_id, p_flagged);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_promotion_review_set_demote_flag(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_promotion_review_set_demote_flag(uuid, boolean) TO authenticated;

COMMIT;