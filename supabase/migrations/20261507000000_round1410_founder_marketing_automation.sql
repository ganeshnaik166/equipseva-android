BEGIN;
-- r1410 — Founder Marketing Automation: lead capture + nurturing sequences
-- 3 tables + 8 RPCs. Founder-only via RLS + SECURITY DEFINER.

-- ============ TABLES ============

CREATE TABLE IF NOT EXISTS public.founder_marketing_leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_email text NOT NULL UNIQUE,
  lead_name text,
  lead_phone text,
  lead_company text,
  lead_source text NOT NULL DEFAULT 'website_form' CHECK (lead_source IN (
    'website_form','linkedin','google_ads','referral','event','outbound','other'
  )),
  lead_kind text NOT NULL DEFAULT 'hospital_prospect' CHECK (lead_kind IN (
    'hospital_prospect','engineer_recruit','partner_inquiry','press_media','investor_outbound','other'
  )),
  lead_score int NOT NULL DEFAULT 50 CHECK (lead_score >= 0 AND lead_score <= 100),
  funnel_stage text NOT NULL DEFAULT 'captured' CHECK (funnel_stage IN (
    'captured','engaged','qualified','meeting_booked','proposal_sent','closed_won','closed_lost','disqualified'
  )),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mkt_leads_stage ON public.founder_marketing_leads(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_mkt_leads_kind ON public.founder_marketing_leads(lead_kind);
CREATE INDEX IF NOT EXISTS idx_mkt_leads_source ON public.founder_marketing_leads(lead_source);
CREATE INDEX IF NOT EXISTS idx_mkt_leads_captured ON public.founder_marketing_leads(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_mkt_leads_score ON public.founder_marketing_leads(lead_score DESC);

ALTER TABLE public.founder_marketing_leads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_mkt_leads_founder ON public.founder_marketing_leads;
CREATE POLICY p_mkt_leads_founder ON public.founder_marketing_leads
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_marketing_nurturing_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sequence_label text NOT NULL UNIQUE,
  target_lead_kind text,
  total_steps int NOT NULL DEFAULT 5 CHECK (total_steps > 0),
  days_to_complete int NOT NULL DEFAULT 14 CHECK (days_to_complete > 0),
  is_active boolean NOT NULL DEFAULT true,
  sent_count int NOT NULL DEFAULT 0,
  conversion_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mkt_seq_active ON public.founder_marketing_nurturing_sequences(is_active);
CREATE INDEX IF NOT EXISTS idx_mkt_seq_target ON public.founder_marketing_nurturing_sequences(target_lead_kind);

ALTER TABLE public.founder_marketing_nurturing_sequences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_mkt_seq_founder ON public.founder_marketing_nurturing_sequences;
CREATE POLICY p_mkt_seq_founder ON public.founder_marketing_nurturing_sequences
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_marketing_lead_sequence_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid NOT NULL REFERENCES public.founder_marketing_leads(id) ON DELETE CASCADE,
  sequence_id uuid REFERENCES public.founder_marketing_nurturing_sequences(id) ON DELETE SET NULL,
  current_step int NOT NULL DEFAULT 1,
  total_steps_completed int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN (
    'active','paused','completed','dropped','converted'
  )),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  last_action_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mkt_runs_lead ON public.founder_marketing_lead_sequence_runs(lead_id);
CREATE INDEX IF NOT EXISTS idx_mkt_runs_seq ON public.founder_marketing_lead_sequence_runs(sequence_id);
CREATE INDEX IF NOT EXISTS idx_mkt_runs_status ON public.founder_marketing_lead_sequence_runs(status);
CREATE INDEX IF NOT EXISTS idx_mkt_runs_started ON public.founder_marketing_lead_sequence_runs(started_at DESC);

ALTER TABLE public.founder_marketing_lead_sequence_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_mkt_runs_founder ON public.founder_marketing_lead_sequence_runs;
CREATE POLICY p_mkt_runs_founder ON public.founder_marketing_lead_sequence_runs
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============ RPC 1: SUMMARY (16 KPIs) ============
DROP FUNCTION IF EXISTS public.founder_marketing_automation_summary();
CREATE OR REPLACE FUNCTION public.founder_marketing_automation_summary()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  SELECT jsonb_build_object(
    'leads_total', (SELECT COUNT(*) FROM public.founder_marketing_leads),
    'leads_captured_30d', (
      SELECT COUNT(*) FROM public.founder_marketing_leads
      WHERE captured_at >= now() - INTERVAL '30 days'
    ),
    'leads_qualified', (
      SELECT COUNT(*) FROM public.founder_marketing_leads
      WHERE funnel_stage IN ('qualified','meeting_booked','proposal_sent','closed_won')
    ),
    'leads_closed_won', (
      SELECT COUNT(*) FROM public.founder_marketing_leads WHERE funnel_stage = 'closed_won'
    ),
    'leads_closed_lost', (
      SELECT COUNT(*) FROM public.founder_marketing_leads WHERE funnel_stage = 'closed_lost'
    ),
    'leads_disqualified', (
      SELECT COUNT(*) FROM public.founder_marketing_leads WHERE funnel_stage = 'disqualified'
    ),
    'leads_in_flight', (
      SELECT COUNT(*) FROM public.founder_marketing_leads
      WHERE funnel_stage IN ('captured','engaged','qualified','meeting_booked','proposal_sent')
    ),
    'avg_lead_score', (
      SELECT COALESCE(ROUND(AVG(lead_score)::numeric, 1), 0)
      FROM public.founder_marketing_leads
    ),
    'high_score_leads', (
      SELECT COUNT(*) FROM public.founder_marketing_leads WHERE lead_score >= 75
    ),
    'sequences_total', (SELECT COUNT(*) FROM public.founder_marketing_nurturing_sequences),
    'sequences_active', (
      SELECT COUNT(*) FROM public.founder_marketing_nurturing_sequences WHERE is_active = true
    ),
    'runs_total', (SELECT COUNT(*) FROM public.founder_marketing_lead_sequence_runs),
    'runs_active', (
      SELECT COUNT(*) FROM public.founder_marketing_lead_sequence_runs WHERE status = 'active'
    ),
    'runs_converted', (
      SELECT COUNT(*) FROM public.founder_marketing_lead_sequence_runs WHERE status = 'converted'
    ),
    'runs_dropped', (
      SELECT COUNT(*) FROM public.founder_marketing_lead_sequence_runs WHERE status = 'dropped'
    ),
    'overall_conversion_rate_pct', (
      SELECT CASE WHEN COUNT(*) = 0 THEN 0
        ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE funnel_stage = 'closed_won') / COUNT(*)::numeric, 2)
      END
      FROM public.founder_marketing_leads
    )
  ) INTO v_result;
  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_automation_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_automation_summary() TO authenticated;

