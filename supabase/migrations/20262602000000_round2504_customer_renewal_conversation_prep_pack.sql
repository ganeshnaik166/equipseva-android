BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_renewal_prep_packs_r2504 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  renewal_due_at timestamptz NOT NULL DEFAULT now(),
  historical_performance_md text NOT NULL DEFAULT '',
  top_csat_quotes_md text NOT NULL DEFAULT '',
  top_complaint_quotes_md text NOT NULL DEFAULT '',
  upsell_hints_md text NOT NULL DEFAULT '',
  risk_flags_md text NOT NULL DEFAULT '',
  prep_status text NOT NULL DEFAULT 'not_started' CHECK (prep_status IN ('not_started','draft','reviewed','final','sent')),
  owner_email text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.renewal_conversation_outcomes_r2504 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prep_pack_id uuid REFERENCES public.customer_renewal_prep_packs_r2504(id) ON DELETE CASCADE,
  conversation_at timestamptz NOT NULL DEFAULT now(),
  conversation_kind text NOT NULL CHECK (conversation_kind IN ('call','visit','meeting')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('renewed','dropped','negotiating','postponed','pending')),
  revenue_outcome_rupees bigint NOT NULL DEFAULT 0,
  follow_up_at timestamptz,
  owner_email text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_renewal_prep_packs_r2504 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.renewal_conversation_outcomes_r2504 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_prep_packs_r2504;
CREATE POLICY founder_all ON public.customer_renewal_prep_packs_r2504
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.renewal_conversation_outcomes_r2504;
CREATE POLICY founder_all ON public.renewal_conversation_outcomes_r2504
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed prep packs
INSERT INTO public.customer_renewal_prep_packs_r2504 (renewal_due_at, historical_performance_md, top_csat_quotes_md, top_complaint_quotes_md, upsell_hints_md, risk_flags_md, prep_status, owner_email, notes) VALUES
('2026-07-15'::timestamptz, '- 18 months on contract\n- 94% uptime\n- 2 escalations resolved <24h', '> Engineer always punctual\n> Best vendor we work with', '> Spare ETA sometimes slow', '- Tier upgrade to Gold AMC\n- Add 2 more ultrasounds', '- New procurement head hired May 2026', 'final', 'founder@equipseva.in', 'Tier-1 hospital — high confidence renewal'),
('2026-07-22'::timestamptz, '- 24 months on contract\n- 87% uptime\n- 5 missed SLAs', '> Liked recent escalation handling', '> Bench billing dispute April\n> Engineer rotation broke trust', '- Discount in exchange for 24mo lock', '- 2 competitor visits seen\n- CFO unhappy', 'reviewed', 'founder@equipseva.in', 'At risk — needs founder call'),
('2026-08-01'::timestamptz, '- 12 months on contract\n- 96% uptime\n- 0 escalations', '> Smoothest vendor relationship', '', '- Sister hospital onboarding\n- Extended warranty bundle', '', 'draft', 'founder@equipseva.in', 'Promoter — easy renewal + expansion'),
('2026-08-10'::timestamptz, '- 6 months on contract\n- 91% uptime', '', '> Want Telugu UI', '- Multi-year prepay discount', '- Procurement budget cut rumour', 'not_started', 'founder@equipseva.in', 'Mid-market hospital'),
('2026-06-28'::timestamptz, '- 36 months on contract\n- 98% uptime\n- referenceable account', '> Lifelong customer', '', '- Refer 2 new hospitals\n- Co-marketing case study', '', 'sent', 'founder@equipseva.in', 'Champion account — already signed');

-- Seed conversation outcomes
INSERT INTO public.renewal_conversation_outcomes_r2504 (prep_pack_id, conversation_at, conversation_kind, outcome, revenue_outcome_rupees, follow_up_at, owner_email, notes)
SELECT id, '2026-06-20'::timestamptz, 'call', 'renewed', 4800000, '2026-07-20'::timestamptz, 'founder@equipseva.in', 'Closed Gold AMC tier upgrade'
FROM public.customer_renewal_prep_packs_r2504 WHERE notes = 'Tier-1 hospital — high confidence renewal' LIMIT 1;

INSERT INTO public.renewal_conversation_outcomes_r2504 (prep_pack_id, conversation_at, conversation_kind, outcome, revenue_outcome_rupees, follow_up_at, owner_email, notes)
SELECT id, '2026-06-21'::timestamptz, 'visit', 'negotiating', 0, '2026-07-05'::timestamptz, 'founder@equipseva.in', 'CFO meeting scheduled — discount ask'
FROM public.customer_renewal_prep_packs_r2504 WHERE notes = 'At risk — needs founder call' LIMIT 1;

INSERT INTO public.renewal_conversation_outcomes_r2504 (prep_pack_id, conversation_at, conversation_kind, outcome, revenue_outcome_rupees, follow_up_at, owner_email, notes)
SELECT id, '2026-06-18'::timestamptz, 'meeting', 'renewed', 9600000, NULL, 'founder@equipseva.in', 'Renewed + 2 ultrasound expansion'
FROM public.customer_renewal_prep_packs_r2504 WHERE notes = 'Champion account — already signed' LIMIT 1;

