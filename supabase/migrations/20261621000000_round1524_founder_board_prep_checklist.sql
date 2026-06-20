BEGIN;

-- Board meetings
CREATE TABLE IF NOT EXISTS founder_board_meetings_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_title text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  location text,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  alert_48h_sent_at timestamptz,
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_fbm_scheduled_at ON founder_board_meetings_v2(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_fbm_closed ON founder_board_meetings_v2(closed_at);

ALTER TABLE founder_board_meetings_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fbm_founder_only ON founder_board_meetings_v2;
CREATE POLICY fbm_founder_only ON founder_board_meetings_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Checklist items (12 per meeting, but flexible)
CREATE TABLE IF NOT EXISTS founder_board_checklist_items_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id uuid NOT NULL REFERENCES founder_board_meetings_v2(id) ON DELETE CASCADE,
  slot int NOT NULL,
  category text NOT NULL,
  title text NOT NULL,
  description text,
  is_done boolean NOT NULL DEFAULT false,
  done_at timestamptz,
  done_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  artifact_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meeting_id, slot)
);

CREATE INDEX IF NOT EXISTS idx_fbci_meeting ON founder_board_checklist_items_v2(meeting_id);
CREATE INDEX IF NOT EXISTS idx_fbci_done ON founder_board_checklist_items_v2(is_done);

ALTER TABLE founder_board_checklist_items_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fbci_founder_only ON founder_board_checklist_items_v2;
CREATE POLICY fbci_founder_only ON founder_board_checklist_items_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============ log helpers ============