-- ============ RPC 2: LEADS RECENT ============
DROP FUNCTION IF EXISTS public.founder_marketing_leads_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_marketing_leads_recent(
  p_stage text DEFAULT NULL,
  p_kind text DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS TABLE (
  id uuid, lead_email text, lead_name text, lead_phone text, lead_company text,
  lead_source text, lead_kind text, lead_score int, funnel_stage text,
  captured_at timestamptz, notes text, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT l.id, l.lead_email, l.lead_name, l.lead_phone, l.lead_company,
         l.lead_source, l.lead_kind, l.lead_score, l.funnel_stage,
         l.captured_at, l.notes, l.created_at
  FROM public.founder_marketing_leads l
  WHERE (p_stage IS NULL OR l.funnel_stage = p_stage)
    AND (p_kind IS NULL OR l.lead_kind = p_kind)
  ORDER BY l.captured_at DESC, l.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_leads_recent(text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_leads_recent(text, text, int) TO authenticated;

-- ============ RPC 3: SEQUENCES RECENT ============
DROP FUNCTION IF EXISTS public.founder_marketing_sequences_recent(boolean, int);
CREATE OR REPLACE FUNCTION public.founder_marketing_sequences_recent(
  p_active boolean DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS TABLE (
  id uuid, sequence_label text, target_lead_kind text,
  total_steps int, days_to_complete int, is_active boolean,
  sent_count int, conversion_rate_pct numeric, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.sequence_label, s.target_lead_kind,
         s.total_steps, s.days_to_complete, s.is_active,
         s.sent_count, s.conversion_rate_pct, s.created_at
  FROM public.founder_marketing_nurturing_sequences s
  WHERE (p_active IS NULL OR s.is_active = p_active)
  ORDER BY s.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_sequences_recent(boolean, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_sequences_recent(boolean, int) TO authenticated;

-- ============ RPC 4: ACTIVE RUNS RECENT ============
DROP FUNCTION IF EXISTS public.founder_marketing_active_runs_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_marketing_active_runs_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 40
)
RETURNS TABLE (
  id uuid, lead_id uuid, sequence_id uuid,
  lead_email text, sequence_label text,
  current_step int, total_steps_completed int, status text,
  started_at timestamptz, completed_at timestamptz, last_action_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.lead_id, r.sequence_id,
         l.lead_email, s.sequence_label,
         r.current_step, r.total_steps_completed, r.status,
         r.started_at, r.completed_at, r.last_action_at
  FROM public.founder_marketing_lead_sequence_runs r
  LEFT JOIN public.founder_marketing_leads l ON l.id = r.lead_id
  LEFT JOIN public.founder_marketing_nurturing_sequences s ON s.id = r.sequence_id
  WHERE (p_status IS NULL OR r.status = p_status)
  ORDER BY r.started_at DESC, r.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_active_runs_recent(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_marketing_active_runs_recent(text, int) TO authenticated;

-- ============ RPC 5: CAPTURE LEAD ============
DROP FUNCTION IF EXISTS public.log_founder_marketing_capture_lead(text, text, text, text, text, text, int);
CREATE OR REPLACE FUNCTION public.log_founder_marketing_capture_lead(
  p_email text,
  p_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_company text DEFAULT NULL,
  p_source text DEFAULT 'website_form',
  p_kind text DEFAULT 'hospital_prospect',
  p_score int DEFAULT 50
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_marketing_leads (
    lead_email, lead_name, lead_phone, lead_company,
    lead_source, lead_kind, lead_score
  ) VALUES (p_email, p_name, p_phone, p_company, p_source, p_kind, p_score)
  ON CONFLICT (lead_email) DO UPDATE
    SET lead_name = COALESCE(EXCLUDED.lead_name, founder_marketing_leads.lead_name),
        lead_phone = COALESCE(EXCLUDED.lead_phone, founder_marketing_leads.lead_phone),
        lead_company = COALESCE(EXCLUDED.lead_company, founder_marketing_leads.lead_company),
        lead_score = GREATEST(EXCLUDED.lead_score, founder_marketing_leads.lead_score),
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_marketing_capture_lead(text, text, text, text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_capture_lead(text, text, text, text, text, text, int) TO authenticated;

-- ============ RPC 6: ADVANCE LEAD STAGE ============
DROP FUNCTION IF EXISTS public.log_founder_marketing_advance_lead_stage(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_marketing_advance_lead_stage(
  p_lead_id uuid,
  p_new_stage text,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_new_stage NOT IN (
    'captured','engaged','qualified','meeting_booked','proposal_sent','closed_won','closed_lost','disqualified'
  ) THEN
    RAISE EXCEPTION 'invalid funnel_stage: %', p_new_stage USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_marketing_leads
     SET funnel_stage = p_new_stage,
         notes = COALESCE(p_notes, notes),
         updated_at = now()
   WHERE id = p_lead_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_marketing_advance_lead_stage(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_advance_lead_stage(uuid, text, text) TO authenticated;

-- ============ RPC 7: REGISTER SEQUENCE ============
DROP FUNCTION IF EXISTS public.log_founder_marketing_register_sequence(text, text, int, int);
CREATE OR REPLACE FUNCTION public.log_founder_marketing_register_sequence(
  p_label text,
  p_target_kind text DEFAULT NULL,
  p_total_steps int DEFAULT 5,
  p_days_to_complete int DEFAULT 14
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_marketing_nurturing_sequences (
    sequence_label, target_lead_kind, total_steps, days_to_complete
  ) VALUES (p_label, p_target_kind, p_total_steps, p_days_to_complete)
  ON CONFLICT (sequence_label) DO UPDATE
    SET target_lead_kind = COALESCE(EXCLUDED.target_lead_kind, founder_marketing_nurturing_sequences.target_lead_kind),
        total_steps = EXCLUDED.total_steps,
        days_to_complete = EXCLUDED.days_to_complete,
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_marketing_register_sequence(text, text, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_register_sequence(text, text, int, int) TO authenticated;

-- ============ RPC 8: START SEQUENCE RUN ============
DROP FUNCTION IF EXISTS public.log_founder_marketing_start_sequence_run(uuid, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_marketing_start_sequence_run(
  p_lead_id uuid,
  p_sequence_id uuid
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_marketing_lead_sequence_runs (
    lead_id, sequence_id, current_step, total_steps_completed,
    status, started_at, last_action_at
  ) VALUES (p_lead_id, p_sequence_id, 1, 0, 'active', now(), now())
  RETURNING id INTO v_id;
  UPDATE public.founder_marketing_nurturing_sequences
     SET sent_count = sent_count + 1, updated_at = now()
   WHERE id = p_sequence_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_marketing_start_sequence_run(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_marketing_start_sequence_run(uuid, uuid) TO authenticated;

COMMIT;