-- Round 3111: Founder Voice + Internal Comms Cadence Effectiveness Tracker
-- Channel x audience reach x open/listen x NPS x tone x action follow-up rate

BEGIN;

-- =====================================================================
-- TABLE 1: founder_comms_broadcasts_r3111
-- One row per founder-originated communication (all-hands, Loom, memo, etc.)
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_comms_broadcasts_r3111 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  broadcast_code text NOT NULL UNIQUE,
  title text NOT NULL,
  channel text NOT NULL CHECK (channel IN (
    'all_hands_live','loom_video','written_memo','slack_post',
    'whatsapp_voice_note','email_digest','town_hall_recording','one_on_one_clip'
  )),
  audience_segment text NOT NULL CHECK (audience_segment IN (
    'all_employees','engineers_field','engineers_senior','ops_team',
    'sales_team','founders_circle','investors','board','franchise_partners'
  )),
  topic_theme text NOT NULL CHECK (topic_theme IN (
    'strategy_quarterly','culture_values','product_roadmap','customer_wins',
    'incident_postmortem','hiring_update','financials_runway','market_intel',
    'compensation_policy','crisis_response','vision_north_star'
  )),
  cadence_slot text NOT NULL CHECK (cadence_slot IN (
    'weekly','biweekly','monthly','quarterly','ad_hoc','crisis_only'
  )),
  language_primary text NOT NULL CHECK (language_primary IN (
    'english','hindi','telugu','tamil','kannada','bilingual_en_hi','bilingual_en_te'
  )),
  duration_minutes int NOT NULL CHECK (duration_minutes >= 0 AND duration_minutes <= 240),
  sent_at timestamptz NOT NULL,
  audience_size int NOT NULL CHECK (audience_size > 0),
  delivered_count int NOT NULL CHECK (delivered_count >= 0),
  opened_count int NOT NULL CHECK (opened_count >= 0),
  fully_consumed_count int NOT NULL CHECK (fully_consumed_count >= 0),
  reply_count int NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  follow_up_action_count int NOT NULL DEFAULT 0 CHECK (follow_up_action_count >= 0),
  follow_up_completed_count int NOT NULL DEFAULT 0 CHECK (follow_up_completed_count >= 0),
  avg_nps_score numeric(4,2) CHECK (avg_nps_score IS NULL OR (avg_nps_score >= -100 AND avg_nps_score <= 100)),
  tone_classification text NOT NULL CHECK (tone_classification IN (
    'inspiring','informative','urgent','candid_difficult','celebratory',
    'reflective','directive','vulnerable'
  )),
  effectiveness_band text NOT NULL CHECK (effectiveness_band IN (
    'excellent','strong','adequate','weak','dud'
  )),
  status text NOT NULL CHECK (status IN (
    'scheduled','sent','partially_landed','fully_landed','archived','retracted'
  )),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcb_r3111_channel ON public.founder_comms_broadcasts_r3111(channel);
CREATE INDEX IF NOT EXISTS idx_fcb_r3111_audience ON public.founder_comms_broadcasts_r3111(audience_segment);
CREATE INDEX IF NOT EXISTS idx_fcb_r3111_sent_at ON public.founder_comms_broadcasts_r3111(sent_at DESC);

