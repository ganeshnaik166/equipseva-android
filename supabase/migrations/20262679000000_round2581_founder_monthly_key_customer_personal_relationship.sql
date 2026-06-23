-- Round r2581 — founder-monthly-key-customer-personal-relationship
-- Track founder-level personal bond with key customer decision-makers + touch log.

BEGIN;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_key_customer_relations_r2581 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  customer_decision_maker_email text NOT NULL,
  decision_maker_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  personal_bond_kind text NOT NULL CHECK (personal_bond_kind IN ('weak','developing','strong','champion')),
  shared_interests_md text,
  event_attendance_count int NOT NULL DEFAULT 0,
  loyalty_score int NOT NULL DEFAULT 0 CHECK (loyalty_score BETWEEN 0 AND 100),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','strained','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fkcr_r2581_month ON public.founder_key_customer_relations_r2581(month_label);
CREATE INDEX IF NOT EXISTS idx_fkcr_r2581_bond ON public.founder_key_customer_relations_r2581(personal_bond_kind);
CREATE INDEX IF NOT EXISTS idx_fkcr_r2581_status ON public.founder_key_customer_relations_r2581(status);

CREATE TABLE IF NOT EXISTS public.key_customer_touch_log_r2581 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relation_id uuid NOT NULL REFERENCES public.founder_key_customer_relations_r2581(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL DEFAULT now(),
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','site_visit','dinner','founder_gift','conference')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  follow_up_at timestamptz,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kctl_r2581_relation ON public.key_customer_touch_log_r2581(relation_id);
CREATE INDEX IF NOT EXISTS idx_kctl_r2581_touch_at ON public.key_customer_touch_log_r2581(touch_at);
CREATE INDEX IF NOT EXISTS idx_kctl_r2581_outcome ON public.key_customer_touch_log_r2581(outcome);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.founder_key_customer_relations_r2581 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.key_customer_touch_log_r2581 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_key_customer_relations_r2581;
CREATE POLICY founder_all ON public.founder_key_customer_relations_r2581
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.key_customer_touch_log_r2581;
CREATE POLICY founder_all ON public.key_customer_touch_log_r2581
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED
-- ============================================================

INSERT INTO public.founder_key_customer_relations_r2581
  (month_label, customer_decision_maker_email, decision_maker_name, personal_bond_kind, shared_interests_md, event_attendance_count, loyalty_score, owner_email, status, notes)
VALUES
  ('2026-06', 'cmo@apollo-hyd.example', 'Dr Ramesh Iyer', 'champion', 'cricket; carnatic music; biotech investing', 5, 92, 'founder@equipseva.example', 'active', 'Anchor advocate; opens 3 sister hospitals to us'),
  ('2026-06', 'biomed.head@medanta.example', 'Vikram Singh', 'strong', 'mountaineering; medtech podcasts', 3, 78, 'founder@equipseva.example', 'active', 'Strong AMC renewal advocate'),
  ('2026-06', 'coo@aster.example',           'Dr Priya Menon', 'developing', 'marathon running; fintech', 1, 54, 'founder@equipseva.example', 'active', 'Warming up; needs more founder time'),
  ('2026-06', 'cfo@kims.example',            'Suresh Babu',    'weak',     'golf', 0, 28, 'founder@equipseva.example', 'dormant', 'Cold; no founder interaction in 90d'),
  ('2026-05', 'cmo@apollo-hyd.example', 'Dr Ramesh Iyer', 'champion', 'cricket; carnatic music', 4, 90, 'founder@equipseva.example', 'active', 'May baseline')
ON CONFLICT DO NOTHING;

INSERT INTO public.key_customer_touch_log_r2581
  (relation_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '5 days', 'dinner', 'positive', now() + interval '21 days', 'founder@equipseva.example', 'done', 'Dinner at ITC; introduced to two peer CMOs'
  FROM public.founder_key_customer_relations_r2581 WHERE customer_decision_maker_email='cmo@apollo-hyd.example' AND month_label='2026-06' LIMIT 1;

INSERT INTO public.key_customer_touch_log_r2581
  (relation_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '12 days', 'site_visit', 'positive', now() + interval '30 days', 'founder@equipseva.example', 'done', 'Walked biomed floor; AMC renewal verbal yes'
  FROM public.founder_key_customer_relations_r2581 WHERE customer_decision_maker_email='biomed.head@medanta.example' LIMIT 1;

INSERT INTO public.key_customer_touch_log_r2581
  (relation_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '20 days', 'call', 'neutral', now() + interval '10 days', 'founder@equipseva.example', 'open', 'Quarterly check-in; agreed to founder dinner Q3'
  FROM public.founder_key_customer_relations_r2581 WHERE customer_decision_maker_email='coo@aster.example' LIMIT 1;

INSERT INTO public.key_customer_touch_log_r2581
  (relation_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '95 days', 'email', 'pending', NULL, 'founder@equipseva.example', 'dropped', 'No reply; dormant'
  FROM public.founder_key_customer_relations_r2581 WHERE customer_decision_maker_email='cfo@kims.example' LIMIT 1;

INSERT INTO public.key_customer_touch_log_r2581
  (relation_id, touch_at, touch_kind, outcome, follow_up_at, owner_email, status, notes)
SELECT id, now() - interval '2 days', 'founder_gift', 'positive', NULL, 'founder@equipseva.example', 'done', 'Diwali hamper + handwritten note'
  FROM public.founder_key_customer_relations_r2581 WHERE customer_decision_maker_email='cmo@apollo-hyd.example' AND month_label='2026-06' LIMIT 1;

-- ============================================================
-- RPCS
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_relations_r2581()
RETURNS TABLE (
  id uuid,
  month_label text,
  customer_decision_maker_email text,
  decision_maker_name text,
  personal_bond_kind text,
  shared_interests_md text,
  event_attendance_count int,
  loyalty_score int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.month_label, r.customer_decision_maker_email, r.decision_maker_name,
         r.personal_bond_kind, r.shared_interests_md, r.event_attendance_count,
         r.loyalty_score, r.owner_email, r.status, r.notes, r.created_at
    FROM public.founder_key_customer_relations_r2581 r
   ORDER BY r.month_label DESC, r.loyalty_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_relations_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_relations_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_touch_log_r2581()
RETURNS TABLE (
  id uuid,
  relation_id uuid,
  decision_maker_name text,
  customer_decision_maker_email text,
  touch_at timestamptz,
  touch_kind text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.relation_id, r.decision_maker_name, r.customer_decision_maker_email,
         t.touch_at, t.touch_kind, t.outcome, t.follow_up_at,
         t.owner_email, t.status, t.notes
    FROM public.key_customer_touch_log_r2581 t
    JOIN public.founder_key_customer_relations_r2581 r ON r.id = t.relation_id
   ORDER BY t.touch_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_touch_log_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touch_log_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_loyalty_customers_r2581()
RETURNS TABLE (
  decision_maker_name text,
  customer_decision_maker_email text,
  personal_bond_kind text,
  loyalty_score int,
  event_attendance_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.decision_maker_name, r.customer_decision_maker_email, r.personal_bond_kind,
         r.loyalty_score, r.event_attendance_count, r.status
    FROM public.founder_key_customer_relations_r2581 r
   WHERE r.month_label = (SELECT max(month_label) FROM public.founder_key_customer_relations_r2581)
   ORDER BY r.loyalty_score DESC NULLS LAST
   LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_loyalty_customers_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loyalty_customers_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.bond_kind_distribution_r2581()
RETURNS TABLE (
  personal_bond_kind text,
  relation_count bigint,
  avg_loyalty numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.personal_bond_kind,
         count(*)::bigint,
         round(avg(r.loyalty_score)::numeric, 1)
    FROM public.founder_key_customer_relations_r2581 r
   WHERE r.month_label = (SELECT max(month_label) FROM public.founder_key_customer_relations_r2581)
   GROUP BY r.personal_bond_kind
   ORDER BY count(*) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bond_kind_distribution_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bond_kind_distribution_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.dormant_focus_r2581()
RETURNS TABLE (
  decision_maker_name text,
  customer_decision_maker_email text,
  personal_bond_kind text,
  loyalty_score int,
  status text,
  last_touch_at timestamptz,
  days_since_touch int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.decision_maker_name, r.customer_decision_maker_email, r.personal_bond_kind,
         r.loyalty_score, r.status,
         lt.last_touch_at,
         EXTRACT(DAY FROM (now() - lt.last_touch_at))::int AS days_since_touch
    FROM public.founder_key_customer_relations_r2581 r
    LEFT JOIN LATERAL (
      SELECT max(t.touch_at) AS last_touch_at
        FROM public.key_customer_touch_log_r2581 t
       WHERE t.relation_id = r.id
    ) lt ON true
   WHERE r.status IN ('dormant','strained','lost')
      OR lt.last_touch_at IS NULL
      OR lt.last_touch_at < now() - interval '60 days'
   ORDER BY r.loyalty_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dormant_focus_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dormant_focus_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.monthly_touch_trend_r2581()
RETURNS TABLE (
  month_bucket text,
  touch_count bigint,
  positive_count bigint,
  negative_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', t.touch_at), 'YYYY-MM') AS month_bucket,
         count(*)::bigint,
         count(*) FILTER (WHERE t.outcome = 'positive')::bigint,
         count(*) FILTER (WHERE t.outcome = 'negative')::bigint
    FROM public.key_customer_touch_log_r2581 t
   GROUP BY date_trunc('month', t.touch_at)
   ORDER BY date_trunc('month', t.touch_at) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_touch_trend_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_touch_trend_r2581() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2581()
RETURNS TABLE (
  metric text,
  value text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_champions int;
  v_avg_loyalty numeric;
  v_dormant int;
  v_touches_30d int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total
    FROM public.founder_key_customer_relations_r2581
   WHERE month_label = (SELECT max(month_label) FROM public.founder_key_customer_relations_r2581);

  SELECT count(*) INTO v_champions
    FROM public.founder_key_customer_relations_r2581
   WHERE personal_bond_kind = 'champion'
     AND month_label = (SELECT max(month_label) FROM public.founder_key_customer_relations_r2581);

  SELECT round(avg(loyalty_score)::numeric, 1) INTO v_avg_loyalty
    FROM public.founder_key_customer_relations_r2581
   WHERE month_label = (SELECT max(month_label) FROM public.founder_key_customer_relations_r2581);

  SELECT count(*) INTO v_dormant
    FROM public.founder_key_customer_relations_r2581
   WHERE status IN ('dormant','strained','lost');

  SELECT count(*) INTO v_touches_30d
    FROM public.key_customer_touch_log_r2581
   WHERE touch_at > now() - interval '30 days';

  RETURN QUERY
  SELECT 'key_relations_this_month'::text, COALESCE(v_total,0)::text
  UNION ALL SELECT 'champions'::text,            COALESCE(v_champions,0)::text
  UNION ALL SELECT 'avg_loyalty_score'::text,    COALESCE(v_avg_loyalty,0)::text
  UNION ALL SELECT 'dormant_or_strained'::text,  COALESCE(v_dormant,0)::text
  UNION ALL SELECT 'founder_touches_30d'::text,  COALESCE(v_touches_30d,0)::text;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2581() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2581() TO authenticated;