INSERT INTO public.renewal_conversation_outcomes_r2504 (prep_pack_id, conversation_at, conversation_kind, outcome, revenue_outcome_rupees, follow_up_at, owner_email, notes)
SELECT id, '2026-06-15'::timestamptz, 'call', 'postponed', 0, '2026-07-15'::timestamptz, 'founder@equipseva.in', 'Procurement freeze 30 days'
FROM public.customer_renewal_prep_packs_r2504 WHERE notes = 'Mid-market hospital' LIMIT 1;

INSERT INTO public.renewal_conversation_outcomes_r2504 (prep_pack_id, conversation_at, conversation_kind, outcome, revenue_outcome_rupees, follow_up_at, owner_email, notes)
SELECT id, '2026-06-22'::timestamptz, 'meeting', 'pending', 0, '2026-06-28'::timestamptz, 'founder@equipseva.in', 'Promoter — discussion next week'
FROM public.customer_renewal_prep_packs_r2504 WHERE notes = 'Promoter — easy renewal + expansion' LIMIT 1;

-- RPC 1: list_prep_packs_r2504
CREATE OR REPLACE FUNCTION public.list_prep_packs_r2504()
RETURNS TABLE(id uuid, renewal_due_at timestamptz, prep_status text, owner_email text, risk_flags_md text, upsell_hints_md text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.renewal_due_at, p.prep_status, p.owner_email, p.risk_flags_md, p.upsell_hints_md, p.notes
  FROM public.customer_renewal_prep_packs_r2504 p
  ORDER BY p.renewal_due_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_prep_packs_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_prep_packs_r2504() TO authenticated;

-- RPC 2: list_conversation_outcomes_r2504
CREATE OR REPLACE FUNCTION public.list_conversation_outcomes_r2504()
RETURNS TABLE(id uuid, prep_pack_id uuid, conversation_at timestamptz, conversation_kind text, outcome text, revenue_outcome_rupees bigint, follow_up_at timestamptz, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.prep_pack_id, o.conversation_at, o.conversation_kind, o.outcome, o.revenue_outcome_rupees, o.follow_up_at, o.owner_email, o.notes
  FROM public.renewal_conversation_outcomes_r2504 o
  ORDER BY o.conversation_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_conversation_outcomes_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_conversation_outcomes_r2504() TO authenticated;

-- RPC 3: top_risk_hospitals_r2504
CREATE OR REPLACE FUNCTION public.top_risk_hospitals_r2504()
RETURNS TABLE(id uuid, renewal_due_at timestamptz, risk_flags_md text, prep_status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.renewal_due_at, p.risk_flags_md, p.prep_status, p.notes
  FROM public.customer_renewal_prep_packs_r2504 p
  WHERE length(p.risk_flags_md) > 0
  ORDER BY p.renewal_due_at ASC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_risk_hospitals_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_risk_hospitals_r2504() TO authenticated;

-- RPC 4: top_revenue_outcomes_r2504
CREATE OR REPLACE FUNCTION public.top_revenue_outcomes_r2504()
RETURNS TABLE(id uuid, conversation_at timestamptz, conversation_kind text, outcome text, revenue_outcome_rupees bigint, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.conversation_at, o.conversation_kind, o.outcome, o.revenue_outcome_rupees, o.notes
  FROM public.renewal_conversation_outcomes_r2504 o
  WHERE o.revenue_outcome_rupees > 0
  ORDER BY o.revenue_outcome_rupees DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_revenue_outcomes_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_revenue_outcomes_r2504() TO authenticated;

-- RPC 5: prep_status_funnel_r2504
CREATE OR REPLACE FUNCTION public.prep_status_funnel_r2504()
RETURNS TABLE(prep_status text, pack_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.prep_status, count(*)::bigint AS pack_count
  FROM public.customer_renewal_prep_packs_r2504 p
  GROUP BY p.prep_status
  ORDER BY pack_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.prep_status_funnel_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prep_status_funnel_r2504() TO authenticated;

-- RPC 6: monthly_renewal_outcome_trend_r2504
CREATE OR REPLACE FUNCTION public.monthly_renewal_outcome_trend_r2504()
RETURNS TABLE(month_label text, outcome text, conversation_count bigint, revenue_sum_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', o.conversation_at), 'YYYY-MM') AS month_label,
         o.outcome,
         count(*)::bigint AS conversation_count,
         coalesce(sum(o.revenue_outcome_rupees), 0)::bigint AS revenue_sum_rupees
  FROM public.renewal_conversation_outcomes_r2504 o
  GROUP BY 1, 2
  ORDER BY 1 DESC, 2 ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_renewal_outcome_trend_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_renewal_outcome_trend_r2504() TO authenticated;

-- RPC 7: upcoming_renewals_r2504
CREATE OR REPLACE FUNCTION public.upcoming_renewals_r2504()
RETURNS TABLE(id uuid, renewal_due_at timestamptz, prep_status text, owner_email text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.renewal_due_at, p.prep_status, p.owner_email, p.notes
  FROM public.customer_renewal_prep_packs_r2504 p
  WHERE p.renewal_due_at >= now() - interval '7 days'
  ORDER BY p.renewal_due_at ASC
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.upcoming_renewals_r2504() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_renewals_r2504() TO authenticated;