ALTER TABLE public.founder_comms_broadcasts_r3111 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- TABLE 2: founder_comms_feedback_r3111
-- Per-broadcast individual feedback signals from audience
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_comms_feedback_r3111 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id uuid NOT NULL REFERENCES public.founder_comms_broadcasts_r3111(id) ON DELETE CASCADE,
  responder_role text NOT NULL CHECK (responder_role IN (
    'engineer_junior','engineer_senior','ops_lead','sales_rep',
    'finance','hr','founder_team','investor','franchise_owner','board_member'
  )),
  responder_city text NOT NULL CHECK (responder_city IN (
    'hyderabad','bengaluru','chennai','mumbai','delhi','pune',
    'kolkata','ahmedabad','jaipur','kochi','remote'
  )),
  consumption_mode text NOT NULL CHECK (consumption_mode IN (
    'live_attended','recording_watched','skimmed','read_full',
    'read_skimmed','listened_audio','not_consumed'
  )),
  nps_score int CHECK (nps_score IS NULL OR (nps_score >= -10 AND nps_score <= 10)),
  sentiment text NOT NULL CHECK (sentiment IN (
    'highly_positive','positive','neutral','concerned','negative','very_negative'
  )),
  clarity_rating int NOT NULL CHECK (clarity_rating >= 1 AND clarity_rating <= 5),
  alignment_rating int NOT NULL CHECK (alignment_rating >= 1 AND alignment_rating <= 5),
  action_taken text NOT NULL CHECK (action_taken IN (
    'changed_priority','escalated_concern','shared_team','no_action',
    'replied_directly','attended_followup','blocked_progress','adopted_change'
  )),
  follow_up_owner text NOT NULL CHECK (follow_up_owner IN (
    'self','manager','founder','hr','ops','none'
  )),
  raised_quarterly_concern boolean NOT NULL DEFAULT false,
  free_text_snippet text,
  submitted_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcf_r3111_broadcast ON public.founder_comms_feedback_r3111(broadcast_id);
CREATE INDEX IF NOT EXISTS idx_fcf_r3111_role ON public.founder_comms_feedback_r3111(responder_role);

ALTER TABLE public.founder_comms_feedback_r3111 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $seed$
DECLARE
  v_org_id uuid;
