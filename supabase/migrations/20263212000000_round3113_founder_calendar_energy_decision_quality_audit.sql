-- Round 3113: Founder Quarterly Strategic Engineer-Founder Founder Calendar Energy + Decision-Quality Audit
-- Scope: Founder calendar audit — meeting type x prep x outcome x decision quality x interruptions x deep-work blocks x delegate vs defend candidates.

BEGIN;

-- ============================================================================
-- TABLE 1: founder_calendar_meetings_r3113
-- One row per audited meeting on the founder calendar over the quarter.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_calendar_meetings_r3113 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  meeting_code text NOT NULL UNIQUE,
  meeting_title text NOT NULL,
  meeting_type text NOT NULL CHECK (meeting_type IN (
    'investor_update','hospital_chain_sales','engineer_1on1','team_standup',
    'product_review','board_prep','customer_escalation','partner_negotiation',
    'recruiting_interview','vendor_review','compliance_review','press_pr'
  )),
  meeting_format text NOT NULL CHECK (meeting_format IN (
    'in_person','video_call','phone_call','hybrid','site_visit'
  )),
  scheduled_at timestamptz NOT NULL,
  duration_minutes integer NOT NULL CHECK (duration_minutes > 0 AND duration_minutes <= 600),
  attendee_count integer NOT NULL CHECK (attendee_count >= 1 AND attendee_count <= 100),
  prep_minutes integer NOT NULL CHECK (prep_minutes >= 0),
  prep_quality text NOT NULL CHECK (prep_quality IN ('none','rushed','adequate','thorough','exhaustive')),
  agenda_clarity text NOT NULL CHECK (agenda_clarity IN ('absent','vague','clear','crystal_clear')),
  energy_drain_score smallint NOT NULL CHECK (energy_drain_score BETWEEN 1 AND 10),
  energy_gain_score smallint NOT NULL CHECK (energy_gain_score BETWEEN 1 AND 10),
  decision_quality_rating text NOT NULL CHECK (decision_quality_rating IN (
    'no_decision','poor','adequate','strong','exceptional'
  )),
  outcome_status text NOT NULL CHECK (outcome_status IN (
    'cancelled','no_show','rambled','informational','aligned','decided','closed_deal'
  )),
  interruptions_count integer NOT NULL DEFAULT 0 CHECK (interruptions_count >= 0),
  follow_up_actions integer NOT NULL DEFAULT 0 CHECK (follow_up_actions >= 0),
  delegate_candidate boolean NOT NULL DEFAULT false,
  defend_candidate boolean NOT NULL DEFAULT false,
  kill_candidate boolean NOT NULL DEFAULT false,
  founder_must_attend boolean NOT NULL DEFAULT false,
  estimated_revenue_impact_rupees bigint NOT NULL DEFAULT 0,
  audit_notes text,
  audited_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcm_r3113_type ON public.founder_calendar_meetings_r3113(meeting_type);
