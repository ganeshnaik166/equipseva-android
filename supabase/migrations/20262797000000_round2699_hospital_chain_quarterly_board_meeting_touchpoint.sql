BEGIN;

-- =====================================================================
-- Round 2699 — Hospital Chain Quarterly Board Meeting Touchpoint
-- chain × board contact × meeting kind × topic × ask × commitment × follow-up
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: board meetings + contacts + kinds + topics
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS hospital_chain_board_meetings_r2699 CASCADE;
CREATE TABLE hospital_chain_board_meetings_r2699 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name      text NOT NULL,
  chain_tier      text NOT NULL CHECK (chain_tier IN ('tier1_metro','tier2_city','super_specialty','government','corporate')),
  board_contact   text NOT NULL,
  contact_role    text NOT NULL CHECK (contact_role IN ('chairman','ceo','cfo','coo','cmo','head_biomed','head_procurement','head_finance')),
  meeting_kind    text NOT NULL CHECK (meeting_kind IN ('qbr','annual','strategy','renewal','escalation','intro')),
  meeting_date    date NOT NULL,
  meeting_topic   text NOT NULL CHECK (meeting_topic IN ('amc_renewal','expansion','sla_review','pricing','new_vertical','escalation','partnership','tech_review')),
  ask_summary     text NOT NULL,
  ask_value_inr   bigint NOT NULL DEFAULT 0,
  sentiment       text NOT NULL CHECK (sentiment IN ('positive','neutral','cautious','negative')),
  outcome         text NOT NULL CHECK (outcome IN ('won','progressing','stalled','lost','pending')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_board_meetings_r2699 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_board_meetings_r2699;
CREATE POLICY founder_all ON hospital_chain_board_meetings_r2699
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_board_meetings_r2699
  (chain_name, chain_tier, board_contact, contact_role, meeting_kind, meeting_date, meeting_topic, ask_summary, ask_value_inr, sentiment, outcome)
VALUES
  ('Apollo Group',        'tier1_metro',     'Dr. Sangita Reddy',   'ceo',              'qbr',        '2026-06-12'::date, 'amc_renewal', 'Renew 47 sites AMC + add 8 new sites',         18500000, 'positive',  'progressing'),
  ('Fortis Healthcare',   'tier1_metro',     'Anil Vinayak',        'coo',              'strategy',   '2026-06-08'::date, 'expansion',   'Pan-India rollout to 62 facilities',           24200000, 'positive',  'won'),
  ('Manipal Hospitals',   'tier1_metro',     'Dilip Jose',          'cfo',              'renewal',    '2026-06-15'::date, 'pricing',     '4 percent rate hike + 24x7 SLA upgrade',        9800000, 'cautious',  'progressing'),
  ('Narayana Health',     'super_specialty', 'Dr. Devi Shetty',     'chairman',         'annual',     '2026-05-28'::date, 'new_vertical','Cardiac cath-lab AMC pilot 12 sites',          15600000, 'positive',  'progressing'),
  ('AIIMS Delhi',         'government',      'Dr. M. Srinivas',     'head_biomed',      'escalation', '2026-06-18'::date, 'escalation',  'Ventilator downtime breach response',           3200000, 'negative',  'stalled'),
  ('Max Healthcare',      'corporate',       'Abhay Soi',           'ceo',              'qbr',        '2026-06-10'::date, 'sla_review',  '99.5 percent uptime guarantee + bonded parts', 12400000, 'neutral',   'progressing'),
  ('Medanta',             'super_specialty', 'Pankaj Sahni',        'ceo',              'intro',      '2026-06-05'::date, 'partnership', 'Strategic biomed partnership 18 sites',        21000000, 'positive',  'progressing'),
  ('Tata Memorial',       'government',      'Dr. Sudeep Gupta',    'head_procurement', 'qbr',        '2026-06-14'::date, 'tech_review', 'Oncology equipment uptime audit',               4500000, 'cautious',  'pending');

-- ---------------------------------------------------------------------
-- Table 2: commitments + follow-ups
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS hospital_chain_board_commitments_r2699 CASCADE;
CREATE TABLE hospital_chain_board_commitments_r2699 (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id        uuid NOT NULL REFERENCES hospital_chain_board_meetings_r2699(id) ON DELETE CASCADE,
  chain_name        text NOT NULL,
  commitment_type   text NOT NULL CHECK (commitment_type IN ('contract','sla','pricing','rollout','escalation_close','data_room','pilot','exclusivity')),
  commitment_text   text NOT NULL,
  owner             text NOT NULL CHECK (owner IN ('founder','sales_lead','ops_lead','cs_lead','tech_lead','legal')),
  due_date          date NOT NULL,
  status            text NOT NULL CHECK (status IN ('open','in_progress','done','slipped','blocked')),
  follow_up_action  text NOT NULL,
  follow_up_date    date NOT NULL,
  blocker           text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_board_commitments_r2699 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_board_commitments_r2699;
CREATE POLICY founder_all ON hospital_chain_board_commitments_r2699
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_board_commitments_r2699
  (meeting_id, chain_name, commitment_type, commitment_text, owner, due_date, status, follow_up_action, follow_up_date, blocker)
SELECT id, 'Apollo Group', 'contract', 'Draft 55-site MSA with tier discount', 'legal', '2026-06-28'::date, 'in_progress', 'Legal review red-line MSA v3', '2026-06-24'::date, NULL
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Apollo Group'
UNION ALL
SELECT id, 'Fortis Healthcare', 'rollout', 'Phase-1 deploy 22 sites by Aug-end', 'ops_lead', '2026-08-31'::date, 'in_progress', 'Kickoff call with regional ops heads', '2026-06-25'::date, NULL
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Fortis Healthcare'
UNION ALL
SELECT id, 'Manipal Hospitals', 'pricing', 'Submit revised pricing with 24x7 add-on', 'sales_lead', '2026-06-22'::date, 'open', 'Send pricing memo + ROI deck', '2026-06-22'::date, 'CFO sign-off pending'
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Manipal Hospitals'
UNION ALL
SELECT id, 'Narayana Health', 'pilot', '12-site cath-lab pilot KPI scope', 'tech_lead', '2026-07-05'::date, 'in_progress', 'Tech-scope workshop on cath-lab uptime', '2026-06-27'::date, NULL
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Narayana Health'
UNION ALL
SELECT id, 'AIIMS Delhi', 'escalation_close', 'RCA report + service-credit memo', 'founder', '2026-06-24'::date, 'blocked', 'In-person visit with RCA + credits', '2026-06-23'::date, 'OEM bonded part ETA from Germany'
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='AIIMS Delhi'
UNION ALL
SELECT id, 'Max Healthcare', 'sla', 'Codify 99.5 percent SLA + penalty clauses', 'legal', '2026-07-01'::date, 'in_progress', 'Legal annex draft + benchmark data', '2026-06-26'::date, NULL
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Max Healthcare'
UNION ALL
SELECT id, 'Medanta', 'data_room', 'Share investor-grade uptime data room', 'cs_lead', '2026-06-26'::date, 'open', 'Generate signed data-room link 7-day expiry', '2026-06-26'::date, NULL
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Medanta'
UNION ALL
SELECT id, 'Tata Memorial', 'pilot', 'Oncology uptime audit 4 sites', 'tech_lead', '2026-07-12'::date, 'open', 'Schedule onsite audit calendar', '2026-06-30'::date, 'Procurement budget freeze'
  FROM hospital_chain_board_meetings_r2699 WHERE chain_name='Tata Memorial';

-- =====================================================================
-- RPCs
-- =====================================================================

-- RPC 1 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_kpis();
CREATE FUNCTION rpc_r2699_kpis()
RETURNS TABLE (
  total_meetings        bigint,
  unique_chains         bigint,
  total_ask_inr         bigint,
  won_ask_inr           bigint,
  progressing_ask_inr   bigint,
  open_commitments      bigint,
  slipped_commitments   bigint,
  next_7_day_followups  bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM hospital_chain_board_meetings_r2699),
    (SELECT COUNT(DISTINCT chain_name) FROM hospital_chain_board_meetings_r2699),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699 WHERE outcome='won'),
    (SELECT COALESCE(SUM(ask_value_inr),0) FROM hospital_chain_board_meetings_r2699 WHERE outcome='progressing'),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 WHERE status IN ('open','in_progress')),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 WHERE status='slipped' OR status='blocked'),
    (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699
       WHERE follow_up_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_kpis() TO authenticated;

-- RPC 2 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_meetings_list();
CREATE FUNCTION rpc_r2699_meetings_list()
RETURNS TABLE (
  id uuid, chain_name text, chain_tier text, board_contact text, contact_role text,
  meeting_kind text, meeting_date date, meeting_topic text, ask_summary text,
  ask_value_inr bigint, sentiment text, outcome text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.chain_name, m.chain_tier, m.board_contact, m.contact_role,
         m.meeting_kind, m.meeting_date, m.meeting_topic, m.ask_summary,
         m.ask_value_inr, m.sentiment, m.outcome
  FROM hospital_chain_board_meetings_r2699 m
  ORDER BY m.meeting_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_meetings_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_meetings_list() TO authenticated;

-- RPC 3 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_commitments_list();
CREATE FUNCTION rpc_r2699_commitments_list()
RETURNS TABLE (
  id uuid, chain_name text, commitment_type text, commitment_text text,
  owner text, due_date date, status text, follow_up_action text,
  follow_up_date date, blocker text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.commitment_type, c.commitment_text, c.owner,
         c.due_date, c.status, c.follow_up_action, c.follow_up_date, c.blocker
  FROM hospital_chain_board_commitments_r2699 c
  ORDER BY c.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_commitments_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_commitments_list() TO authenticated;

-- RPC 4 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_by_chain();
CREATE FUNCTION rpc_r2699_by_chain()
RETURNS TABLE (
  chain_name text, meetings bigint, total_ask_inr bigint,
  won_inr bigint, open_commits bigint, blocked_commits bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.chain_name,
         COUNT(*)::bigint,
         COALESCE(SUM(m.ask_value_inr),0),
         COALESCE(SUM(m.ask_value_inr) FILTER (WHERE m.outcome='won'),0),
         (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 c
            WHERE c.chain_name=m.chain_name AND c.status IN ('open','in_progress'))::bigint,
         (SELECT COUNT(*) FROM hospital_chain_board_commitments_r2699 c
            WHERE c.chain_name=m.chain_name AND c.status='blocked')::bigint
  FROM hospital_chain_board_meetings_r2699 m
  GROUP BY m.chain_name
  ORDER BY COALESCE(SUM(m.ask_value_inr),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_by_chain() TO authenticated;

-- RPC 5 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_by_topic();
CREATE FUNCTION rpc_r2699_by_topic()
RETURNS TABLE (
  meeting_topic text, meetings bigint, total_ask_inr bigint, won_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.meeting_topic,
         COUNT(*)::bigint,
         COALESCE(SUM(m.ask_value_inr),0),
         ROUND(100.0 * COUNT(*) FILTER (WHERE m.outcome='won') / NULLIF(COUNT(*),0), 1)
  FROM hospital_chain_board_meetings_r2699 m
  GROUP BY m.meeting_topic
  ORDER BY COALESCE(SUM(m.ask_value_inr),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_by_topic() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_by_topic() TO authenticated;

-- RPC 6 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_upcoming_followups();
CREATE FUNCTION rpc_r2699_upcoming_followups()
RETURNS TABLE (
  id uuid, chain_name text, follow_up_action text, follow_up_date date,
  owner text, status text, days_until int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.follow_up_action, c.follow_up_date, c.owner, c.status,
         (c.follow_up_date - CURRENT_DATE)::int
  FROM hospital_chain_board_commitments_r2699 c
  WHERE c.follow_up_date >= CURRENT_DATE - 30
  ORDER BY c.follow_up_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_upcoming_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_upcoming_followups() TO authenticated;

-- RPC 7 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_blockers();
CREATE FUNCTION rpc_r2699_blockers()
RETURNS TABLE (
  id uuid, chain_name text, commitment_text text, owner text,
  due_date date, blocker text, follow_up_date date
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.chain_name, c.commitment_text, c.owner, c.due_date, c.blocker, c.follow_up_date
  FROM hospital_chain_board_commitments_r2699 c
  WHERE c.blocker IS NOT NULL OR c.status IN ('blocked','slipped')
  ORDER BY c.due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_blockers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_blockers() TO authenticated;

-- RPC 8 -----------------------------------------------------
DROP FUNCTION IF EXISTS rpc_r2699_by_owner();
CREATE FUNCTION rpc_r2699_by_owner()
RETURNS TABLE (
  owner text, open_count bigint, in_progress_count bigint, blocked_count bigint, total_commits bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.owner,
         COUNT(*) FILTER (WHERE c.status='open')::bigint,
         COUNT(*) FILTER (WHERE c.status='in_progress')::bigint,
         COUNT(*) FILTER (WHERE c.status='blocked')::bigint,
         COUNT(*)::bigint
  FROM hospital_chain_board_commitments_r2699 c
  GROUP BY c.owner
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2699_by_owner() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2699_by_owner() TO authenticated;

COMMIT;