BEGIN
  SELECT id INTO v_org_id FROM public.organizations ORDER BY created_at ASC LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE NOTICE 'No organization found; skipping seed';
    RETURN;
  END IF;

  -- 8 broadcast rows
  INSERT INTO public.founder_comms_broadcasts_r3111 (
    org_id, broadcast_code, title, channel, audience_segment, topic_theme,
    cadence_slot, language_primary, duration_minutes, sent_at, audience_size,
    delivered_count, opened_count, fully_consumed_count, reply_count,
    follow_up_action_count, follow_up_completed_count, avg_nps_score,
    tone_classification, effectiveness_band, status, notes
  ) VALUES
  (v_org_id, 'BC-3111-001', 'Q2 FY27 All-Hands: Path to Profitability', 'all_hands_live',
   'all_employees', 'strategy_quarterly', 'quarterly', 'bilingual_en_hi', 75,
   '2026-06-04 14:00:00+05:30', 142, 138, 131, 118, 27, 14, 11, 58.50,
   'inspiring', 'excellent', 'fully_landed',
   'Hyderabad HQ + remote zoom; record posted to drive'),
  (v_org_id, 'BC-3111-002', 'Loom: Why We Killed Dental Vertical', 'loom_video',
   'all_employees', 'strategy_quarterly', 'biweekly', 'english', 12,
   '2026-06-09 09:30:00+05:30', 142, 140, 124, 91, 18, 9, 7, 32.00,
   'candid_difficult', 'strong', 'fully_landed',
   'Hard call; founder voice mattered'),
  (v_org_id, 'BC-3111-003', 'Memo: New Engineer Tier-3 Comp Bands', 'written_memo',
   'engineers_field', 'compensation_policy', 'ad_hoc', 'bilingual_en_hi', 0,
   '2026-06-12 18:00:00+05:30', 47, 47, 44, 38, 22, 19, 16, 41.20,
   'directive', 'strong', 'fully_landed',
   'Published to Notion + WhatsApp blast'),
  (v_org_id, 'BC-3111-004', 'WhatsApp Voice: Apollo Win Story', 'whatsapp_voice_note',
   'engineers_field', 'customer_wins', 'weekly', 'telugu', 4,
   '2026-06-15 08:00:00+05:30', 47, 47, 47, 41, 12, 5, 5, 67.40,
   'celebratory', 'excellent', 'fully_landed',
   'Telugu voice note hit hardest with field team'),
  (v_org_id, 'BC-3111-005', 'Town Hall: Cashfree Activation Delay', 'town_hall_recording',
   'all_employees', 'crisis_response', 'crisis_only', 'english', 35,
   '2026-06-18 16:00:00+05:30', 142, 139, 102, 71, 31, 11, 6, 12.10,
   'urgent', 'adequate', 'partially_landed',
   'Anxiety about runway; second clip planned'),
  (v_org_id, 'BC-3111-006', 'Slack: Tier-3 Engineer Hiring Push', 'slack_post',
   'ops_team', 'hiring_update', 'biweekly', 'english', 0,
   '2026-06-20 11:00:00+05:30', 18, 18, 17, 14, 8, 6, 5, 44.30,
   'directive', 'strong', 'fully_landed',
   'Operations channel reach'),
  (v_org_id, 'BC-3111-007', 'Email: Investor Quarterly Letter Preview', 'email_digest',
   'founders_circle', 'financials_runway', 'quarterly', 'english', 0,
   '2026-06-22 19:30:00+05:30', 9, 9, 9, 8, 4, 3, 3, 71.00,
   'reflective', 'excellent', 'fully_landed',
   'Internal preview before sending to LPs'),
  (v_org_id, 'BC-3111-008', 'Loom: Counterfeit Spare Parts Incident', 'loom_video',
   'engineers_senior', 'incident_postmortem', 'ad_hoc', 'english', 18,
   '2026-06-25 10:00:00+05:30', 24, 24, 22, 19, 14, 11, 8, 36.80,
   'vulnerable', 'strong', 'fully_landed',
   'Postmortem of OEM bond breach');

  -- 14 feedback rows across various broadcasts
  INSERT INTO public.founder_comms_feedback_r3111 (
    broadcast_id, responder_role, responder_city, consumption_mode,
    nps_score, sentiment, clarity_rating, alignment_rating, action_taken,
    follow_up_owner, raised_quarterly_concern, free_text_snippet, submitted_at
  )
  SELECT b.id, r.responder_role, r.responder_city, r.consumption_mode,
         r.nps_score, r.sentiment, r.clarity_rating, r.alignment_rating,
         r.action_taken, r.follow_up_owner, r.raised_quarterly_concern,
         r.free_text_snippet, r.submitted_at::timestamptz
  FROM public.founder_comms_broadcasts_r3111 b
  JOIN (VALUES
    ('BC-3111-001', 'engineer_senior', 'hyderabad', 'live_attended', 9, 'highly_positive', 5, 5, 'adopted_change', 'self', false, 'Clarity on profitability path was rare', '2026-06-04 16:30:00+05:30'),
    ('BC-3111-001', 'ops_lead', 'bengaluru', 'live_attended', 8, 'positive', 5, 4, 'changed_priority', 'manager', false, 'Need more on hospital chains plan', '2026-06-04 17:00:00+05:30'),
    ('BC-3111-001', 'sales_rep', 'chennai', 'recording_watched', 7, 'positive', 4, 4, 'shared_team', 'self', true, 'Will reshare with sales pod', '2026-06-05 11:00:00+05:30'),
    ('BC-3111-002', 'engineer_junior', 'hyderabad', 'recording_watched', 3, 'concerned', 3, 3, 'escalated_concern', 'manager', true, 'Worried about dental teammates', '2026-06-09 14:00:00+05:30'),
    ('BC-3111-002', 'founder_team', 'hyderabad', 'live_attended', 9, 'highly_positive', 5, 5, 'adopted_change', 'self', false, 'Hard but correct call', '2026-06-09 12:00:00+05:30'),
    ('BC-3111-003', 'engineer_senior', 'pune', 'read_full', 8, 'positive', 5, 5, 'adopted_change', 'self', false, 'Tier-3 bands clear', '2026-06-12 19:30:00+05:30'),
    ('BC-3111-003', 'engineer_junior', 'bengaluru', 'read_skimmed', 4, 'neutral', 3, 4, 'replied_directly', 'hr', false, 'Need example payslips', '2026-06-13 08:00:00+05:30'),
    ('BC-3111-004', 'engineer_senior', 'hyderabad', 'listened_audio', 10, 'highly_positive', 5, 5, 'shared_team', 'self', false, 'Telugu mein bahut accha laga', '2026-06-15 09:30:00+05:30'),
    ('BC-3111-004', 'engineer_junior', 'hyderabad', 'listened_audio', 9, 'highly_positive', 5, 5, 'attended_followup', 'self', false, 'Apollo story motivated me', '2026-06-15 10:00:00+05:30'),
    ('BC-3111-005', 'ops_lead', 'mumbai', 'live_attended', -2, 'concerned', 3, 2, 'escalated_concern', 'founder', true, 'Cashfree pending too long; runway risk', '2026-06-18 17:30:00+05:30'),
    ('BC-3111-005', 'finance', 'hyderabad', 'live_attended', 1, 'neutral', 4, 3, 'no_action', 'none', true, 'Need weekly KYC update', '2026-06-18 18:00:00+05:30'),
    ('BC-3111-006', 'ops_lead', 'delhi', 'read_full', 7, 'positive', 5, 4, 'changed_priority', 'manager', false, 'Will source 3 Tier-3 candidates', '2026-06-20 13:00:00+05:30'),
    ('BC-3111-007', 'investor', 'bengaluru', 'read_full', 8, 'positive', 5, 5, 'replied_directly', 'founder', false, 'Numbers tracking thesis', '2026-06-23 09:00:00+05:30'),
    ('BC-3111-008', 'engineer_senior', 'hyderabad', 'recording_watched', 5, 'neutral', 4, 4, 'adopted_change', 'self', true, 'Bond provenance fix landed but trust dented', '2026-06-25 12:30:00+05:30')
  ) AS r(broadcast_code, responder_role, responder_city, consumption_mode,
         nps_score, sentiment, clarity_rating, alignment_rating, action_taken,
         follow_up_owner, raised_quarterly_concern, free_text_snippet, submitted_at)
  ON b.broadcast_code = r.broadcast_code;
