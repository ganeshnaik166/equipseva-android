BEGIN;

CREATE TABLE IF NOT EXISTS founder_onboarding_hires (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_name text NOT NULL,
  hire_email text NOT NULL,
  role_title text NOT NULL,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  mentor_name text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','offboarded')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_onboarding_hires_status ON founder_onboarding_hires(status);
CREATE INDEX IF NOT EXISTS idx_founder_onboarding_hires_start ON founder_onboarding_hires(start_date DESC);

ALTER TABLE founder_onboarding_hires ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_onboarding_hires_founder_only ON founder_onboarding_hires;
CREATE POLICY founder_onboarding_hires_founder_only ON founder_onboarding_hires
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_onboarding_checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hire_id uuid NOT NULL REFERENCES founder_onboarding_hires(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('hardware','accounts','payroll','people','goals','compliance')),
  item_label text NOT NULL,
  item_order int NOT NULL DEFAULT 0,
  done boolean NOT NULL DEFAULT false,
  done_at timestamptz,
  done_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_onboarding_items_hire ON founder_onboarding_checklist_items(hire_id);
CREATE INDEX IF NOT EXISTS idx_founder_onboarding_items_done ON founder_onboarding_checklist_items(done);

ALTER TABLE founder_onboarding_checklist_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_onboarding_items_founder_only ON founder_onboarding_checklist_items;
CREATE POLICY founder_onboarding_items_founder_only ON founder_onboarding_checklist_items
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- helper: seed 30 standard checklist items for a hire
CREATE OR REPLACE FUNCTION fn_founder_onboarding_seed_items(p_hire_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO founder_onboarding_checklist_items (hire_id, category, item_label, item_order) VALUES
    (p_hire_id, 'hardware', 'Order laptop (MacBook Pro 14)', 1),
    (p_hire_id, 'hardware', 'Order monitor + keyboard + mouse', 2),
    (p_hire_id, 'hardware', 'Ship welcome kit', 3),
    (p_hire_id, 'hardware', 'Phone + SIM provisioned', 4),
    (p_hire_id, 'hardware', 'Office access card issued', 5),
    (p_hire_id, 'accounts', 'Google Workspace email created', 6),
    (p_hire_id, 'accounts', 'Slack invite sent', 7),
    (p_hire_id, 'accounts', 'GitHub org invite', 8),
    (p_hire_id, 'accounts', 'Supabase + Vercel access', 9),
    (p_hire_id, 'accounts', '1Password vault shared', 10),
    (p_hire_id, 'accounts', 'Notion workspace invite', 11),
    (p_hire_id, 'accounts', 'Figma seat assigned', 12),
    (p_hire_id, 'payroll', 'Collect PAN + Aadhaar', 13),
    (p_hire_id, 'payroll', 'Bank account collected', 14),
    (p_hire_id, 'payroll', 'Offer letter signed', 15),
    (p_hire_id, 'payroll', 'NDA signed', 16),
    (p_hire_id, 'payroll', 'Add to payroll system', 17),
    (p_hire_id, 'payroll', 'PF + ESIC enrollment', 18),
    (p_hire_id, 'payroll', 'Health insurance enrollment', 19),
    (p_hire_id, 'people', 'Mentor pair assigned', 20),
    (p_hire_id, 'people', 'Day-1 founder coffee scheduled', 21),
    (p_hire_id, 'people', 'Team intro in all-hands', 22),
    (p_hire_id, 'people', 'Shadow 2 customer calls', 23),
    (p_hire_id, 'goals', 'First-week goals doc shared', 24),
    (p_hire_id, 'goals', '30-day goals defined', 25),
    (p_hire_id, 'goals', '60-day goals defined', 26),
    (p_hire_id, 'goals', '90-day goals defined', 27),
    (p_hire_id, 'compliance', 'DPDP training completed', 28),
    (p_hire_id, 'compliance', 'Security policy acknowledged', 29),
    (p_hire_id, 'compliance', 'Code-of-conduct signed', 30)
  ON CONFLICT DO NOTHING;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_seed_items(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_seed_items(uuid) TO authenticated;

-- RPC 1: create hire + seed 30 items
CREATE OR REPLACE FUNCTION fn_founder_onboarding_create_hire(
  p_hire_name text,
  p_hire_email text,
  p_role_title text,
  p_start_date date,
  p_mentor_name text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO founder_onboarding_hires (hire_name, hire_email, role_title, start_date, mentor_name)
  VALUES (p_hire_name, p_hire_email, p_role_title, COALESCE(p_start_date, CURRENT_DATE), p_mentor_name)
  RETURNING id INTO v_id;

  PERFORM fn_founder_onboarding_seed_items(v_id);

  INSERT INTO founder_action_log (action_type, payload, actor_email)
  VALUES ('founder_onboarding_create_hire',
          jsonb_build_object('hire_id', v_id, 'name', p_hire_name, 'role', p_role_title),
          (auth.jwt()->>'email'));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_create_hire(text, text, text, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_create_hire(text, text, text, date, text) TO authenticated;

-- RPC 2: toggle a checklist item
CREATE OR REPLACE FUNCTION fn_founder_onboarding_toggle_item(p_item_id uuid, p_done boolean, p_note text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE founder_onboarding_checklist_items
     SET done = p_done,
         done_at = CASE WHEN p_done THEN now() ELSE NULL END,
         done_note = p_note
   WHERE id = p_item_id;

  INSERT INTO founder_action_log (action_type, payload, actor_email)
  VALUES ('founder_onboarding_toggle_item',
          jsonb_build_object('item_id', p_item_id, 'done', p_done),
          (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_toggle_item(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_toggle_item(uuid, boolean, text) TO authenticated;

-- RPC 3: mark hire completed / offboarded
CREATE OR REPLACE FUNCTION fn_founder_onboarding_set_status(p_hire_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('active','completed','offboarded') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE founder_onboarding_hires
     SET status = p_status, updated_at = now()
   WHERE id = p_hire_id;

  INSERT INTO founder_action_log (action_type, payload, actor_email)
  VALUES ('founder_onboarding_set_status',
          jsonb_build_object('hire_id', p_hire_id, 'status', p_status),
          (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_set_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_set_status(uuid, text) TO authenticated;

-- RPC 4: list hires with progress
CREATE OR REPLACE FUNCTION fn_founder_onboarding_list_hires()
RETURNS TABLE (
  id uuid,
  hire_name text,
  hire_email text,
  role_title text,
  start_date date,
  mentor_name text,
  status text,
  total_items int,
  done_items int,
  pct_done int,
  days_since_start int
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
  SELECT h.id,
         h.hire_name,
         h.hire_email,
         h.role_title,
         h.start_date,
         h.mentor_name,
         h.status,
         (COUNT(i.*))::int AS total_items,
         (COUNT(*) FILTER (WHERE i.done))::int AS done_items,
         CASE WHEN COUNT(i.*) = 0 THEN 0
              ELSE ((COUNT(*) FILTER (WHERE i.done))::numeric * 100 / COUNT(i.*))::int
         END AS pct_done,
         (CURRENT_DATE - h.start_date)::int AS days_since_start
    FROM founder_onboarding_hires h
    LEFT JOIN founder_onboarding_checklist_items i ON i.hire_id = h.id
   GROUP BY h.id
   ORDER BY h.start_date DESC, h.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_list_hires() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_list_hires() TO authenticated;

-- RPC 5: list checklist items for a hire
CREATE OR REPLACE FUNCTION fn_founder_onboarding_list_items(p_hire_id uuid)
RETURNS TABLE (
  id uuid,
  category text,
  item_label text,
  item_order int,
  done boolean,
  done_at timestamptz,
  done_note text
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
  SELECT i.id, i.category, i.item_label, i.item_order, i.done, i.done_at, i.done_note
    FROM founder_onboarding_checklist_items i
   WHERE i.hire_id = p_hire_id
   ORDER BY i.item_order ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_list_items(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_list_items(uuid) TO authenticated;

-- RPC 6: category rollup for a hire
CREATE OR REPLACE FUNCTION fn_founder_onboarding_category_rollup(p_hire_id uuid)
RETURNS TABLE (
  category text,
  total_items int,
  done_items int,
  pct_done int
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
  SELECT i.category,
         (COUNT(*))::int AS total_items,
         (COUNT(*) FILTER (WHERE i.done))::int AS done_items,
         CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ((COUNT(*) FILTER (WHERE i.done))::numeric * 100 / COUNT(*))::int
         END AS pct_done
    FROM founder_onboarding_checklist_items i
   WHERE i.hire_id = p_hire_id
   GROUP BY i.category
   ORDER BY i.category ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_category_rollup(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_category_rollup(uuid) TO authenticated;

-- RPC 7: org-wide summary
CREATE OR REPLACE FUNCTION fn_founder_onboarding_summary()
RETURNS TABLE (
  active_hires int,
  completed_hires int,
  offboarded_hires int,
  total_items int,
  done_items int,
  avg_pct_done_active int,
  stalled_hires int
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
    (SELECT (COUNT(*) FILTER (WHERE status='active'))::int FROM founder_onboarding_hires),
    (SELECT (COUNT(*) FILTER (WHERE status='completed'))::int FROM founder_onboarding_hires),
    (SELECT (COUNT(*) FILTER (WHERE status='offboarded'))::int FROM founder_onboarding_hires),
    (SELECT (COUNT(*))::int FROM founder_onboarding_checklist_items),
    (SELECT (COUNT(*) FILTER (WHERE done))::int FROM founder_onboarding_checklist_items),
    (SELECT COALESCE(AVG(pct)::int, 0) FROM (
        SELECT CASE WHEN COUNT(i.*) = 0 THEN 0
                    ELSE ((COUNT(*) FILTER (WHERE i.done))::numeric * 100 / COUNT(i.*))::int
               END AS pct
          FROM founder_onboarding_hires h
          LEFT JOIN founder_onboarding_checklist_items i ON i.hire_id = h.id
         WHERE h.status='active'
         GROUP BY h.id
    ) q),
    (SELECT (COUNT(*))::int FROM founder_onboarding_hires h
       WHERE h.status='active'
         AND (CURRENT_DATE - h.start_date) > 14
         AND EXISTS (SELECT 1 FROM founder_onboarding_checklist_items i
                      WHERE i.hire_id = h.id AND NOT i.done));
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_founder_onboarding_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_founder_onboarding_summary() TO authenticated;

COMMIT;