-- Round 2669: Founder Monthly Board Investor Update Impact
-- Tables track monthly board updates sent to investors and follow-up actions taken

CREATE TABLE IF NOT EXISTS public.founder_board_update_impact_r2669 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  sent_at timestamptz NOT NULL,
  recipients_count int NOT NULL DEFAULT 0,
  open_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  reply_count int NOT NULL DEFAULT 0,
  ask_resolved_count int NOT NULL DEFAULT 0,
  top_takeaway_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','responded','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.update_followup_actions_r2669 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id uuid NOT NULL REFERENCES public.founder_board_update_impact_r2669(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('intro','help_with_metric','board_question','follow_up_call','strategic_advice')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_board_update_impact_r2669 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.update_followup_actions_r2669 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_board_update_impact_r2669;
CREATE POLICY founder_all ON public.founder_board_update_impact_r2669
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.update_followup_actions_r2669;
CREATE POLICY founder_all ON public.update_followup_actions_r2669
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.founder_board_update_impact_r2669 (month_label, sent_at, recipients_count, open_rate_pct, reply_count, ask_resolved_count, top_takeaway_md, owner_email, status, notes) VALUES
  ('Feb 2026', '2026-03-02 09:00:00+05:30'::timestamptz, 18, 88.50, 6, 2, 'Strong AMC traction, ask for hospital intros in Pune', 'founder@equipseva.com', 'closed', 'All replies actioned'),
  ('Mar 2026', '2026-04-02 09:00:00+05:30'::timestamptz, 22, 92.30, 9, 4, 'GMV milestone hit, focus shifting to engineer retention', 'founder@equipseva.com', 'closed', 'Two strategic intros materialised'),
  ('Apr 2026', '2026-05-02 09:00:00+05:30'::timestamptz, 24, 87.00, 7, 3, 'Cashfree activation pending, runway 14 months', 'founder@equipseva.com', 'responded', 'Three asks still open'),
  ('May 2026', '2026-06-02 09:00:00+05:30'::timestamptz, 26, 90.10, 11, 1, 'Tier-1 home dashboard live, NABH conformance shipped', 'founder@equipseva.com', 'sent', 'Awaiting reply consolidation'),
  ('Jun 2026', '2026-06-19 09:00:00+05:30'::timestamptz, 27, 0.00, 0, 0, 'Draft pending final metrics from board pack', 'founder@equipseva.com', 'draft', 'Send window 1-3 Jul');

INSERT INTO public.update_followup_actions_r2669 (update_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, sent_at + interval '2 days', 'intro', 'positive', 'founder@equipseva.com', 'done', 'Warm intro to Apollo BD lead'
FROM public.founder_board_update_impact_r2669 WHERE month_label = 'Feb 2026';

INSERT INTO public.update_followup_actions_r2669 (update_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, sent_at + interval '3 days', 'help_with_metric', 'positive', 'founder@equipseva.com', 'done', 'Investor flagged churn drift, coached on cohorting'
FROM public.founder_board_update_impact_r2669 WHERE month_label = 'Mar 2026';

INSERT INTO public.update_followup_actions_r2669 (update_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, sent_at + interval '5 days', 'board_question', 'neutral', 'founder@equipseva.com', 'open', 'Question on unit economics deferred to next board'
FROM public.founder_board_update_impact_r2669 WHERE month_label = 'Apr 2026';

INSERT INTO public.update_followup_actions_r2669 (update_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, sent_at + interval '4 days', 'follow_up_call', 'positive', 'founder@equipseva.com', 'done', 'Half hour deep dive with lead investor'
FROM public.founder_board_update_impact_r2669 WHERE month_label = 'May 2026';

INSERT INTO public.update_followup_actions_r2669 (update_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, sent_at + interval '6 days', 'strategic_advice', 'pending', 'founder@equipseva.com', 'open', 'Asked for hiring guidance on VP Engineering'
FROM public.founder_board_update_impact_r2669 WHERE month_label = 'May 2026';

-- RPC 1: list updates
CREATE OR REPLACE FUNCTION public.list_updates_r2669()
RETURNS TABLE (
  id uuid,
  month_label text,
  sent_at timestamptz,
  recipients_count int,
  open_rate_pct numeric,
  reply_count int,
  ask_resolved_count int,
  top_takeaway_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.month_label, u.sent_at, u.recipients_count, u.open_rate_pct,
         u.reply_count, u.ask_resolved_count, u.top_takeaway_md, u.owner_email, u.status, u.notes
  FROM public.founder_board_update_impact_r2669 u
  ORDER BY u.sent_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_updates_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_updates_r2669() TO authenticated;

-- RPC 2: list followup actions
CREATE OR REPLACE FUNCTION public.list_followup_actions_r2669()
RETURNS TABLE (
  id uuid,
  update_id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.update_id, u.month_label, a.action_at, a.action_kind, a.outcome,
         a.owner_email, a.status, a.notes
  FROM public.update_followup_actions_r2669 a
  JOIN public.founder_board_update_impact_r2669 u ON u.id = a.update_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followup_actions_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_actions_r2669() TO authenticated;

-- RPC 3: top response focus (which updates drove most replies)
CREATE OR REPLACE FUNCTION public.top_response_focus_r2669()
RETURNS TABLE (
  month_label text,
  reply_count int,
  ask_resolved_count int,
  open_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.month_label, u.reply_count, u.ask_resolved_count, u.open_rate_pct
  FROM public.founder_board_update_impact_r2669 u
  WHERE u.status <> 'draft'
  ORDER BY u.reply_count DESC, u.ask_resolved_count DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_response_focus_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_response_focus_r2669() TO authenticated;

-- RPC 4: action kind distribution
CREATE OR REPLACE FUNCTION public.action_kind_distribution_r2669()
RETURNS TABLE (
  action_kind text,
  total_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_count
  FROM public.update_followup_actions_r2669 a
  GROUP BY a.action_kind
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_distribution_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_distribution_r2669() TO authenticated;

-- RPC 5: status funnel
CREATE OR REPLACE FUNCTION public.status_funnel_r2669()
RETURNS TABLE (
  status text,
  update_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.status, COUNT(*)::bigint AS update_count
  FROM public.founder_board_update_impact_r2669 u
  GROUP BY u.status
  ORDER BY
    CASE u.status
      WHEN 'draft' THEN 1
      WHEN 'sent' THEN 2
      WHEN 'responded' THEN 3
      WHEN 'closed' THEN 4
      ELSE 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2669() TO authenticated;

-- RPC 6: monthly update trend
CREATE OR REPLACE FUNCTION public.monthly_update_trend_r2669()
RETURNS TABLE (
  month_label text,
  sent_at timestamptz,
  recipients_count int,
  open_rate_pct numeric,
  reply_count int,
  reply_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.month_label,
         u.sent_at,
         u.recipients_count,
         u.open_rate_pct,
         u.reply_count,
         CASE WHEN u.recipients_count > 0
              THEN ROUND((u.reply_count::numeric / u.recipients_count) * 100, 2)
              ELSE 0
         END AS reply_rate_pct
  FROM public.founder_board_update_impact_r2669 u
  ORDER BY u.sent_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_update_trend_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_update_trend_r2669() TO authenticated;

-- RPC 7: founder pulse summary
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2669()
RETURNS TABLE (
  total_updates bigint,
  total_recipients bigint,
  total_replies bigint,
  total_asks_resolved bigint,
  avg_open_rate_pct numeric,
  open_actions bigint,
  positive_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_board_update_impact_r2669),
    (SELECT COALESCE(SUM(recipients_count),0)::bigint FROM public.founder_board_update_impact_r2669),
    (SELECT COALESCE(SUM(reply_count),0)::bigint FROM public.founder_board_update_impact_r2669),
    (SELECT COALESCE(SUM(ask_resolved_count),0)::bigint FROM public.founder_board_update_impact_r2669),
    (SELECT COALESCE(ROUND(AVG(open_rate_pct) FILTER (WHERE status <> 'draft'), 2), 0)
       FROM public.founder_board_update_impact_r2669),
    (SELECT COUNT(*)::bigint FROM public.update_followup_actions_r2669 WHERE status = 'open'),
    (SELECT COUNT(*)::bigint FROM public.update_followup_actions_r2669 WHERE outcome = 'positive');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2669() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2669() TO authenticated;
