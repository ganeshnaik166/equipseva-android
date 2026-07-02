BEGIN;

-- Board pack drafts (one per cycle, founder edits in-place before shipping)
CREATE TABLE IF NOT EXISTS founder_board_pack_drafts_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_label text NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','ready','shipped','archived')),
  executive_summary_md text NOT NULL DEFAULT '',
  pillar_growth_md text NOT NULL DEFAULT '',
  pillar_quality_md text NOT NULL DEFAULT '',
  pillar_unit_econ_md text NOT NULL DEFAULT '',
  pillar_supply_md text NOT NULL DEFAULT '',
  pillar_compliance_md text NOT NULL DEFAULT '',
  asks_md text NOT NULL DEFAULT '',
  kpi_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  shipped_at timestamptz,
  shipped_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE founder_board_pack_drafts_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fbpd_v2_founder_all ON founder_board_pack_drafts_v2;
CREATE POLICY fbpd_v2_founder_all ON founder_board_pack_drafts_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_fbpd_v2_status ON founder_board_pack_drafts_v2(status, period_end DESC);

-- Investor email-out queue (founder ships drafts here)
CREATE TABLE IF NOT EXISTS founder_board_pack_email_queue_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES founder_board_pack_drafts_v2(id) ON DELETE CASCADE,
  recipient_email text NOT NULL,
  recipient_name text,
  subject text NOT NULL,
  body_md text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','failed','cancelled')),
  queued_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  error_text text,
  queued_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE founder_board_pack_email_queue_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fbpq_v2_founder_all ON founder_board_pack_email_queue_v2;
CREATE POLICY fbpq_v2_founder_all ON founder_board_pack_email_queue_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_fbpq_v2_status ON founder_board_pack_email_queue_v2(status, queued_at DESC);
CREATE INDEX IF NOT EXISTS idx_fbpq_v2_draft ON founder_board_pack_email_queue_v2(draft_id);

