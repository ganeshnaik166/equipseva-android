BEGIN;

-- =========================================================================
-- Round 1600 — Founder Investor Pro-Rata Rights Tracker
-- Per-investor pro-rata %; current-round pro-rata amount; election deadline;
-- founder follow-up workflow.
-- =========================================================================

-- ---------- TABLE 1 : investor pro-rata registry ------------------------
CREATE TABLE IF NOT EXISTS public.investor_pro_rata_rights (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name            text NOT NULL,
  investor_email           text,
  investor_org             text,
  pro_rata_pct             numeric(7,4) NOT NULL CHECK (pro_rata_pct >= 0 AND pro_rata_pct <= 100),
  prior_round_label        text,
  prior_round_invested_rupees numeric(14,2) NOT NULL DEFAULT 0 CHECK (prior_round_invested_rupees >= 0),
  current_round_label      text NOT NULL,
  current_round_size_rupees numeric(16,2) NOT NULL CHECK (current_round_size_rupees >= 0),
  pro_rata_amount_rupees   numeric(14,2) NOT NULL DEFAULT 0 CHECK (pro_rata_amount_rupees >= 0),
  election_deadline        timestamptz NOT NULL,
  notice_sent_at           timestamptz,
  reminder_count           integer NOT NULL DEFAULT 0 CHECK (reminder_count >= 0),
  election_status          text NOT NULL DEFAULT 'pending'
                           CHECK (election_status IN ('pending','exercised','partial','waived','expired')),
  exercised_amount_rupees  numeric(14,2) NOT NULL DEFAULT 0 CHECK (exercised_amount_rupees >= 0),
  waiver_reason            text,
  legal_notice_required    boolean NOT NULL DEFAULT true,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iprr_deadline ON public.investor_pro_rata_rights(election_deadline);
CREATE INDEX IF NOT EXISTS idx_iprr_status ON public.investor_pro_rata_rights(election_status);
CREATE INDEX IF NOT EXISTS idx_iprr_round ON public.investor_pro_rata_rights(current_round_label);

ALTER TABLE public.investor_pro_rata_rights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iprr_founder_only ON public.investor_pro_rata_rights;
CREATE POLICY iprr_founder_only ON public.investor_pro_rata_rights
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------- TABLE 2 : follow-up touchpoint log --------------------------
CREATE TABLE IF NOT EXISTS public.investor_pro_rata_followups (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rights_id       uuid NOT NULL REFERENCES public.investor_pro_rata_rights(id) ON DELETE CASCADE,
  channel         text NOT NULL CHECK (channel IN ('email','call','whatsapp','in_person','sms')),
  outcome         text NOT NULL CHECK (outcome IN ('contacted','no_response','intent_exercise','intent_waive','negotiating','escalated')),
  next_action_at  timestamptz,
  founder_note    text,
  logged_by_email text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iprr_followup_rights ON public.investor_pro_rata_followups(rights_id);
CREATE INDEX IF NOT EXISTS idx_iprr_followup_next ON public.investor_pro_rata_followups(next_action_at);

ALTER TABLE public.investor_pro_rata_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iprr_followup_founder_only ON public.investor_pro_rata_followups;
CREATE POLICY iprr_followup_founder_only ON public.investor_pro_rata_followups
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

DROP FUNCTION IF EXISTS public.rpc_iprr_summary_kpis();
CREATE OR REPLACE FUNCTION public.rpc_iprr_summary_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'investor_count', COUNT(*),
    'pending_count', COUNT(*) FILTER (WHERE election_status='pending'),
    'exercised_count', COUNT(*) FILTER (WHERE election_status='exercised'),
    'waived_count', COUNT(*) FILTER (WHERE election_status='waived'),
    'partial_count', COUNT(*) FILTER (WHERE election_status='partial'),
    'expired_count', COUNT(*) FILTER (WHERE election_status='expired'),
    'total_pro_rata_pct', COALESCE(SUM(pro_rata_pct),0),
    'total_pro_rata_amount', COALESCE(SUM(pro_rata_amount_rupees),0),
    'total_exercised_amount', COALESCE(SUM(exercised_amount_rupees),0),
    'total_waived_amount', COALESCE(SUM(CASE WHEN election_status='waived' THEN pro_rata_amount_rupees ELSE 0 END),0),
    'overdue_count', COUNT(*) FILTER (WHERE election_deadline < now() AND election_status='pending'),
    'due_7d_count', COUNT(*) FILTER (WHERE election_deadline BETWEEN now() AND now() + interval '7 days' AND election_status='pending'),
    'never_contacted', COUNT(*) FILTER (WHERE notice_sent_at IS NULL),
    'avg_reminder_count', ROUND(COALESCE(AVG(reminder_count),0)::numeric, 2),
    'legal_notice_pending', COUNT(*) FILTER (WHERE legal_notice_required AND notice_sent_at IS NULL),
    'exercise_rate_pct', CASE WHEN SUM(pro_rata_amount_rupees) > 0
        THEN ROUND((SUM(exercised_amount_rupees) / SUM(pro_rata_amount_rupees) * 100)::numeric, 2)
        ELSE 0 END
  ) INTO result
  FROM investor_pro_rata_rights;
  RETURN COALESCE(result, '{}'::jsonb);
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_summary_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_summary_kpis() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_list_rights();
CREATE OR REPLACE FUNCTION public.rpc_iprr_list_rights()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  investor_org text,
  pro_rata_pct numeric,
  pro_rata_amount_rupees numeric,
  exercised_amount_rupees numeric,
  current_round_label text,
  election_status text,
  election_deadline timestamptz,
  days_to_deadline numeric,
  reminder_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.investor_email, r.investor_org,
         r.pro_rata_pct, r.pro_rata_amount_rupees, r.exercised_amount_rupees,
         r.current_round_label, r.election_status, r.election_deadline,
         ROUND(EXTRACT(EPOCH FROM (r.election_deadline - now()))/86400.0, 1) AS days_to_deadline,
         r.reminder_count
  FROM investor_pro_rata_rights r
  ORDER BY r.election_deadline ASC, r.pro_rata_amount_rupees DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_list_rights() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_list_rights() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_overdue();
CREATE OR REPLACE FUNCTION public.rpc_iprr_overdue()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  pro_rata_amount_rupees numeric,
  election_deadline timestamptz,
  days_overdue numeric,
  reminder_count integer,
  notice_sent_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.investor_email, r.pro_rata_amount_rupees,
         r.election_deadline,
         ROUND(EXTRACT(EPOCH FROM (now() - r.election_deadline))/86400.0, 1) AS days_overdue,
         r.reminder_count, r.notice_sent_at
  FROM investor_pro_rata_rights r
  WHERE r.election_status = 'pending'
    AND r.election_deadline < now()
  ORDER BY r.election_deadline ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_overdue() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_upcoming_deadlines();
CREATE OR REPLACE FUNCTION public.rpc_iprr_upcoming_deadlines()
RETURNS TABLE (
  id uuid,
  investor_name text,
  current_round_label text,
  pro_rata_pct numeric,
  pro_rata_amount_rupees numeric,
  election_deadline timestamptz,
  days_remaining numeric,
  reminder_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.current_round_label,
         r.pro_rata_pct, r.pro_rata_amount_rupees,
         r.election_deadline,
         ROUND(EXTRACT(EPOCH FROM (r.election_deadline - now()))/86400.0, 1) AS days_remaining,
         r.reminder_count
  FROM investor_pro_rata_rights r
  WHERE r.election_status = 'pending'
    AND r.election_deadline BETWEEN now() AND now() + interval '30 days'
  ORDER BY r.election_deadline ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_upcoming_deadlines() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_upcoming_deadlines() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_recent_followups();
CREATE OR REPLACE FUNCTION public.rpc_iprr_recent_followups()
RETURNS TABLE (
  id uuid,
  rights_id uuid,
  investor_name text,
  channel text,
  outcome text,
  next_action_at timestamptz,
  founder_note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.rights_id, r.investor_name, f.channel, f.outcome,
         f.next_action_at, f.founder_note, f.created_at
  FROM investor_pro_rata_followups f
  JOIN investor_pro_rata_rights r ON r.id = f.rights_id
  ORDER BY f.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_recent_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_recent_followups() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_status_breakdown();
CREATE OR REPLACE FUNCTION public.rpc_iprr_status_breakdown()
RETURNS TABLE (
  election_status text,
  investor_count bigint,
  total_amount_rupees numeric,
  pct_of_round numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  total_round numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT NULLIF(SUM(pro_rata_amount_rupees), 0) INTO total_round
  FROM investor_pro_rata_rights;
  RETURN QUERY
  SELECT r.election_status,
         COUNT(*)::bigint AS investor_count,
         COALESCE(SUM(r.pro_rata_amount_rupees), 0) AS total_amount_rupees,
         CASE WHEN total_round IS NULL THEN 0
              ELSE ROUND((SUM(r.pro_rata_amount_rupees) / total_round * 100)::numeric, 2)
         END AS pct_of_round
  FROM investor_pro_rata_rights r
  GROUP BY r.election_status
  ORDER BY total_amount_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_status_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS public.rpc_iprr_action_queue();
CREATE OR REPLACE FUNCTION public.rpc_iprr_action_queue()
RETURNS TABLE (
  id uuid,
  investor_name text,
  reason text,
  pro_rata_amount_rupees numeric,
  election_deadline timestamptz,
  reminder_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name,
         CASE
           WHEN r.notice_sent_at IS NULL THEN 'send_initial_notice'
           WHEN r.election_deadline < now() AND r.election_status='pending' THEN 'overdue_escalate'
           WHEN r.election_deadline < now() + interval '3 days' AND r.election_status='pending' THEN 'final_reminder'
           WHEN r.reminder_count = 0 AND r.election_deadline < now() + interval '14 days' THEN 'first_reminder'
           ELSE 'monitor'
         END AS reason,
         r.pro_rata_amount_rupees, r.election_deadline, r.reminder_count
  FROM investor_pro_rata_rights r
  WHERE r.election_status='pending'
  ORDER BY r.election_deadline ASC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.rpc_iprr_action_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_iprr_action_queue() TO authenticated;

-- =========================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =========================================================================

DROP FUNCTION IF EXISTS public.log_founder_iprr_notice_sent(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_iprr_notice_sent(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_pro_rata_rights
     SET notice_sent_at = COALESCE(notice_sent_at, now()),
         reminder_count = reminder_count + 1,
         updated_at = now()
   WHERE id = p_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iprr_notice_sent',
          jsonb_build_object('rights_id', p_id, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_iprr_notice_sent(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_iprr_notice_sent(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_iprr_election_recorded(uuid, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_iprr_election_recorded(
  p_id uuid, p_status text, p_exercised_amount numeric
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('exercised','partial','waived','expired','pending') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE investor_pro_rata_rights
     SET election_status = p_status,
         exercised_amount_rupees = COALESCE(p_exercised_amount, 0),
         updated_at = now()
   WHERE id = p_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iprr_election_recorded',
          jsonb_build_object('rights_id', p_id, 'status', p_status, 'exercised', p_exercised_amount));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_iprr_election_recorded(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_iprr_election_recorded(uuid, text, numeric) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_iprr_followup_added(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_iprr_followup_added(
  p_rights_id uuid, p_channel text, p_outcome text, p_note text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_pro_rata_followups (rights_id, channel, outcome, founder_note, logged_by_email)
  VALUES (p_rights_id, p_channel, p_outcome, p_note, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iprr_followup_added',
          jsonb_build_object('rights_id', p_rights_id, 'followup_id', v_id, 'channel', p_channel, 'outcome', p_outcome));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_iprr_followup_added(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_iprr_followup_added(uuid, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_iprr_rights_upserted(uuid, text, numeric, numeric, timestamptz);
CREATE OR REPLACE FUNCTION public.log_founder_iprr_rights_upserted(
  p_id uuid, p_investor_name text, p_pct numeric, p_amount numeric, p_deadline timestamptz
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iprr_rights_upserted',
          jsonb_build_object(
            'rights_id', p_id,
            'investor_name', p_investor_name,
            'pro_rata_pct', p_pct,
            'pro_rata_amount_rupees', p_amount,
            'election_deadline', p_deadline));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_iprr_rights_upserted(uuid, text, numeric, numeric, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_iprr_rights_upserted(uuid, text, numeric, numeric, timestamptz) TO authenticated;

COMMIT;