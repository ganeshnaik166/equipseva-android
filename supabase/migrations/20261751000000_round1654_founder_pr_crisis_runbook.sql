BEGIN;

-- ============================================================================
-- r1654 — Founder PR Crisis Runbook
-- Pre-built per-step playbooks for PR crises (negative press, viral complaints,
-- founder controversy) with escalation contacts. Founder-only.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: pr_crisis_playbooks — one row per crisis archetype
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pr_crisis_playbooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  crisis_code text NOT NULL UNIQUE,
  crisis_title text NOT NULL,
  crisis_kind text NOT NULL CHECK (crisis_kind IN ('negative_press','viral_complaint','founder_controversy','regulatory_blowback','social_media_storm','employee_leak','data_breach_perception')),
  severity_tier text NOT NULL DEFAULT 'p2' CHECK (severity_tier IN ('p0','p1','p2','p3')),
  first_60_min_action text NOT NULL,
  do_say jsonb NOT NULL DEFAULT '[]'::jsonb,
  do_not_say jsonb NOT NULL DEFAULT '[]'::jsonb,
  step_playbook jsonb NOT NULL DEFAULT '[]'::jsonb,      -- ordered steps with owner + sla_minutes
  escalation_contacts jsonb NOT NULL DEFAULT '[]'::jsonb,-- [{name,role,phone,email,when}]
  comms_template_short text,
  comms_template_long text,
  legal_review_required boolean NOT NULL DEFAULT true,
  last_dry_run_at timestamptz,
  last_invoked_at timestamptz,
  invocation_count int NOT NULL DEFAULT 0,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS pr_crisis_playbooks_kind_idx ON public.pr_crisis_playbooks(crisis_kind) WHERE NOT is_archived;
CREATE INDEX IF NOT EXISTS pr_crisis_playbooks_severity_idx ON public.pr_crisis_playbooks(severity_tier) WHERE NOT is_archived;

ALTER TABLE public.pr_crisis_playbooks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pr_crisis_playbooks_founder_all ON public.pr_crisis_playbooks;
CREATE POLICY pr_crisis_playbooks_founder_all ON public.pr_crisis_playbooks
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
-- Table 2: pr_crisis_invocations — live + historical crisis activations
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pr_crisis_invocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playbook_id uuid NOT NULL REFERENCES public.pr_crisis_playbooks(id) ON DELETE RESTRICT,
  invocation_status text NOT NULL DEFAULT 'active' CHECK (invocation_status IN ('active','contained','resolved','false_alarm')),
  trigger_summary text NOT NULL,
  source_url text,
  reach_estimate int,
  current_step_index int NOT NULL DEFAULT 0,
  step_log jsonb NOT NULL DEFAULT '[]'::jsonb, -- [{step_index, note, by_email, at}]
  opened_at timestamptz NOT NULL DEFAULT now(),
  contained_at timestamptz,
  resolved_at timestamptz,
  postmortem_url text,
  opened_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS pr_crisis_invocations_status_idx ON public.pr_crisis_invocations(invocation_status, opened_at DESC);
CREATE INDEX IF NOT EXISTS pr_crisis_invocations_playbook_idx ON public.pr_crisis_invocations(playbook_id, opened_at DESC);

