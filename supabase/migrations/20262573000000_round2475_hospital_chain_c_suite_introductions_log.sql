-- Round 2475: hospital-chain-c-suite-introductions-log
-- Chain x C-suite name x intro source x intro at x follow-up x deal influence x deck shared.

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_c_suite_intros_r2475 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  c_suite_name text NOT NULL,
  c_suite_role text NOT NULL DEFAULT 'ceo' CHECK (c_suite_role IN ('ceo','coo','cmo','cfo','cio','chief_medical_officer','owner')),
  intro_source_kind text NOT NULL DEFAULT 'investor' CHECK (intro_source_kind IN ('investor','customer','advisor','event','cold_outreach','employee_referral')),
  intro_source_name text,
  intro_at timestamptz,
  follow_up_at timestamptz,
  follow_up_owner_email text,
  deal_influence text NOT NULL DEFAULT 'medium' CHECK (deal_influence IN ('none','low','medium','high','critical')),
  deck_shared_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_chain ON public.chain_c_suite_intros_r2475(chain_name);
CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_role ON public.chain_c_suite_intros_r2475(c_suite_role);
CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_source ON public.chain_c_suite_intros_r2475(intro_source_kind);
CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_status ON public.chain_c_suite_intros_r2475(status);
CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_influence ON public.chain_c_suite_intros_r2475(deal_influence);
CREATE INDEX IF NOT EXISTS idx_chain_c_suite_intros_r2475_intro_at ON public.chain_c_suite_intros_r2475(intro_at);

CREATE TABLE IF NOT EXISTS public.c_suite_intro_outcomes_r2475 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intro_id uuid NOT NULL REFERENCES public.chain_c_suite_intros_r2475(id) ON DELETE CASCADE,
  outcome_at timestamptz,
  outcome_kind text NOT NULL DEFAULT 'meeting_held' CHECK (outcome_kind IN ('meeting_held','proposal_sent','champion_secured','passed','stalled','deal_closed')),
  outcome_summary text,
  value_rupees bigint,
  next_step text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_c_suite_intro_outcomes_r2475_intro ON public.c_suite_intro_outcomes_r2475(intro_id);
CREATE INDEX IF NOT EXISTS idx_c_suite_intro_outcomes_r2475_kind ON public.c_suite_intro_outcomes_r2475(outcome_kind);
CREATE INDEX IF NOT EXISTS idx_c_suite_intro_outcomes_r2475_at ON public.c_suite_intro_outcomes_r2475(outcome_at);

ALTER TABLE public.chain_c_suite_intros_r2475 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.c_suite_intro_outcomes_r2475 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_c_suite_intros_r2475;
CREATE POLICY founder_all ON public.chain_c_suite_intros_r2475
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.c_suite_intro_outcomes_r2475;
CREATE POLICY founder_all ON public.c_suite_intro_outcomes_r2475
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $$
DECLARE
  v_i1 uuid;
  v_i2 uuid;
  v_i3 uuid;
  v_i4 uuid;
  v_i5 uuid;