-- Logging helpers (VOLATILE SECDEF)
CREATE OR REPLACE FUNCTION log_founder_board_pack_draft_created(p_draft_id uuid, p_cycle_label text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_pack_draft_created',
          jsonb_build_object('draft_id', p_draft_id, 'cycle_label', p_cycle_label));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_pack_draft_created(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_pack_draft_created(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_pack_section_edited(p_draft_id uuid, p_section text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_pack_section_edited',
          jsonb_build_object('draft_id', p_draft_id, 'section', p_section));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_pack_section_edited(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_pack_section_edited(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_pack_shipped(p_draft_id uuid, p_recipient_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_pack_shipped',
          jsonb_build_object('draft_id', p_draft_id, 'recipient_count', p_recipient_count));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_pack_shipped(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_pack_shipped(uuid, int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_board_pack_archived(p_draft_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'board_pack_archived',
          jsonb_build_object('draft_id', p_draft_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_board_pack_archived(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_board_pack_archived(uuid) TO authenticated;

-- READ RPC 1: KPI snapshot for the period
CREATE OR REPLACE FUNCTION founder_board_pack_kpi_snapshot(p_start date, p_end date)
RETURNS TABLE (
  metric text,
  value_num numeric,
  value_text text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'hospitals_active'::text, COUNT(DISTINCT o.id)::numeric, NULL::text
    FROM organizations o WHERE o.kind = 'hospital'
  UNION ALL
  SELECT 'engineers_active'::text, COUNT(*)::numeric, NULL::text FROM engineers
  UNION ALL
  SELECT 'jobs_in_period'::text, COUNT(*)::numeric, NULL::text
    FROM repair_jobs WHERE created_at::date BETWEEN p_start AND p_end
  UNION ALL
  SELECT 'gmv_rupees'::text, COALESCE(SUM(contracted_amount_rupees),0)::numeric, NULL::text
    FROM repair_jobs WHERE created_at::date BETWEEN p_start AND p_end
  UNION ALL
  SELECT 'amc_active'::text, COUNT(*)::numeric, NULL::text
    FROM amc_contracts WHERE status = 'active'
  UNION ALL
  SELECT 'avg_hospital_rating'::text, COALESCE(AVG(hospital_rating),0)::numeric, NULL::text
    FROM repair_jobs WHERE hospital_rating IS NOT NULL AND created_at::date BETWEEN p_start AND p_end;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_kpi_snapshot(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_kpi_snapshot(date, date) TO authenticated;

-- READ RPC 2: list drafts
CREATE OR REPLACE FUNCTION founder_board_pack_list_drafts()
RETURNS TABLE (
  id uuid,
  cycle_label text,
  period_start date,
  period_end date,
  status text,
  updated_at timestamptz,
  shipped_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.cycle_label, d.period_start, d.period_end, d.status, d.updated_at, d.shipped_at
    FROM founder_board_pack_drafts_v2 d
    ORDER BY d.period_end DESC, d.created_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_list_drafts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_list_drafts() TO authenticated;

-- READ RPC 3: email queue list
CREATE OR REPLACE FUNCTION founder_board_pack_list_email_queue()
RETURNS TABLE (
  id uuid,
  draft_id uuid,
  recipient_email text,
  recipient_name text,
  subject text,
  status text,
  queued_at timestamptz,
  sent_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.draft_id, q.recipient_email, q.recipient_name, q.subject, q.status, q.queued_at, q.sent_at
    FROM founder_board_pack_email_queue_v2 q
    ORDER BY q.queued_at DESC
    LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_list_email_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_list_email_queue() TO authenticated;

-- READ RPC 4: pillar growth detail
CREATE OR REPLACE FUNCTION founder_board_pack_pillar_growth(p_start date, p_end date)
RETURNS TABLE (
  bucket text,
  jobs_count bigint,
  gmv_rupees numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', rj.created_at), 'YYYY-MM')::text AS bucket,
         COUNT(*)::bigint AS jobs_count,
         COALESCE(SUM(rj.contracted_amount_rupees),0)::numeric AS gmv_rupees
    FROM repair_jobs rj
    WHERE rj.created_at::date BETWEEN p_start AND p_end
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_pillar_growth(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_pillar_growth(date, date) TO authenticated;

-- WRITE RPC 5: create draft (auto-aggregate snapshot)
CREATE OR REPLACE FUNCTION founder_board_pack_create_draft(p_cycle_label text, p_start date, p_end date)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_snapshot jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_object_agg(metric, COALESCE(value_num::text, value_text))
    INTO v_snapshot
    FROM founder_board_pack_kpi_snapshot(p_start, p_end);
  INSERT INTO founder_board_pack_drafts_v2(cycle_label, period_start, period_end, kpi_snapshot)
    VALUES (p_cycle_label, p_start, p_end, COALESCE(v_snapshot, '{}'::jsonb))
    RETURNING id INTO v_id;
  PERFORM log_founder_board_pack_draft_created(v_id, p_cycle_label);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_create_draft(text, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_create_draft(text, date, date) TO authenticated;

-- WRITE RPC 6: update section
CREATE OR REPLACE FUNCTION founder_board_pack_update_section(p_draft_id uuid, p_section text, p_md text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_section NOT IN ('executive_summary','growth','quality','unit_econ','supply','compliance','asks') THEN
    RAISE EXCEPTION 'invalid_section';
  END IF;
  UPDATE founder_board_pack_drafts_v2
    SET executive_summary_md = CASE WHEN p_section = 'executive_summary' THEN p_md ELSE executive_summary_md END,
        pillar_growth_md     = CASE WHEN p_section = 'growth' THEN p_md ELSE pillar_growth_md END,
        pillar_quality_md    = CASE WHEN p_section = 'quality' THEN p_md ELSE pillar_quality_md END,
        pillar_unit_econ_md  = CASE WHEN p_section = 'unit_econ' THEN p_md ELSE pillar_unit_econ_md END,
        pillar_supply_md     = CASE WHEN p_section = 'supply' THEN p_md ELSE pillar_supply_md END,
        pillar_compliance_md = CASE WHEN p_section = 'compliance' THEN p_md ELSE pillar_compliance_md END,
        asks_md              = CASE WHEN p_section = 'asks' THEN p_md ELSE asks_md END,
        updated_at = now()
    WHERE id = p_draft_id;
  PERFORM log_founder_board_pack_section_edited(p_draft_id, p_section);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_update_section(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_update_section(uuid, text, text) TO authenticated;

-- WRITE RPC 7: ship draft to email queue
CREATE OR REPLACE FUNCTION founder_board_pack_ship_to_queue(p_draft_id uuid, p_recipients jsonb, p_subject text)
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r jsonb;
  v_count int := 0;
  v_body text;
  v_draft founder_board_pack_drafts_v2%ROWTYPE;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT * INTO v_draft FROM founder_board_pack_drafts_v2 WHERE id = p_draft_id;
  IF v_draft.id IS NULL THEN RAISE EXCEPTION 'draft_not_found'; END IF;
  v_body := concat_ws(E'\n\n',
    '# ' || v_draft.cycle_label,
    '## Executive Summary', v_draft.executive_summary_md,
    '## Growth', v_draft.pillar_growth_md,
    '## Quality', v_draft.pillar_quality_md,
    '## Unit Econ', v_draft.pillar_unit_econ_md,
    '## Supply', v_draft.pillar_supply_md,
    '## Compliance', v_draft.pillar_compliance_md,
    '## Asks', v_draft.asks_md);
  FOR r IN SELECT * FROM jsonb_array_elements(p_recipients)
  LOOP
    INSERT INTO founder_board_pack_email_queue_v2(draft_id, recipient_email, recipient_name, subject, body_md, queued_by_user_id)
      VALUES (p_draft_id, r->>'email', r->>'name', p_subject, v_body, auth.uid());
    v_count := v_count + 1;
  END LOOP;
  UPDATE founder_board_pack_drafts_v2
    SET status = 'shipped', shipped_at = now(), shipped_by_user_id = auth.uid()
    WHERE id = p_draft_id;
  PERFORM log_founder_board_pack_shipped(p_draft_id, v_count);
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_board_pack_ship_to_queue(uuid, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_board_pack_ship_to_queue(uuid, jsonb, text) TO authenticated;

COMMIT;