CREATE INDEX IF NOT EXISTS idx_fcm_r3113_scheduled ON public.founder_calendar_meetings_r3113(scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcm_r3113_decision ON public.founder_calendar_meetings_r3113(decision_quality_rating);

ALTER TABLE public.founder_calendar_meetings_r3113 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- TABLE 2: founder_deep_work_blocks_r3113
-- Tracks deep-work blocks vs reactive blocks, interruptions, output quality.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_deep_work_blocks_r3113 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  block_code text NOT NULL UNIQUE,
  block_label text NOT NULL,
  block_category text NOT NULL CHECK (block_category IN (
    'deep_strategic','deep_writing','deep_review','deep_coding',
    'reactive_inbox','reactive_slack','reactive_calls','admin_ops',
    'recovery_walk','recovery_lunch'
  )),
  block_start timestamptz NOT NULL,
  block_end timestamptz NOT NULL,
  planned_minutes integer NOT NULL CHECK (planned_minutes > 0),
  actual_minutes integer NOT NULL CHECK (actual_minutes >= 0),
  interruptions_count integer NOT NULL DEFAULT 0 CHECK (interruptions_count >= 0),
  output_quality text NOT NULL CHECK (output_quality IN (
    'wasted','poor','passable','good','excellent','breakthrough'
  )),
  energy_level_start smallint NOT NULL CHECK (energy_level_start BETWEEN 1 AND 10),
  energy_level_end smallint NOT NULL CHECK (energy_level_end BETWEEN 1 AND 10),
  context_switch_cost_minutes integer NOT NULL DEFAULT 0 CHECK (context_switch_cost_minutes >= 0),
  protected_block boolean NOT NULL DEFAULT false,
  related_meeting_id uuid REFERENCES public.founder_calendar_meetings_r3113(id) ON DELETE SET NULL,
  output_artifact_url text,
  block_notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdwb_r3113_category ON public.founder_deep_work_blocks_r3113(block_category);
CREATE INDEX IF NOT EXISTS idx_fdwb_r3113_start ON public.founder_deep_work_blocks_r3113(block_start DESC);
CREATE INDEX IF NOT EXISTS idx_fdwb_r3113_quality ON public.founder_deep_work_blocks_r3113(output_quality);

ALTER TABLE public.founder_deep_work_blocks_r3113 ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_org_id uuid;
BEGIN
  SELECT id INTO v_org_id FROM public.organizations ORDER BY created_at LIMIT 1;
  IF v_org_id IS NULL THEN
    RAISE NOTICE 'no organizations row found, skipping seed';
    RETURN;
  END IF;

  INSERT INTO public.founder_calendar_meetings_r3113 (
    organization_id, meeting_code, meeting_title, meeting_type, meeting_format,
    scheduled_at, duration_minutes, attendee_count, prep_minutes, prep_quality,
    agenda_clarity, energy_drain_score, energy_gain_score, decision_quality_rating,
    outcome_status, interruptions_count, follow_up_actions,
    delegate_candidate, defend_candidate, kill_candidate, founder_must_attend,
    estimated_revenue_impact_rupees, audit_notes
  ) VALUES
    (v_org_id, 'MTG-3113-001', 'Series A lead VC quarterly update', 'investor_update', 'video_call',
     now() - interval '85 days', 60, 4, 180, 'thorough', 'crystal_clear', 5, 8, 'strong',
     'aligned', 1, 6, false, true, false, true, 25000000, 'High-value; founder must attend.'),
    (v_org_id, 'MTG-3113-002', 'Apollo Hospitals Hyderabad chain pitch', 'hospital_chain_sales', 'in_person',
     now() - interval '78 days', 90, 6, 240, 'exhaustive', 'crystal_clear', 6, 9, 'exceptional',
     'closed_deal', 0, 12, false, true, false, true, 8500000, 'Closed 14-site AMC; defend at all costs.'),
    (v_org_id, 'MTG-3113-003', 'Engineer 1:1 with senior tier-A bio-med', 'engineer_1on1', 'video_call',
     now() - interval '70 days', 30, 2, 15, 'adequate', 'clear', 3, 7, 'strong',
     'aligned', 0, 3, false, true, false, true, 0, 'Retention signal; keep monthly cadence.'),
    (v_org_id, 'MTG-3113-004', 'Daily ops standup (delegate-ready)', 'team_standup', 'video_call',
     now() - interval '65 days', 30, 8, 0, 'none', 'vague', 7, 3, 'no_decision',
     'rambled', 4, 1, true, false, false, false, 0, 'Delegate to COO; founder presence pointless.'),
    (v_org_id, 'MTG-3113-005', 'Engineer rating system v3 product review', 'product_review', 'hybrid',
     now() - interval '60 days', 75, 5, 90, 'thorough', 'clear', 4, 8, 'strong',
     'decided', 2, 7, false, true, false, true, 1200000, 'Decision lock; rollout in two weeks.'),
    (v_org_id, 'MTG-3113-006', 'Board prep deck rehearsal', 'board_prep', 'video_call',
     now() - interval '55 days', 120, 3, 360, 'exhaustive', 'crystal_clear', 6, 6, 'strong',
     'aligned', 0, 9, false, true, false, true, 0, 'Necessary evil; cannot skip.'),
    (v_org_id, 'MTG-3113-007', 'Manipal Bangalore escalation call', 'customer_escalation', 'phone_call',
     now() - interval '50 days', 45, 4, 30, 'rushed', 'clear', 8, 4, 'adequate',
     'aligned', 3, 5, false, true, false, true, -450000, 'Saved 8-site AMC; founder voice mattered.'),
    (v_org_id, 'MTG-3113-008', 'Vendor MoU - Karl Storz spare-parts pricing', 'partner_negotiation', 'in_person',
     now() - interval '45 days', 90, 5, 120, 'thorough', 'crystal_clear', 5, 7, 'exceptional',
     'closed_deal', 1, 8, false, true, false, true, 3200000, 'Locked 18% supplier discount.'),
    (v_org_id, 'MTG-3113-009', 'Field engineer recruiting - tier-A candidate', 'recruiting_interview', 'video_call',
     now() - interval '40 days', 60, 2, 45, 'adequate', 'clear', 4, 6, 'strong',
     'decided', 0, 4, false, true, false, false, 0, 'Hired; could have delegated final round to ops head.'),
    (v_org_id, 'MTG-3113-010', 'Cashfree onboarding checkpoint', 'vendor_review', 'video_call',
     now() - interval '35 days', 45, 3, 20, 'rushed', 'vague', 6, 4, 'no_decision',
     'informational', 5, 2, true, false, false, false, 0, 'Pure status update; delegate to finance.'),
    (v_org_id, 'MTG-3113-011', 'DPDP grievance officer compliance sync', 'compliance_review', 'video_call',
     now() - interval '30 days', 30, 2, 30, 'adequate', 'clear', 3, 5, 'adequate',
     'aligned', 0, 3, true, false, false, false, 0, 'Delegate to legal counsel.'),
    (v_org_id, 'MTG-3113-012', 'TechCrunch India profile interview', 'press_pr', 'phone_call',
     now() - interval '25 days', 45, 2, 60, 'thorough', 'clear', 5, 8, 'strong',
     'closed_deal', 0, 2, false, true, false, true, 0, 'Brand amplifier; only founder voice works.'),
    (v_org_id, 'MTG-3113-013', 'Random LinkedIn intro - undefined agenda', 'investor_update', 'video_call',
     now() - interval '20 days', 30, 2, 5, 'none', 'absent', 9, 2, 'no_decision',
     'rambled', 6, 0, false, false, true, false, 0, 'KILL: no agenda, no decision, drained 30 min.'),
    (v_org_id, 'MTG-3113-014', 'Fortis Mumbai chain renewal review', 'hospital_chain_sales', 'site_visit',
     now() - interval '15 days', 180, 7, 300, 'exhaustive', 'crystal_clear', 7, 9, 'exceptional',
     'closed_deal', 1, 11, false, true, false, true, 15600000, 'Renewed 22-site AMC; site visit was decisive.'),
    (v_org_id, 'MTG-3113-015', 'Weekly all-hands standup', 'team_standup', 'video_call',
     now() - interval '10 days', 60, 22, 10, 'rushed', 'vague', 8, 4, 'no_decision',
     'informational', 7, 0, true, false, false, false, 0, 'Delegate to ops head; founder cameo monthly only.');

  INSERT INTO public.founder_deep_work_blocks_r3113 (
    organization_id, block_code, block_label, block_category, block_start, block_end,
    planned_minutes, actual_minutes, interruptions_count, output_quality,
    energy_level_start, energy_level_end, context_switch_cost_minutes,
    protected_block, output_artifact_url, block_notes
  ) VALUES
    (v_org_id, 'DWB-3113-001', 'Q3 board memo draft - morning deep work', 'deep_writing',
     now() - interval '84 days 4 hours', now() - interval '84 days 1 hour',
     180, 175, 1, 'breakthrough', 9, 7, 8, true,
     'https://docs.example.com/q3-board-memo', 'Protected 4-7am block; phone in another room.'),
    (v_org_id, 'DWB-3113-002', 'AMC pricing model v2 spreadsheet rebuild', 'deep_strategic',
     now() - interval '80 days 5 hours', now() - interval '80 days 2 hours',
     180, 165, 2, 'excellent', 8, 6, 12, true,
     'https://sheets.example.com/amc-pricing-v2', 'Two slack pings broke flow but recovered.'),
    (v_org_id, 'DWB-3113-003', 'Inbox triage - reactive sprint', 'reactive_inbox',
     now() - interval '76 days 8 hours', now() - interval '76 days 7 hours',
     60, 90, 12, 'poor', 6, 3, 35, false,
     NULL, 'Mid-day inbox dive cost 90min + 35min context-switch.'),
    (v_org_id, 'DWB-3113-004', 'Founder essay - investor narrative refresh', 'deep_writing',
     now() - interval '72 days 4 hours', now() - interval '72 days 2 hours',
     120, 120, 0, 'breakthrough', 9, 8, 0, true,
     'https://docs.example.com/narrative-v3', 'Best block of quarter; locked door, no phone.'),
    (v_org_id, 'DWB-3113-005', 'Slack firefighting - dispatcher escalation', 'reactive_slack',
     now() - interval '68 days 6 hours', now() - interval '68 days 5 hours',
     30, 75, 8, 'wasted', 7, 4, 25, false,
     NULL, 'Should have routed to ops head; wasted strategic afternoon.'),
    (v_org_id, 'DWB-3113-006', 'Engineer tier-ladder design review', 'deep_review',
     now() - interval '64 days 3 hours', now() - interval '64 days',
     180, 175, 1, 'excellent', 8, 7, 5, true,
     'https://docs.example.com/tier-ladder-v4', 'Quiet review session; one interrupt managed.'),
    (v_org_id, 'DWB-3113-007', 'Pricing strategy whiteboarding - co-founder pair', 'deep_strategic',
     now() - interval '60 days 5 hours', now() - interval '60 days 3 hours',
     120, 115, 0, 'excellent', 8, 7, 0, true,
     NULL, 'Pair work counts as deep when both heads-down.'),
    (v_org_id, 'DWB-3113-008', 'Admin ops - expense reports + vendor payments', 'admin_ops',
     now() - interval '56 days 4 hours', now() - interval '56 days 3 hours',
     60, 65, 3, 'passable', 6, 5, 8, false,
     NULL, 'Pure admin; delegate to finance ops next quarter.'),
    (v_org_id, 'DWB-3113-009', 'Lunch + walk - recovery block', 'recovery_walk',
     now() - interval '52 days 5 hours', now() - interval '52 days 4 hours',
     45, 45, 0, 'good', 5, 8, 0, true,
     NULL, 'Recovery block recharged afternoon strategic time.'),
    (v_org_id, 'DWB-3113-010', 'Reactive calls cluster - dispatcher + 2 customers', 'reactive_calls',
     now() - interval '48 days 6 hours', now() - interval '48 days 5 hours',
     30, 95, 5, 'poor', 7, 3, 40, false,
     NULL, 'Calls bled 65min over plan; biggest energy drain of week.'),
    (v_org_id, 'DWB-3113-011', 'Quarterly OKR refresh - strategic deep block', 'deep_strategic',
     now() - interval '44 days 5 hours', now() - interval '44 days 2 hours',
     180, 180, 0, 'breakthrough', 9, 8, 0, true,
     'https://docs.example.com/okr-q4-draft', 'Locked-room session; produced clean OKR draft.'),
    (v_org_id, 'DWB-3113-012', 'Engineer tier-2 rollout PRD review', 'deep_review',
     now() - interval '40 days 4 hours', now() - interval '40 days 2 hours',
     120, 115, 1, 'good', 7, 6, 6, true,
     'https://docs.example.com/tier2-prd-comments', 'One interrupt; recovered fast.'),
    (v_org_id, 'DWB-3113-013', 'Lunch alone, journaling', 'recovery_lunch',
     now() - interval '36 days 5 hours', now() - interval '36 days 4 hours',
     45, 50, 0, 'good', 6, 8, 0, true,
     NULL, 'Lunch + journal block - critical for afternoon decision quality.'),
    (v_org_id, 'DWB-3113-014', 'Reactive inbox + slack chaos - bad afternoon', 'reactive_inbox',
     now() - interval '32 days 8 hours', now() - interval '32 days 5 hours',
     60, 180, 22, 'wasted', 7, 2, 95, false,
     NULL, 'Worst block of quarter; 22 interrupts, 3hrs wasted, no output.'),
    (v_org_id, 'DWB-3113-015', 'Deep coding - prototype scoring algo', 'deep_coding',
     now() - interval '28 days 4 hours', now() - interval '28 days 1 hour',
     180, 170, 2, 'excellent', 8, 7, 10, true,
     'https://github.example.com/scoring-prototype', 'Rare deep-coding block; high signal.');
END
$seed$;

-- ============================================================================
-- RPC 1: meeting-type rollup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_meeting_type_rollup()
RETURNS TABLE (
  meeting_type text,
  meeting_count bigint,
  avg_duration_minutes numeric,
  avg_prep_minutes numeric,
  avg_energy_drain numeric,
  avg_energy_gain numeric,
  total_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.meeting_type,
    count(*)::bigint,
    round(avg(m.duration_minutes)::numeric, 1),
    round(avg(m.prep_minutes)::numeric, 1),
    round(avg(m.energy_drain_score)::numeric, 2),
    round(avg(m.energy_gain_score)::numeric, 2),
    sum(m.estimated_revenue_impact_rupees)::bigint
  FROM public.founder_calendar_meetings_r3113 m
  GROUP BY m.meeting_type
  ORDER BY count(*) DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_meeting_type_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_meeting_type_rollup() TO authenticated;

-- ============================================================================
-- RPC 2: decision-quality distribution
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_decision_quality_distribution()
RETURNS TABLE (
  decision_quality_rating text,
  meeting_count bigint,
  total_minutes_invested bigint,
  avg_prep_quality_rank numeric,
  total_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.decision_quality_rating,
    count(*)::bigint,
    sum(m.duration_minutes)::bigint,
    round(avg(CASE m.prep_quality
      WHEN 'none' THEN 0
      WHEN 'rushed' THEN 1
      WHEN 'adequate' THEN 2
      WHEN 'thorough' THEN 3
      WHEN 'exhaustive' THEN 4
      ELSE 0 END)::numeric, 2),
    sum(m.estimated_revenue_impact_rupees)::bigint
  FROM public.founder_calendar_meetings_r3113 m
  GROUP BY m.decision_quality_rating
  ORDER BY count(*) DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_decision_quality_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_decision_quality_distribution() TO authenticated;

-- ============================================================================
-- RPC 3: delegate / defend / kill candidates
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_delegate_defend_kill_candidates()
RETURNS TABLE (
  meeting_code text,
  meeting_title text,
  meeting_type text,
  duration_minutes integer,
  energy_drain_score smallint,
  decision_quality_rating text,
  recommendation text,
  audit_notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.meeting_code,
    m.meeting_title,
    m.meeting_type,
    m.duration_minutes,
    m.energy_drain_score,
    m.decision_quality_rating,
    CASE
      WHEN m.kill_candidate THEN 'KILL'
      WHEN m.delegate_candidate THEN 'DELEGATE'
      WHEN m.defend_candidate THEN 'DEFEND'
      ELSE 'REVIEW'
    END,
    m.audit_notes
  FROM public.founder_calendar_meetings_r3113 m
  WHERE m.kill_candidate OR m.delegate_candidate OR m.defend_candidate
  ORDER BY
    CASE
      WHEN m.kill_candidate THEN 1
      WHEN m.delegate_candidate THEN 2
      WHEN m.defend_candidate THEN 3
      ELSE 4
    END,
    m.energy_drain_score DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_delegate_defend_kill_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_delegate_defend_kill_candidates() TO authenticated;

-- ============================================================================
-- RPC 4: prep quality vs outcome
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_prep_vs_outcome()
RETURNS TABLE (
  prep_quality text,
  meeting_count bigint,
  decided_or_closed bigint,
  rambled_or_no_show bigint,
  avg_follow_up_actions numeric,
  avg_energy_gain numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.prep_quality,
    count(*)::bigint,
    count(*) FILTER (WHERE m.outcome_status IN ('decided','closed_deal','aligned'))::bigint,
    count(*) FILTER (WHERE m.outcome_status IN ('rambled','no_show','cancelled'))::bigint,
    round(avg(m.follow_up_actions)::numeric, 2),
    round(avg(m.energy_gain_score)::numeric, 2)
  FROM public.founder_calendar_meetings_r3113 m
  GROUP BY m.prep_quality
  ORDER BY count(*) DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_prep_vs_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_prep_vs_outcome() TO authenticated;

-- ============================================================================
-- RPC 5: deep-work block category rollup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_deep_work_category_rollup()
RETURNS TABLE (
  block_category text,
  block_count bigint,
  total_planned_minutes bigint,
  total_actual_minutes bigint,
  total_interruptions bigint,
  total_context_switch_cost bigint,
  avg_energy_delta numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.block_category,
    count(*)::bigint,
    sum(b.planned_minutes)::bigint,
    sum(b.actual_minutes)::bigint,
    sum(b.interruptions_count)::bigint,
    sum(b.context_switch_cost_minutes)::bigint,
    round(avg(b.energy_level_end - b.energy_level_start)::numeric, 2)
  FROM public.founder_deep_work_blocks_r3113 b
  GROUP BY b.block_category
  ORDER BY sum(b.actual_minutes) DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_deep_work_category_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_deep_work_category_rollup() TO authenticated;

-- ============================================================================
-- RPC 6: deep work output quality breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_deep_work_output_quality()
RETURNS TABLE (
  output_quality text,
  block_count bigint,
  total_actual_minutes bigint,
  protected_blocks bigint,
  avg_interruptions numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_total_minutes numeric;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT NULLIF(sum(actual_minutes), 0)::numeric INTO v_total_minutes
  FROM public.founder_deep_work_blocks_r3113;

  RETURN QUERY
  SELECT
    b.output_quality,
    count(*)::bigint,
    sum(b.actual_minutes)::bigint,
    count(*) FILTER (WHERE b.protected_block)::bigint,
    round(avg(b.interruptions_count)::numeric, 2),
    round(100.0 * sum(b.actual_minutes) / COALESCE(v_total_minutes, 1), 2)
  FROM public.founder_deep_work_blocks_r3113 b
  GROUP BY b.output_quality
  ORDER BY sum(b.actual_minutes) DESC;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_deep_work_output_quality() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_deep_work_output_quality() TO authenticated;

-- ============================================================================
-- RPC 7: interruption hot-list
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_interruption_hotlist()
RETURNS TABLE (
  block_code text,
  block_label text,
  block_category text,
  interruptions_count integer,
  context_switch_cost_minutes integer,
  actual_minutes integer,
  output_quality text,
  protected_block boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.block_code,
    b.block_label,
    b.block_category,
    b.interruptions_count,
    b.context_switch_cost_minutes,
    b.actual_minutes,
    b.output_quality,
    b.protected_block
  FROM public.founder_deep_work_blocks_r3113 b
  WHERE b.interruptions_count >= 2 OR b.context_switch_cost_minutes >= 10
  ORDER BY b.interruptions_count DESC, b.context_switch_cost_minutes DESC
  LIMIT 25;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_interruption_hotlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_interruption_hotlist() TO authenticated;

-- ============================================================================
-- RPC 8: quarterly headline summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_quarterly_summary()
RETURNS TABLE (
  metric text,
  value text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_total_meetings bigint;
  v_total_meeting_minutes bigint;
  v_total_blocks bigint;
  v_total_deep_minutes bigint;
  v_total_reactive_minutes bigint;
  v_kill_count bigint;
  v_delegate_count bigint;
  v_defend_count bigint;
  v_revenue_impact bigint;
  v_breakthrough_blocks bigint;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT count(*), COALESCE(sum(duration_minutes), 0)
    INTO v_total_meetings, v_total_meeting_minutes
  FROM public.founder_calendar_meetings_r3113;

  SELECT count(*),
    COALESCE(sum(actual_minutes) FILTER (WHERE block_category LIKE 'deep_%'), 0),
    COALESCE(sum(actual_minutes) FILTER (WHERE block_category LIKE 'reactive_%'), 0)
    INTO v_total_blocks, v_total_deep_minutes, v_total_reactive_minutes
  FROM public.founder_deep_work_blocks_r3113;

  SELECT count(*) FILTER (WHERE kill_candidate),
         count(*) FILTER (WHERE delegate_candidate),
         count(*) FILTER (WHERE defend_candidate),
         COALESCE(sum(estimated_revenue_impact_rupees), 0)
    INTO v_kill_count, v_delegate_count, v_defend_count, v_revenue_impact
  FROM public.founder_calendar_meetings_r3113;

  SELECT count(*) FILTER (WHERE output_quality = 'breakthrough')
    INTO v_breakthrough_blocks
  FROM public.founder_deep_work_blocks_r3113;

  RETURN QUERY
  SELECT 'total_meetings_audited'::text, v_total_meetings::text
  UNION ALL SELECT 'total_meeting_minutes', v_total_meeting_minutes::text
  UNION ALL SELECT 'total_work_blocks', v_total_blocks::text
  UNION ALL SELECT 'total_deep_work_minutes', v_total_deep_minutes::text
  UNION ALL SELECT 'total_reactive_minutes', v_total_reactive_minutes::text
  UNION ALL SELECT 'kill_candidate_meetings', v_kill_count::text
  UNION ALL SELECT 'delegate_candidate_meetings', v_delegate_count::text
  UNION ALL SELECT 'defend_candidate_meetings', v_defend_count::text
  UNION ALL SELECT 'estimated_revenue_impact_rupees', v_revenue_impact::text
  UNION ALL SELECT 'breakthrough_deep_blocks', v_breakthrough_blocks::text;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_quarterly_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_quarterly_summary() TO authenticated;

-- ============================================================================
-- RPC 9: top meetings by revenue impact
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r3113_top_revenue_meetings()
RETURNS TABLE (
  meeting_code text,
  meeting_title text,
  meeting_type text,
  duration_minutes integer,
  prep_minutes integer,
  decision_quality_rating text,
  estimated_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.meeting_code,
    m.meeting_title,
    m.meeting_type,
    m.duration_minutes,
    m.prep_minutes,
    m.decision_quality_rating,
    m.estimated_revenue_impact_rupees
  FROM public.founder_calendar_meetings_r3113 m
  WHERE m.estimated_revenue_impact_rupees <> 0
  ORDER BY m.estimated_revenue_impact_rupees DESC
  LIMIT 10;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_r3113_top_revenue_meetings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3113_top_revenue_meetings() TO authenticated;

COMMIT;