BEGIN
  INSERT INTO public.chain_c_suite_intros_r2475(chain_name, c_suite_name, c_suite_role, intro_source_kind, intro_source_name, intro_at, follow_up_at, follow_up_owner_email, deal_influence, deck_shared_at, status, notes)
  VALUES ('Apollo Hospitals', 'Dr Suresh Menon', 'ceo', 'investor', 'Accel Partner Ravi', '2026-05-10 11:00:00'::timestamptz, '2026-07-05 10:00:00'::timestamptz, 'founder@equipseva.com', 'critical', '2026-05-12 09:00:00'::timestamptz, 'in_progress', 'Warm intro, deck shared, follow-up scheduled')
  RETURNING id INTO v_i1;

  INSERT INTO public.chain_c_suite_intros_r2475(chain_name, c_suite_name, c_suite_role, intro_source_kind, intro_source_name, intro_at, follow_up_at, follow_up_owner_email, deal_influence, deck_shared_at, status, notes)
  VALUES ('Fortis Healthcare', 'Anita Kapoor', 'coo', 'customer', 'Manipal Bengaluru', '2026-04-22 14:30:00'::timestamptz, '2026-06-30 11:00:00'::timestamptz, 'sales@equipseva.com', 'high', '2026-04-25 16:00:00'::timestamptz, 'open', 'Operational champion identified')
  RETURNING id INTO v_i2;

  INSERT INTO public.chain_c_suite_intros_r2475(chain_name, c_suite_name, c_suite_role, intro_source_kind, intro_source_name, intro_at, follow_up_at, follow_up_owner_email, deal_influence, deck_shared_at, status, notes)
  VALUES ('Manipal Hospitals', 'Vikram Shetty', 'cio', 'advisor', 'Board advisor Lakshmi', '2026-03-15 10:00:00'::timestamptz, '2026-06-25 15:00:00'::timestamptz, 'founder@equipseva.com', 'high', '2026-03-18 11:00:00'::timestamptz, 'done', 'Pilot signed for 3 sites')
  RETURNING id INTO v_i3;

  INSERT INTO public.chain_c_suite_intros_r2475(chain_name, c_suite_name, c_suite_role, intro_source_kind, intro_source_name, intro_at, follow_up_at, follow_up_owner_email, deal_influence, deck_shared_at, status, notes)
  VALUES ('Max Healthcare', 'Dr Pooja Sinha', 'chief_medical_officer', 'event', 'FICCI Health Summit 2026', '2026-06-01 16:00:00'::timestamptz, '2026-07-10 14:00:00'::timestamptz, 'founder@equipseva.com', 'medium', NULL, 'open', 'Met at FICCI; needs follow-up')
  RETURNING id INTO v_i4;

  INSERT INTO public.chain_c_suite_intros_r2475(chain_name, c_suite_name, c_suite_role, intro_source_kind, intro_source_name, intro_at, follow_up_at, follow_up_owner_email, deal_influence, deck_shared_at, status, notes)
  VALUES ('Narayana Health', 'Rakesh Iyengar', 'cfo', 'employee_referral', 'VP Sales Arjun', '2026-02-20 13:00:00'::timestamptz, '2026-06-22 10:00:00'::timestamptz, 'cfo@equipseva.com', 'low', '2026-02-22 10:00:00'::timestamptz, 'dropped', 'Budget cycle misaligned, revisit Q4')
  RETURNING id INTO v_i5;

  IF v_i1 IS NOT NULL THEN
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i1, '2026-05-20 11:00:00'::timestamptz, 'meeting_held', 'First exec meeting at Apollo HQ', 0, 'Send commercial proposal', 'founder@equipseva.com', 'Strong receptivity');
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i1, '2026-06-10 15:00:00'::timestamptz, 'proposal_sent', 'Proposal for 12-site rollout', 24000000, 'Awaiting committee review', 'founder@equipseva.com', NULL);
  END IF;

  IF v_i2 IS NOT NULL THEN
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i2, '2026-05-05 14:00:00'::timestamptz, 'champion_secured', 'COO endorsed internal champion', 0, 'Schedule CTO-level demo', 'sales@equipseva.com', 'Champion = ops director Reema');
  END IF;

  IF v_i3 IS NOT NULL THEN
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i3, '2026-04-10 10:00:00'::timestamptz, 'deal_closed', 'Manipal 3-site pilot signed', 8500000, 'Kick off implementation', 'founder@equipseva.com', 'First chain deal');
  END IF;

  IF v_i4 IS NOT NULL THEN
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i4, '2026-06-08 12:00:00'::timestamptz, 'stalled', 'No response to two follow-ups', 0, 'Try advisor warm-touch', 'founder@equipseva.com', NULL);
  END IF;

  IF v_i5 IS NOT NULL THEN
    INSERT INTO public.c_suite_intro_outcomes_r2475(intro_id, outcome_at, outcome_kind, outcome_summary, value_rupees, next_step, owner_email, notes)
    VALUES (v_i5, '2026-03-15 14:00:00'::timestamptz, 'passed', 'Budget on hold this fiscal', 0, 'Re-engage Q4 FY27', 'cfo@equipseva.com', 'Maintain warm relationship');
  END IF;
END $$;