ALTER TABLE public.pr_crisis_invocations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pr_crisis_invocations_founder_all ON public.pr_crisis_invocations;
CREATE POLICY pr_crisis_invocations_founder_all ON public.pr_crisis_invocations
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
-- Seed: 7 canonical PR crisis archetypes
-- ----------------------------------------------------------------------------
INSERT INTO public.pr_crisis_playbooks (crisis_code, crisis_title, crisis_kind, severity_tier, first_60_min_action, do_say, do_not_say, step_playbook, escalation_contacts, comms_template_short, comms_template_long, legal_review_required)
VALUES
  ('negative_press_hit_piece', 'Negative press / hit-piece in major outlet', 'negative_press', 'p1',
   'Read full article. Verify factual claims. Founder + legal call within 30 min. No public statement yet.',
   '["We take this seriously.","We are investigating internally.","Patient/customer safety is our first priority."]'::jsonb,
   '["No comment.","Fake news.","That reporter has a grudge.","It''s not our fault."]'::jsonb,
   '[{"step":1,"owner":"founder","sla_minutes":30,"action":"Read article end-to-end + screenshot archive"},{"step":2,"owner":"legal","sla_minutes":60,"action":"Fact-check every claim against internal records"},{"step":3,"owner":"founder","sla_minutes":120,"action":"Draft holding statement (50 words)"},{"step":4,"owner":"pr_lead","sla_minutes":180,"action":"Reach out to reporter with corrections + on-record source"},{"step":5,"owner":"founder","sla_minutes":1440,"action":"Post measured response on company blog"}]'::jsonb,
   '[{"name":"Legal counsel","role":"External counsel","phone":"+91-XXXXXXXXXX","when":"immediately"},{"name":"PR retainer","role":"Crisis PR firm","when":"within 60 min"},{"name":"Board chair","role":"Board","when":"if severity escalates to p0"}]'::jsonb,
   'We have seen the article and are reviewing the claims carefully. Patient safety is our priority and we will share more details soon.',
   NULL, true),
  ('viral_customer_complaint', 'Customer complaint goes viral on social media', 'viral_complaint', 'p1',
   'Identify the customer. Pull every record. Reply publicly within 2 hours acknowledging — DM to resolve.',
   '["We hear you. We are on it.","DMing you now to make this right.","Thank you for flagging — this is not the experience we want."]'::jsonb,
   '["That''s not our policy.","You are misremembering.","Per our T&C...","Please email support@"]'::jsonb,
   '[{"step":1,"owner":"founder","sla_minutes":15,"action":"Pull customer record + job history + payment trail"},{"step":2,"owner":"ops_lead","sla_minutes":30,"action":"Identify ground truth — was customer right?"},{"step":3,"owner":"founder","sla_minutes":120,"action":"Public reply: empathetic + offer to resolve via DM"},{"step":4,"owner":"ops_lead","sla_minutes":240,"action":"DM customer with concrete remedy"},{"step":5,"owner":"founder","sla_minutes":1440,"action":"Post resolution publicly once customer agrees"}]'::jsonb,
   '[{"name":"Ops lead","role":"Internal","when":"immediately"},{"name":"Customer success head","role":"Internal","when":"within 30 min"}]'::jsonb,
   'We hear you and we are sorry. DMing you now to make this right — please check your inbox.',
   NULL, false),
  ('founder_controversy', 'Founder personal controversy surfaces', 'founder_controversy', 'p0',
   'Founder steps back from public-facing comms for 24 hours. Board chair + legal lead response. Do NOT tweet.',
   '["The matter is being addressed.","We are cooperating fully."]'::jsonb,
   '["It was taken out of context.","That was a long time ago.","Personal attack."]'::jsonb,
   '[{"step":1,"owner":"founder","sla_minutes":15,"action":"STOP all public posting from personal + company accounts"},{"step":2,"owner":"board_chair","sla_minutes":60,"action":"Convene emergency board call"},{"step":3,"owner":"legal","sla_minutes":120,"action":"Determine factual posture + legal exposure"},{"step":4,"owner":"board_chair","sla_minutes":360,"action":"Statement from board, not founder"},{"step":5,"owner":"founder","sla_minutes":2880,"action":"Personal statement only after board + legal sign-off"}]'::jsonb,
   '[{"name":"Board chair","role":"Board","when":"immediately"},{"name":"Legal counsel","role":"External counsel","when":"immediately"},{"name":"Lead investor","role":"Investor relations","when":"within 60 min"},{"name":"Crisis PR firm","role":"External","when":"within 60 min"}]'::jsonb,
   'The matter has been raised and is being addressed appropriately. We have no further comment at this time.',
   NULL, true),
  ('regulatory_blowback', 'Regulatory body issues public notice / inquiry', 'regulatory_blowback', 'p0',
   'Acknowledge receipt within 1 hour. Legal-only comms. Do NOT post on social.',
   '["We have received the notice and are cooperating fully.","We respect the regulator''s authority."]'::jsonb,
   '["This is overreach.","The rule is unclear.","We will fight this."]'::jsonb,
   '[{"step":1,"owner":"legal","sla_minutes":60,"action":"Acknowledge receipt formally"},{"step":2,"owner":"compliance_lead","sla_minutes":240,"action":"Pull all responsive records into a clean room"},{"step":3,"owner":"founder","sla_minutes":1440,"action":"Brief board + key investors"},{"step":4,"owner":"legal","sla_minutes":4320,"action":"File formal response"},{"step":5,"owner":"founder","sla_minutes":10080,"action":"Public statement only after response filed"}]'::jsonb,
   '[{"name":"Regulatory counsel","role":"External counsel","when":"immediately"},{"name":"Compliance lead","role":"Internal","when":"immediately"}]'::jsonb,
   'We have received the notice and are cooperating fully with the authority. We will share more once we have substantively responded.',
   NULL, true),
  ('social_media_storm', 'Twitter / LinkedIn pile-on without single complaint', 'social_media_storm', 'p2',
   'Do NOT engage individual threads. Pin a single statement. Mute notifications for the founder personal account.',
   '["We are listening.","Here is what we know so far."]'::jsonb,
   '["You don''t know the full story.","Let me explain..."]'::jsonb,
   '[{"step":1,"owner":"founder","sla_minutes":30,"action":"Stop engaging individual threads"},{"step":2,"owner":"ops_lead","sla_minutes":120,"action":"Identify root narrative + 3 loudest amplifiers"},{"step":3,"owner":"founder","sla_minutes":240,"action":"Single pinned statement on company channel"},{"step":4,"owner":"pr_lead","sla_minutes":1440,"action":"Direct outreach to top 3 critics offering call"}]'::jsonb,
   '[{"name":"PR retainer","role":"Crisis PR firm","when":"within 4 hours"}]'::jsonb,
   'We see the conversation and are listening. A full response is coming — meanwhile we are not going to engage individual threads.',
   NULL, false),
  ('employee_leak', 'Former employee leaks internal docs / Slack', 'employee_leak', 'p1',
   'Confirm authenticity. Audit access logs. Legal review of NDA + employment contract.',
   '["We take confidentiality seriously.","We are reviewing the situation."]'::jsonb,
   '["That person was disgruntled.","Those documents are fake."]'::jsonb,
   '[{"step":1,"owner":"security_lead","sla_minutes":60,"action":"Verify authenticity + identify leaker"},{"step":2,"owner":"legal","sla_minutes":240,"action":"Review NDA + send cease-and-desist if warranted"},{"step":3,"owner":"founder","sla_minutes":480,"action":"Brief team internally before they see it on Twitter"},{"step":4,"owner":"founder","sla_minutes":1440,"action":"Address substance not the leak"}]'::jsonb,
   '[{"name":"Employment counsel","role":"External counsel","when":"within 2 hours"},{"name":"Security lead","role":"Internal","when":"immediately"}]'::jsonb,
   'We are aware of the materials circulating. We are reviewing them and will address the substance, not the breach itself, in due course.',
   NULL, true),
  ('data_breach_perception', 'Perceived data breach (real or rumored)', 'data_breach_perception', 'p0',
   'Trigger DPDP incident protocol IMMEDIATELY whether confirmed or not. Founder + DPO on call within 60 min.',
   '["Patient/customer data security is paramount.","We are investigating with full force."]'::jsonb,
   '["There is no breach.","This is overblown.","Move on."]'::jsonb,
   '[{"step":1,"owner":"dpo","sla_minutes":60,"action":"Trigger DPDP incident logging + forensics"},{"step":2,"owner":"security_lead","sla_minutes":240,"action":"Containment + scope assessment"},{"step":3,"owner":"legal","sla_minutes":1440,"action":"Determine notification obligations"},{"step":4,"owner":"founder","sla_minutes":2880,"action":"Public statement with concrete facts"},{"step":5,"owner":"dpo","sla_minutes":4320,"action":"File breach notification with DPB if required"}]'::jsonb,
   '[{"name":"DPO","role":"Internal","when":"immediately"},{"name":"Privacy counsel","role":"External counsel","when":"immediately"},{"name":"Security forensics partner","role":"External","when":"within 60 min"}]'::jsonb,
   'We are aware of the reports and have triggered our incident protocol. Customer/patient data security is paramount and we will share verified facts as soon as we have them.',
   NULL, true)
