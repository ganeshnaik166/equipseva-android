BEGIN;

-- ============================================================================
-- r1670 Founder Weekly No-Meeting Block
-- Founder protects deep-work blocks: opt-out + reschedule queue
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_focus_blocks_r1670 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  block_start time NOT NULL,
  block_end time NOT NULL,
  label text NOT NULL,
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  recurring boolean NOT NULL DEFAULT true,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_focus_block_violations_r1670 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  block_id uuid NOT NULL REFERENCES founder_focus_blocks_r1670(id) ON DELETE CASCADE,
  attempted_meeting_title text NOT NULL,
  requested_by_email text NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT now(),
  decision text CHECK (decision IN ('declined','accepted_with_reschedule','accepted')),
  alt_time timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_focus_blocks_r1670_dow ON founder_focus_blocks_r1670(day_of_week) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_focus_block_violations_r1670_block ON founder_focus_block_violations_r1670(block_id);
CREATE INDEX IF NOT EXISTS idx_focus_block_violations_r1670_decision ON founder_focus_block_violations_r1670(decision);
CREATE INDEX IF NOT EXISTS idx_focus_block_violations_r1670_requested_at ON founder_focus_block_violations_r1670(requested_at DESC);

ALTER TABLE founder_focus_blocks_r1670 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_focus_block_violations_r1670 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS focus_blocks_r1670_founder_all ON founder_focus_blocks_r1670;
CREATE POLICY focus_blocks_r1670_founder_all ON founder_focus_blocks_r1670
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS focus_block_violations_r1670_founder_all ON founder_focus_block_violations_r1670;
CREATE POLICY focus_block_violations_r1670_founder_all ON founder_focus_block_violations_r1670
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_blocks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_blocks_r1670()
RETURNS TABLE (
  id uuid,
  block_start time,
  block_end time,
  label text,
  day_of_week int,
  recurring boolean,
  active boolean,
  violation_count bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.block_start,
    b.block_end,
    b.label,
    b.day_of_week,
    b.recurring,
    b.active,
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 v WHERE v.block_id = b.id),
    b.created_at
  FROM founder_focus_blocks_r1670 b
  ORDER BY b.day_of_week, b.block_start;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_blocks_r1670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_blocks_r1670() TO authenticated;

-- ============================================================================
-- RPC 2: add_block
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_block_r1670(
  p_block_start time,
  p_block_end time,
  p_label text,
  p_day_of_week int,
  p_recurring boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_block_end <= p_block_start THEN
    RAISE EXCEPTION 'block_end must be after block_start';
  END IF;

  INSERT INTO founder_focus_blocks_r1670(block_start, block_end, label, day_of_week, recurring)
  VALUES (p_block_start, p_block_end, p_label, p_day_of_week, p_recurring)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1670_add_block',
    jsonb_build_object(
      'block_id', v_id,
      'label', p_label,
      'day_of_week', p_day_of_week,
      'block_start', p_block_start,
      'block_end', p_block_end,
      'recurring', p_recurring
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_block_r1670(time, time, text, int, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_block_r1670(time, time, text, int, boolean) TO authenticated;

-- ============================================================================
-- RPC 3: list_violations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_violations_r1670()
RETURNS TABLE (
  id uuid,
  block_id uuid,
  block_label text,
  block_day_of_week int,
  attempted_meeting_title text,
  requested_by_email text,
  requested_at timestamptz,
  decision text,
  alt_time timestamptz,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    v.id,
    v.block_id,
    b.label,
    b.day_of_week,
    v.attempted_meeting_title,
    v.requested_by_email,
    v.requested_at,
    v.decision,
    v.alt_time,
    v.decided_at
  FROM founder_focus_block_violations_r1670 v
  JOIN founder_focus_blocks_r1670 b ON b.id = v.block_id
  ORDER BY v.requested_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_violations_r1670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_violations_r1670() TO authenticated;

-- ============================================================================
-- RPC 4: record_violation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_violation_r1670(
  p_block_id uuid,
  p_attempted_meeting_title text,
  p_requested_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO founder_focus_block_violations_r1670(block_id, attempted_meeting_title, requested_by_email)
  VALUES (p_block_id, p_attempted_meeting_title, p_requested_by_email)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1670_record_violation',
    jsonb_build_object(
      'violation_id', v_id,
      'block_id', p_block_id,
      'meeting_title', p_attempted_meeting_title,
      'requested_by', p_requested_by_email
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_violation_r1670(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_violation_r1670(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: decide_violation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.decide_violation_r1670(
  p_violation_id uuid,
  p_decision text,
  p_alt_time timestamptz DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_decision NOT IN ('declined','accepted_with_reschedule','accepted') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  UPDATE founder_focus_block_violations_r1670
  SET decision = p_decision,
      alt_time = p_alt_time,
      decided_at = now(),
      updated_at = now()
  WHERE id = p_violation_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1670_decide_violation',
    jsonb_build_object(
      'violation_id', p_violation_id,
      'decision', p_decision,
      'alt_time', p_alt_time
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.decide_violation_r1670(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decide_violation_r1670(uuid, text, timestamptz) TO authenticated;

-- ============================================================================
-- RPC 6: weekly_block_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_block_summary_r1670()
RETURNS TABLE (
  total_blocks bigint,
  active_blocks bigint,
  total_violations_7d bigint,
  declined_7d bigint,
  accepted_with_reschedule_7d bigint,
  accepted_7d bigint,
  pending_7d bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM founder_focus_blocks_r1670),
    (SELECT COUNT(*) FROM founder_focus_blocks_r1670 WHERE active = true),
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 WHERE requested_at >= now() - interval '7 days'),
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 WHERE requested_at >= now() - interval '7 days' AND decision = 'declined'),
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 WHERE requested_at >= now() - interval '7 days' AND decision = 'accepted_with_reschedule'),
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 WHERE requested_at >= now() - interval '7 days' AND decision = 'accepted'),
    (SELECT COUNT(*) FROM founder_focus_block_violations_r1670 WHERE requested_at >= now() - interval '7 days' AND decision IS NULL);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weekly_block_summary_r1670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_block_summary_r1670() TO authenticated;

-- ============================================================================
-- RPC 7: decline_rate
-- ============================================================================
CREATE OR REPLACE FUNCTION public.decline_rate_r1670()
RETURNS TABLE (
  block_id uuid,
  label text,
  day_of_week int,
  total_violations bigint,
  declined_count bigint,
  decline_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.label,
    b.day_of_week,
    (COUNT(v.id))::bigint,
    (COUNT(*) FILTER (WHERE v.decision = 'declined'))::bigint,
    CASE
      WHEN COUNT(v.id) = 0 THEN 0::numeric
      ELSE ROUND(100.0 * (COUNT(*) FILTER (WHERE v.decision = 'declined'))::numeric / COUNT(v.id)::numeric, 1)
    END
  FROM founder_focus_blocks_r1670 b
  LEFT JOIN founder_focus_block_violations_r1670 v ON v.block_id = b.id
  GROUP BY b.id, b.label, b.day_of_week
  ORDER BY 6 DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.decline_rate_r1670() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decline_rate_r1670() TO authenticated;

COMMIT;