END;
$seed$;

-- =====================================================================
-- RPCs (all founder-gated)
-- =====================================================================

-- 1. Channel mix rollup
CREATE OR REPLACE FUNCTION public.fn_r3111_channel_rollup()
RETURNS TABLE(
  channel text,
  broadcasts_count bigint,
  total_audience bigint,
  total_opened bigint,
  total_consumed bigint,
  open_rate_pct numeric,
  consume_rate_pct numeric,
  avg_nps numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.channel,
         COUNT(*)::bigint,
         SUM(b.audience_size)::bigint,
         SUM(b.opened_count)::bigint,
         SUM(b.fully_consumed_count)::bigint,
         ROUND(100.0 * SUM(b.opened_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2)
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.channel
  ORDER BY broadcasts_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_channel_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_channel_rollup() TO authenticated;

-- 2. Audience segment rollup
CREATE OR REPLACE FUNCTION public.fn_r3111_audience_rollup()
RETURNS TABLE(
  audience_segment text,
  broadcasts_count bigint,
  total_reach bigint,
  consume_rate_pct numeric,
  reply_count bigint,
  follow_up_completion_pct numeric,
  avg_nps numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.audience_segment,
         COUNT(*)::bigint,
         SUM(b.delivered_count)::bigint,
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         SUM(b.reply_count)::bigint,
         ROUND(100.0 * SUM(b.follow_up_completed_count)::numeric / NULLIF(SUM(b.follow_up_action_count),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2)
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.audience_segment
  ORDER BY total_reach DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_audience_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_audience_rollup() TO authenticated;

-- 3. Cadence slot effectiveness
CREATE OR REPLACE FUNCTION public.fn_r3111_cadence_effectiveness()
RETURNS TABLE(
  cadence_slot text,
  broadcasts_count bigint,
  avg_consume_rate_pct numeric,
  avg_nps numeric,
  dud_count bigint,
  excellent_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.cadence_slot,
         COUNT(*)::bigint,
         ROUND(AVG(100.0 * b.fully_consumed_count::numeric / NULLIF(b.audience_size,0))::numeric, 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2),
         COUNT(*) FILTER (WHERE b.effectiveness_band = 'dud')::bigint,
         COUNT(*) FILTER (WHERE b.effectiveness_band = 'excellent')::bigint
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.cadence_slot
  ORDER BY avg_nps DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_cadence_effectiveness() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_cadence_effectiveness() TO authenticated;

-- 4. Tone vs outcome
CREATE OR REPLACE FUNCTION public.fn_r3111_tone_outcome()
RETURNS TABLE(
  tone_classification text,
  broadcasts_count bigint,
  avg_clarity numeric,
  avg_alignment numeric,
  positive_sentiment_pct numeric,
  concern_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.tone_classification,
         COUNT(DISTINCT b.id)::bigint,
         ROUND(AVG(f.clarity_rating)::numeric, 2),
         ROUND(AVG(f.alignment_rating)::numeric, 2),
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.sentiment IN ('highly_positive','positive'))::numeric
               / NULLIF(COUNT(f.id),0), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.sentiment IN ('concerned','negative','very_negative'))::numeric
               / NULLIF(COUNT(f.id),0), 1)
  FROM public.founder_comms_broadcasts_r3111 b
  LEFT JOIN public.founder_comms_feedback_r3111 f ON f.broadcast_id = b.id
  GROUP BY b.tone_classification
  ORDER BY broadcasts_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_tone_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_tone_outcome() TO authenticated;

-- 5. Follow-up action completion
CREATE OR REPLACE FUNCTION public.fn_r3111_followup_completion()
RETURNS TABLE(
  broadcast_code text,
  title text,
  follow_up_action_count int,
  follow_up_completed_count int,
  completion_pct numeric,
  effectiveness_band text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.broadcast_code,
         b.title,
         b.follow_up_action_count,
         b.follow_up_completed_count,
         ROUND(100.0 * b.follow_up_completed_count::numeric / NULLIF(b.follow_up_action_count,0), 1),
         b.effectiveness_band
  FROM public.founder_comms_broadcasts_r3111 b
  WHERE b.follow_up_action_count > 0
  ORDER BY completion_pct ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_followup_completion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_followup_completion() TO authenticated;

-- 6. Language reach
CREATE OR REPLACE FUNCTION public.fn_r3111_language_reach()
RETURNS TABLE(
  language_primary text,
  broadcasts_count bigint,
  total_consumed bigint,
  consume_rate_pct numeric,
  avg_nps numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.language_primary,
         COUNT(*)::bigint,
         SUM(b.fully_consumed_count)::bigint,
         ROUND(100.0 * SUM(b.fully_consumed_count)::numeric / NULLIF(SUM(b.audience_size),0), 1),
         ROUND(AVG(b.avg_nps_score)::numeric, 2)
  FROM public.founder_comms_broadcasts_r3111 b
  GROUP BY b.language_primary
  ORDER BY avg_nps DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_language_reach() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_language_reach() TO authenticated;

-- 7. Concern hotspots by role
CREATE OR REPLACE FUNCTION public.fn_r3111_role_concern_hotspots()
RETURNS TABLE(
  responder_role text,
  total_feedback bigint,
  raised_concern_count bigint,
  concern_pct numeric,
  avg_nps numeric,
  avg_clarity numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.responder_role,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE f.raised_quarterly_concern)::bigint,
         ROUND(100.0 * COUNT(*) FILTER (WHERE f.raised_quarterly_concern)::numeric
               / NULLIF(COUNT(*),0), 1),
         ROUND(AVG(f.nps_score)::numeric, 2),
         ROUND(AVG(f.clarity_rating)::numeric, 2)
  FROM public.founder_comms_feedback_r3111 f
  GROUP BY f.responder_role
  ORDER BY concern_pct DESC, total_feedback DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_role_concern_hotspots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_role_concern_hotspots() TO authenticated;

-- 8. Recent broadcast feed
CREATE OR REPLACE FUNCTION public.fn_r3111_recent_broadcasts()
RETURNS TABLE(
  broadcast_code text,
  title text,
  channel text,
  audience_segment text,
  topic_theme text,
  sent_at timestamptz,
  duration_minutes int,
  audience_size int,
  fully_consumed_count int,
  avg_nps_score numeric,
  tone_classification text,
  effectiveness_band text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.broadcast_code, b.title, b.channel, b.audience_segment, b.topic_theme,
         b.sent_at, b.duration_minutes, b.audience_size, b.fully_consumed_count,
         b.avg_nps_score, b.tone_classification, b.effectiveness_band, b.status
  FROM public.founder_comms_broadcasts_r3111 b
  ORDER BY b.sent_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_r3111_recent_broadcasts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r3111_recent_broadcasts() TO authenticated;

COMMIT;