ON CONFLICT (crisis_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- RPC 1: founder_pr_runbook_overview — summary stats
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_runbook_overview()
RETURNS TABLE(
  total_playbooks int,
  p0_playbooks int,
  p1_playbooks int,
  legal_review_required_count int,
  active_invocations int,
  contained_invocations_30d int,
  resolved_invocations_30d int,
  last_invocation_at timestamptz,
  playbooks_never_dry_run int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE NOT p.is_archived))::int,
    (COUNT(*) FILTER (WHERE p.severity_tier = 'p0' AND NOT p.is_archived))::int,
    (COUNT(*) FILTER (WHERE p.severity_tier = 'p1' AND NOT p.is_archived))::int,
    (COUNT(*) FILTER (WHERE p.legal_review_required AND NOT p.is_archived))::int,
    (SELECT (COUNT(*) FILTER (WHERE invocation_status = 'active'))::int FROM pr_crisis_invocations),
    (SELECT (COUNT(*) FILTER (WHERE invocation_status = 'contained' AND opened_at > now() - interval '30 days'))::int FROM pr_crisis_invocations),
    (SELECT (COUNT(*) FILTER (WHERE invocation_status = 'resolved' AND opened_at > now() - interval '30 days'))::int FROM pr_crisis_invocations),
    (SELECT MAX(opened_at) FROM pr_crisis_invocations),
    (COUNT(*) FILTER (WHERE p.last_dry_run_at IS NULL AND NOT p.is_archived))::int
  FROM pr_crisis_playbooks p;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_runbook_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_runbook_overview() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 2: founder_pr_list_playbooks — full directory
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_list_playbooks()
RETURNS TABLE(
  id uuid,
  crisis_code text,
  crisis_title text,
  crisis_kind text,
  severity_tier text,
  first_60_min_action text,
  legal_review_required boolean,
  invocation_count int,
  last_invoked_at timestamptz,
  last_dry_run_at timestamptz,
  step_count int,
  contact_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.crisis_code,
    p.crisis_title,
    p.crisis_kind,
    p.severity_tier,
    p.first_60_min_action,
    p.legal_review_required,
    p.invocation_count,
    p.last_invoked_at,
    p.last_dry_run_at,
    jsonb_array_length(p.step_playbook)::int,
    jsonb_array_length(p.escalation_contacts)::int
  FROM pr_crisis_playbooks p
  WHERE NOT p.is_archived
  ORDER BY
    CASE p.severity_tier WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    p.crisis_title ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_list_playbooks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_list_playbooks() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 3: founder_pr_playbook_steps — ordered steps for one playbook
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_playbook_steps(p_playbook_id uuid)
RETURNS TABLE(
  step_index int,
  owner_role text,
  sla_minutes int,
  action_text text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE((s->>'step')::int, ord::int),
    COALESCE(s->>'owner', '—'),
    COALESCE((s->>'sla_minutes')::int, 0),
    COALESCE(s->>'action', '—')
  FROM pr_crisis_playbooks p,
       LATERAL jsonb_array_elements(p.step_playbook) WITH ORDINALITY AS t(s, ord)
  WHERE p.id = p_playbook_id
  ORDER BY 1 ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_playbook_steps(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_playbook_steps(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 4: founder_pr_playbook_contacts — escalation contacts for one playbook
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_playbook_contacts(p_playbook_id uuid)
RETURNS TABLE(
  contact_name text,
  contact_role text,
  contact_phone text,
  contact_email text,
  call_when text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(c->>'name', '—'),
    COALESCE(c->>'role', '—'),
    COALESCE(c->>'phone', '—'),
    COALESCE(c->>'email', '—'),
    COALESCE(c->>'when', 'as needed')
  FROM pr_crisis_playbooks p,
       LATERAL jsonb_array_elements(p.escalation_contacts) AS c
  WHERE p.id = p_playbook_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_playbook_contacts(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_playbook_contacts(uuid) TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 5: founder_pr_active_invocations — live crisis activations
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_active_invocations()
RETURNS TABLE(
  invocation_id uuid,
  crisis_title text,
  severity_tier text,
  invocation_status text,
  trigger_summary text,
  reach_estimate int,
  current_step_index int,
  total_steps int,
  opened_at timestamptz,
  hours_open numeric,
  opened_by_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    p.crisis_title,
    p.severity_tier,
    i.invocation_status,
    i.trigger_summary,
    i.reach_estimate,
    i.current_step_index,
    jsonb_array_length(p.step_playbook)::int,
    i.opened_at,
    ROUND(EXTRACT(EPOCH FROM (COALESCE(i.resolved_at, i.contained_at, now()) - i.opened_at)) / 3600.0, 1),
    i.opened_by_email
  FROM pr_crisis_invocations i
  JOIN pr_crisis_playbooks p ON p.id = i.playbook_id
  WHERE i.invocation_status IN ('active','contained')
  ORDER BY
    CASE p.severity_tier WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    i.opened_at DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_active_invocations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_active_invocations() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 6: founder_pr_invocation_history — last 30d resolved + false_alarm
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_invocation_history()
RETURNS TABLE(
  invocation_id uuid,
  crisis_title text,
  severity_tier text,
  invocation_status text,
  trigger_summary text,
  opened_at timestamptz,
  resolved_at timestamptz,
  hours_to_resolve numeric,
  postmortem_url text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id,
    p.crisis_title,
    p.severity_tier,
    i.invocation_status,
    i.trigger_summary,
    i.opened_at,
    i.resolved_at,
    CASE WHEN i.resolved_at IS NOT NULL THEN ROUND(EXTRACT(EPOCH FROM (i.resolved_at - i.opened_at)) / 3600.0, 1) ELSE NULL END,
    i.postmortem_url
  FROM pr_crisis_invocations i
  JOIN pr_crisis_playbooks p ON p.id = i.playbook_id
  WHERE i.invocation_status IN ('resolved','false_alarm')
    AND i.opened_at > now() - interval '90 days'
  ORDER BY i.opened_at DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_invocation_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_invocation_history() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 7: founder_pr_kind_breakdown — coverage by crisis kind
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pr_kind_breakdown()
RETURNS TABLE(
  crisis_kind text,
  playbook_count int,
  p0_count int,
  p1_count int,
  p2_p3_count int,
  legal_review_count int,
  ever_invoked_count int,
  total_invocations int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.crisis_kind,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE p.severity_tier = 'p0'))::int,
    (COUNT(*) FILTER (WHERE p.severity_tier = 'p1'))::int,
    (COUNT(*) FILTER (WHERE p.severity_tier IN ('p2','p3')))::int,
    (COUNT(*) FILTER (WHERE p.legal_review_required))::int,
    (COUNT(*) FILTER (WHERE p.invocation_count > 0))::int,
    COALESCE(SUM(p.invocation_count), 0)::int
  FROM pr_crisis_playbooks p
  WHERE NOT p.is_archived
  GROUP BY p.crisis_kind
  ORDER BY 2 DESC, 1 ASC;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_pr_kind_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pr_kind_breakdown() TO authenticated;

-- ----------------------------------------------------------------------------
-- Founder action log entry
-- ----------------------------------------------------------------------------
INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
SELECT auth.uid(), (auth.jwt()->>'email'), 'r1654_pr_crisis_runbook_installed',
       jsonb_build_object('playbooks_seeded', (SELECT COUNT(*) FROM pr_crisis_playbooks), 'rpcs', 7),
       now()
WHERE auth.uid() IS NOT NULL;

COMMIT;