CREATE OR REPLACE FUNCTION log_founder_board_meeting_create(p_meeting_id uuid, p_title text, p_at timestamptz)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_meeting_create',
          jsonb_build_object('meeting_id', p_meeting_id, 'title', p_title, 'scheduled_at', p_at));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_meeting_create(uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_meeting_create(uuid, text, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_item_toggle(p_item_id uuid, p_done boolean)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_item_toggle',
          jsonb_build_object('item_id', p_item_id, 'is_done', p_done));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_item_toggle(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_item_toggle(uuid, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_meeting_close(p_meeting_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_meeting_close',
          jsonb_build_object('meeting_id', p_meeting_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_meeting_close(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_meeting_close(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_alert_fired(p_meeting_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_alert_48h_fired',
          jsonb_build_object('meeting_id', p_meeting_id, 'fired_at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_alert_fired(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_alert_fired(uuid) TO authenticated;

-- ============ READ RPCs (STABLE) ============

CREATE OR REPLACE FUNCTION founder_board_prep_overview()
RETURNS TABLE (
  total_meetings int,
  upcoming_meetings int,
  closed_meetings int,
  next_meeting_at timestamptz,
  hours_to_next numeric,
  total_items int,
  done_items int,
  open_items int,
  pct_done numeric,
  meetings_in_48h int,
  meetings_with_unsent_alert int,
  avg_completion_pct numeric,
  fully_ready_meetings int,
  at_risk_meetings int,
  items_due_in_48h int,
  alerts_fired_total int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH m AS (
    SELECT * FROM founder_board_meetings_v2
  ),
  upc AS (
    SELECT * FROM m WHERE scheduled_at > now() AND closed_at IS NULL
  ),
  nxt AS (
    SELECT scheduled_at FROM upc ORDER BY scheduled_at ASC LIMIT 1
  ),
  items AS (
    SELECT i.*, mm.scheduled_at, mm.closed_at
    FROM founder_board_checklist_items_v2 i JOIN m mm ON mm.id = i.meeting_id
  ),
  per_meeting AS (
    SELECT mm.id,
           mm.scheduled_at,
           mm.closed_at,
           mm.alert_48h_sent_at,
           COUNT(i.*)::int AS total,
           COUNT(i.*) FILTER (WHERE i.is_done)::int AS done
    FROM m mm LEFT JOIN founder_board_checklist_items_v2 i ON i.meeting_id = mm.id
    GROUP BY mm.id
  )
  SELECT
    (SELECT COUNT(*)::int FROM m),
    (SELECT COUNT(*)::int FROM upc),
    (SELECT COUNT(*)::int FROM m WHERE closed_at IS NOT NULL),
    (SELECT scheduled_at FROM nxt),
    COALESCE((SELECT EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 FROM nxt), 0)::numeric,
    (SELECT COUNT(*)::int FROM items),
    (SELECT COUNT(*)::int FROM items WHERE is_done),
    (SELECT COUNT(*)::int FROM items WHERE NOT is_done),
    CASE WHEN (SELECT COUNT(*) FROM items) > 0
         THEN ROUND(100.0 * (SELECT COUNT(*) FROM items WHERE is_done) / (SELECT COUNT(*) FROM items), 1)
         ELSE 0 END,
    (SELECT COUNT(*)::int FROM upc WHERE EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48),
    (SELECT COUNT(*)::int FROM upc WHERE EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48 AND alert_48h_sent_at IS NULL),
    COALESCE((SELECT ROUND(AVG(CASE WHEN total>0 THEN 100.0*done/total ELSE 0 END)::numeric, 1) FROM per_meeting), 0),
    (SELECT COUNT(*)::int FROM per_meeting WHERE total>0 AND done=total AND closed_at IS NULL),
    (SELECT COUNT(*)::int FROM per_meeting
      WHERE closed_at IS NULL
        AND scheduled_at > now()
        AND EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 72
        AND (total = 0 OR done::numeric/NULLIF(total,0) < 0.75)),
    (SELECT COUNT(*)::int FROM items
      WHERE NOT is_done AND scheduled_at > now()
        AND EXTRACT(EPOCH FROM (scheduled_at - now()))/3600.0 <= 48),
    COALESCE((SELECT COUNT(*)::int FROM founder_action_log WHERE op_name = 'board_alert_48h_fired'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_prep_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_prep_overview() TO authenticated;

CREATE OR REPLACE FUNCTION founder_board_meetings_list()
RETURNS TABLE (
  id uuid,
  meeting_title text,
  scheduled_at timestamptz,
  location text,
  hours_until numeric,
  total_items int,
  done_items int,
  pct_done numeric,
  status text,
  alert_48h_sent_at timestamptz,
  closed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id,
         m.meeting_title,
         m.scheduled_at,
         m.location,
         (EXTRACT(EPOCH FROM (m.scheduled_at - now()))/3600.0)::numeric,
         COALESCE(COUNT(i.*)::int, 0),
         COALESCE(COUNT(i.*) FILTER (WHERE i.is_done)::int, 0),
         CASE WHEN COUNT(i.*) > 0
              THEN ROUND(100.0 * COUNT(i.*) FILTER (WHERE i.is_done) / COUNT(i.*), 1)
              ELSE 0 END,
         CASE
           WHEN m.closed_at IS NOT NULL THEN 'closed'
           WHEN m.scheduled_at < now() THEN 'overdue'
           WHEN EXTRACT(EPOCH FROM (m.scheduled_at - now()))/3600.0 <= 48 THEN 'imminent'
           ELSE 'scheduled'
         END,
         m.alert_48h_sent_at,
         m.closed_at
  FROM founder_board_meetings_v2 m
  LEFT JOIN founder_board_checklist_items_v2 i ON i.meeting_id = m.id
  GROUP BY m.id
  ORDER BY m.scheduled_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_meetings_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_meetings_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_board_checklist_for_next()
RETURNS TABLE (
  id uuid,
  meeting_id uuid,
  slot int,
  category text,
  title text,
  description text,
  is_done boolean,
  done_at timestamptz,
  artifact_url text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT m.id INTO v_id FROM founder_board_meetings_v2 m
   WHERE m.scheduled_at > now() AND m.closed_at IS NULL
   ORDER BY m.scheduled_at ASC LIMIT 1;
  RETURN QUERY
  SELECT i.id, i.meeting_id, i.slot, i.category, i.title, i.description, i.is_done, i.done_at, i.artifact_url
  FROM founder_board_checklist_items_v2 i
  WHERE i.meeting_id = v_id
  ORDER BY i.slot ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_checklist_for_next() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_checklist_for_next() TO authenticated;

CREATE OR REPLACE FUNCTION founder_board_imminent_alerts()
RETURNS TABLE (
  meeting_id uuid,
  meeting_title text,
  scheduled_at timestamptz,
  hours_until numeric,
  pct_done numeric,
  open_items int,
  alert_48h_sent_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id,
         m.meeting_title,
         m.scheduled_at,
         (EXTRACT(EPOCH FROM (m.scheduled_at - now()))/3600.0)::numeric,
         CASE WHEN COUNT(i.*) > 0
              THEN ROUND(100.0 * COUNT(i.*) FILTER (WHERE i.is_done) / COUNT(i.*), 1)
              ELSE 0 END,
         COUNT(i.*) FILTER (WHERE NOT i.is_done)::int,
         m.alert_48h_sent_at
  FROM founder_board_meetings_v2 m
  LEFT JOIN founder_board_checklist_items_v2 i ON i.meeting_id = m.id
  WHERE m.closed_at IS NULL
    AND m.scheduled_at > now()
    AND EXTRACT(EPOCH FROM (m.scheduled_at - now()))/3600.0 <= 72
  GROUP BY m.id
  ORDER BY m.scheduled_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_imminent_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_imminent_alerts() TO authenticated;

CREATE OR REPLACE FUNCTION founder_board_category_breakdown()
RETURNS TABLE (
  category text,
  total_items int,
  done_items int,
  open_items int,
  pct_done numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.category,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE i.is_done)::int,
         COUNT(*) FILTER (WHERE NOT i.is_done)::int,
         ROUND(100.0 * COUNT(*) FILTER (WHERE i.is_done) / COUNT(*), 1)
  FROM founder_board_checklist_items_v2 i
  JOIN founder_board_meetings_v2 m ON m.id = i.meeting_id
  WHERE m.closed_at IS NULL
  GROUP BY i.category
  ORDER BY pct_done ASC, category ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_category_breakdown() TO authenticated;

-- ============ WRITE RPCs (VOLATILE) ============

CREATE OR REPLACE FUNCTION founder_board_meeting_create(p_title text, p_at timestamptz, p_location text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_board_meetings_v2(meeting_title, scheduled_at, location, created_by)
  VALUES (p_title, p_at, p_location, auth.uid())
  RETURNING id INTO v_id;

  -- seed standard 12-item checklist
  INSERT INTO founder_board_checklist_items_v2(meeting_id, slot, category, title) VALUES
    (v_id, 1, 'finance', 'P&L update'),
    (v_id, 2, 'finance', 'Cash runway'),
    (v_id, 3, 'kpi', 'Headline KPIs'),
    (v_id, 4, 'kpi', 'Cohort retention'),
    (v_id, 5, 'okr', 'OKR scores'),
    (v_id, 6, 'okr', 'Next-quarter OKRs draft'),
    (v_id, 7, 'people', 'Hires + attrition'),
    (v_id, 8, 'people', 'Org chart updates'),
    (v_id, 9, 'risk', 'Top risks log'),
    (v_id, 10, 'risk', 'Compliance + legal'),
    (v_id, 11, 'asks', 'Board asks'),
    (v_id, 12, 'asks', 'Strategic decisions');

  PERFORM log_founder_board_meeting_create(v_id, p_title, p_at);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_meeting_create(text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_meeting_create(text, timestamptz, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_board_item_toggle(p_item_id uuid, p_done boolean)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_board_checklist_items_v2
     SET is_done = p_done,
         done_at = CASE WHEN p_done THEN now() ELSE NULL END,
         done_by = CASE WHEN p_done THEN auth.uid() ELSE NULL END,
         updated_at = now()
   WHERE id = p_item_id;
  PERFORM log_founder_board_item_toggle(p_item_id, p_done);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_item_toggle(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_item_toggle(uuid, boolean) TO authenticated;

COMMIT;