-- RPC 1: list_intros_r2475
CREATE OR REPLACE FUNCTION public.list_intros_r2475()
RETURNS TABLE(
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  c_suite_name text,
  c_suite_role text,
  intro_source_kind text,
  intro_source_name text,
  intro_at timestamptz,
  follow_up_at timestamptz,
  follow_up_owner_email text,
  deal_influence text,
  deck_shared_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.chain_name, i.hospital_user_id, i.c_suite_name, i.c_suite_role,
         i.intro_source_kind, i.intro_source_name, i.intro_at, i.follow_up_at,
         i.follow_up_owner_email, i.deal_influence, i.deck_shared_at,
         i.status, i.notes, i.created_at
  FROM public.chain_c_suite_intros_r2475 i
  ORDER BY COALESCE(i.intro_at, i.created_at) DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_intros_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_intros_r2475() TO authenticated;

-- RPC 2: list_outcomes_r2475
CREATE OR REPLACE FUNCTION public.list_outcomes_r2475()
RETURNS TABLE(
  id uuid,
  intro_id uuid,
  chain_name text,
  c_suite_name text,
  c_suite_role text,
  outcome_at timestamptz,
  outcome_kind text,
  outcome_summary text,
  value_rupees bigint,
  next_step text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.intro_id, i.chain_name, i.c_suite_name, i.c_suite_role,
         o.outcome_at, o.outcome_kind, o.outcome_summary, o.value_rupees,
         o.next_step, o.owner_email, o.notes, o.created_at
  FROM public.c_suite_intro_outcomes_r2475 o
  LEFT JOIN public.chain_c_suite_intros_r2475 i ON i.id = o.intro_id
  ORDER BY COALESCE(o.outcome_at, o.created_at) DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2475() TO authenticated;

-- RPC 3: top_value_intros_r2475
CREATE OR REPLACE FUNCTION public.top_value_intros_r2475()
RETURNS TABLE(
  intro_id uuid,
  chain_name text,
  c_suite_name text,
  c_suite_role text,
  intro_source_kind text,
  deal_influence text,
  total_value_rupees bigint,
  outcome_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.chain_name, i.c_suite_name, i.c_suite_role,
         i.intro_source_kind, i.deal_influence,
         COALESCE(SUM(o.value_rupees), 0)::bigint AS total_value_rupees,
         COUNT(o.id)::int AS outcome_count
  FROM public.chain_c_suite_intros_r2475 i
  LEFT JOIN public.c_suite_intro_outcomes_r2475 o ON o.intro_id = i.id
  GROUP BY i.id, i.chain_name, i.c_suite_name, i.c_suite_role, i.intro_source_kind, i.deal_influence
  ORDER BY total_value_rupees DESC, outcome_count DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_value_intros_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_intros_r2475() TO authenticated;

-- RPC 4: source_breakdown_r2475
CREATE OR REPLACE FUNCTION public.source_breakdown_r2475()
RETURNS TABLE(
  intro_source_kind text,
  intro_count int,
  pct numeric,
  done_count int,
  in_progress_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.chain_c_suite_intros_r2475;
  RETURN QUERY
  SELECT i.intro_source_kind,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total, 0), 2),
         SUM(CASE WHEN i.status = 'done' THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN i.status = 'in_progress' THEN 1 ELSE 0 END)::int,
         COALESCE(SUM(o.value_rupees), 0)::bigint
  FROM public.chain_c_suite_intros_r2475 i
  LEFT JOIN public.c_suite_intro_outcomes_r2475 o ON o.intro_id = i.id
  GROUP BY i.intro_source_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.source_breakdown_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.source_breakdown_r2475() TO authenticated;

-- RPC 5: role_breakdown_r2475
CREATE OR REPLACE FUNCTION public.role_breakdown_r2475()
RETURNS TABLE(
  c_suite_role text,
  intro_count int,
  pct numeric,
  high_critical_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.chain_c_suite_intros_r2475;
  RETURN QUERY
  SELECT i.c_suite_role,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total, 0), 2),
         SUM(CASE WHEN i.deal_influence IN ('high','critical') THEN 1 ELSE 0 END)::int,
         COALESCE(SUM(o.value_rupees), 0)::bigint
  FROM public.chain_c_suite_intros_r2475 i
  LEFT JOIN public.c_suite_intro_outcomes_r2475 o ON o.intro_id = i.id
  GROUP BY i.c_suite_role
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.role_breakdown_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_breakdown_r2475() TO authenticated;

-- RPC 6: deal_influence_summary_r2475
CREATE OR REPLACE FUNCTION public.deal_influence_summary_r2475()
RETURNS TABLE(
  deal_influence text,
  intro_count int,
  pct numeric,
  deck_shared_count int,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.chain_c_suite_intros_r2475;
  RETURN QUERY
  SELECT i.deal_influence,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total, 0), 2),
         SUM(CASE WHEN i.deck_shared_at IS NOT NULL THEN 1 ELSE 0 END)::int,
         COALESCE(SUM(o.value_rupees), 0)::bigint
  FROM public.chain_c_suite_intros_r2475 i
  LEFT JOIN public.c_suite_intro_outcomes_r2475 o ON o.intro_id = i.id
  GROUP BY i.deal_influence
  ORDER BY
    CASE i.deal_influence
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      WHEN 'none' THEN 5
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.deal_influence_summary_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deal_influence_summary_r2475() TO authenticated;

-- RPC 7: recent_outcomes_focus_r2475
CREATE OR REPLACE FUNCTION public.recent_outcomes_focus_r2475()
RETURNS TABLE(
  outcome_id uuid,
  intro_id uuid,
  chain_name text,
  c_suite_name text,
  c_suite_role text,
  outcome_kind text,
  outcome_summary text,
  value_rupees bigint,
  next_step text,
  owner_email text,
  outcome_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.intro_id, i.chain_name, i.c_suite_name, i.c_suite_role,
         o.outcome_kind, o.outcome_summary, o.value_rupees, o.next_step,
         o.owner_email, o.outcome_at
  FROM public.c_suite_intro_outcomes_r2475 o
  LEFT JOIN public.chain_c_suite_intros_r2475 i ON i.id = o.intro_id
  WHERE o.outcome_kind IN ('meeting_held','proposal_sent','champion_secured','deal_closed')
    AND COALESCE(o.outcome_at, o.created_at) >= (now() - interval '90 days')
  ORDER BY COALESCE(o.outcome_at, o.created_at) DESC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_outcomes_focus_r2475() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_outcomes_focus_r2475() TO authenticated;

