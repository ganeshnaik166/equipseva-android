-- Round r2480: customer-reference-call-program
-- hospital x reference willing x topic x call requested x call completed x deal influence

BEGIN;

-- =====================================================================
-- TABLE 1: customer_reference_calls_r2480
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.customer_reference_calls_r2480 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reference_topic text NOT NULL CHECK (reference_topic IN ('amc','quality','turnaround','csat','outcome','cost_savings')),
  willing boolean NOT NULL DEFAULT false,
  call_requested_at timestamptz,
  call_completed_at timestamptz,
  prospect_name text,
  prospect_email text,
  call_outcome text NOT NULL DEFAULT 'pending' CHECK (call_outcome IN ('positive','neutral','negative','no_show','pending')),
  deal_influence text NOT NULL DEFAULT 'none' CHECK (deal_influence IN ('none','low','medium','high','critical')),
  influenced_revenue_rupees bigint NOT NULL DEFAULT 0 CHECK (influenced_revenue_rupees >= 0),
  owner_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','scheduled','completed','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crc_r2480_hospital ON public.customer_reference_calls_r2480(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_crc_r2480_topic ON public.customer_reference_calls_r2480(reference_topic);
CREATE INDEX IF NOT EXISTS idx_crc_r2480_status ON public.customer_reference_calls_r2480(status);
CREATE INDEX IF NOT EXISTS idx_crc_r2480_outcome ON public.customer_reference_calls_r2480(call_outcome);

ALTER TABLE public.customer_reference_calls_r2480 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_reference_calls_r2480;
CREATE POLICY founder_all ON public.customer_reference_calls_r2480
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: reference_call_thank_you_log_r2480
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.reference_call_thank_you_log_r2480 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_id uuid NOT NULL REFERENCES public.customer_reference_calls_r2480(id) ON DELETE CASCADE,
  thank_you_sent_at timestamptz,
  gift_kind text NOT NULL DEFAULT 'none' CHECK (gift_kind IN ('handwritten_note','branded_swag','dinner_invite','conference_invite','none')),
  gift_value_rupees int NOT NULL DEFAULT 0 CHECK (gift_value_rupees >= 0),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rctyl_r2480_ref ON public.reference_call_thank_you_log_r2480(reference_id);
CREATE INDEX IF NOT EXISTS idx_rctyl_r2480_gift ON public.reference_call_thank_you_log_r2480(gift_kind);

ALTER TABLE public.reference_call_thank_you_log_r2480 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.reference_call_thank_you_log_r2480;
CREATE POLICY founder_all ON public.reference_call_thank_you_log_r2480
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- SEED DATA
-- =====================================================================
DO $$
DECLARE
  v_hospital_a uuid;
  v_hospital_b uuid;
  v_hospital_c uuid;
  v_ref_a uuid;
  v_ref_b uuid;
  v_ref_c uuid;
  v_ref_d uuid;
BEGIN
  SELECT id INTO v_hospital_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital_b FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_hospital_c FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_hospital_a IS NULL THEN
    RETURN;
  END IF;

  IF v_hospital_b IS NULL THEN v_hospital_b := v_hospital_a; END IF;
  IF v_hospital_c IS NULL THEN v_hospital_c := v_hospital_a; END IF;

  INSERT INTO public.customer_reference_calls_r2480(
    hospital_user_id, reference_topic, willing, call_requested_at, call_completed_at,
    prospect_name, prospect_email, call_outcome, deal_influence,
    influenced_revenue_rupees, owner_email, status, notes
  ) VALUES (
    v_hospital_a, 'amc', true, now() - interval '14 days', now() - interval '10 days',
    'Dr Rao - Apollo Vizag', 'rao@apollo-vzg.example.com', 'positive', 'critical',
    4800000, 'founder@equipseva.in', 'completed', 'Closed 18-bed AMC deal after this call'
  ) RETURNING id INTO v_ref_a;

  INSERT INTO public.customer_reference_calls_r2480(
    hospital_user_id, reference_topic, willing, call_requested_at, call_completed_at,
    prospect_name, prospect_email, call_outcome, deal_influence,
    influenced_revenue_rupees, owner_email, status, notes
  ) VALUES (
    v_hospital_b, 'turnaround', true, now() - interval '7 days', now() - interval '5 days',
    'Mr Khan - Yashoda Hitec', 'khan@yashoda-htc.example.com', 'positive', 'high',
    2200000, 'founder@equipseva.in', 'completed', 'Prospect signed pilot 3 days after'
  ) RETURNING id INTO v_ref_b;

  INSERT INTO public.customer_reference_calls_r2480(
    hospital_user_id, reference_topic, willing, call_requested_at, call_completed_at,
    prospect_name, prospect_email, call_outcome, deal_influence,
    influenced_revenue_rupees, owner_email, status, notes
  ) VALUES (
    v_hospital_c, 'cost_savings', true, now() - interval '3 days', NULL,
    'Dr Iyer - KIMS Secunderabad', 'iyer@kims-sec.example.com', 'pending', 'medium',
    0, 'sales@equipseva.in', 'scheduled', 'Call slated for next Tuesday 11am'
  ) RETURNING id INTO v_ref_c;

  INSERT INTO public.customer_reference_calls_r2480(
    hospital_user_id, reference_topic, willing, call_requested_at, call_completed_at,
    prospect_name, prospect_email, call_outcome, deal_influence,
    influenced_revenue_rupees, owner_email, status, notes
  ) VALUES (
    v_hospital_a, 'csat', false, NULL, NULL,
    NULL, NULL, 'pending', 'none',
    0, 'sales@equipseva.in', 'cancelled', 'Hospital declined - new admin not yet briefed'
  ) RETURNING id INTO v_ref_d;

  INSERT INTO public.reference_call_thank_you_log_r2480(
    reference_id, thank_you_sent_at, gift_kind, gift_value_rupees, owner_email, notes
  ) VALUES (
    v_ref_a, now() - interval '9 days', 'handwritten_note', 250, 'founder@equipseva.in',
    'Hand-delivered with biryani box'
  );

  INSERT INTO public.reference_call_thank_you_log_r2480(
    reference_id, thank_you_sent_at, gift_kind, gift_value_rupees, owner_email, notes
  ) VALUES (
    v_ref_b, now() - interval '4 days', 'dinner_invite', 6500, 'founder@equipseva.in',
    'Paradise dinner with founder + Mr Khan family'
  );

  INSERT INTO public.reference_call_thank_you_log_r2480(
    reference_id, thank_you_sent_at, gift_kind, gift_value_rupees, owner_email, notes
  ) VALUES (
    v_ref_b, NULL, 'conference_invite', 15000, 'founder@equipseva.in',
    'Pending - HEAL summit invite Dec 2026'
  );
END $$;

-- =====================================================================
-- RPC 1: list_reference_calls_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_reference_calls_r2480()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  reference_topic text,
  willing boolean,
  call_requested_at timestamptz,
  call_completed_at timestamptz,
  prospect_name text,
  prospect_email text,
  call_outcome text,
  deal_influence text,
  influenced_revenue_rupees bigint,
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
  SELECT c.id, c.hospital_user_id, p.email::text AS hospital_email,
         c.reference_topic, c.willing, c.call_requested_at, c.call_completed_at,
         c.prospect_name, c.prospect_email, c.call_outcome, c.deal_influence,
         c.influenced_revenue_rupees, c.owner_email, c.status, c.notes, c.created_at
  FROM public.customer_reference_calls_r2480 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_reference_calls_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reference_calls_r2480() TO authenticated;

-- =====================================================================
-- RPC 2: list_thank_you_log_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_thank_you_log_r2480()
RETURNS TABLE(
  id uuid,
  reference_id uuid,
  prospect_name text,
  reference_topic text,
  thank_you_sent_at timestamptz,
  gift_kind text,
  gift_value_rupees int,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.reference_id, c.prospect_name, c.reference_topic,
         t.thank_you_sent_at, t.gift_kind, t.gift_value_rupees,
         t.owner_email, t.notes, t.created_at
  FROM public.reference_call_thank_you_log_r2480 t
  LEFT JOIN public.customer_reference_calls_r2480 c ON c.id = t.reference_id
  ORDER BY t.created_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_thank_you_log_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_thank_you_log_r2480() TO authenticated;

-- =====================================================================
-- RPC 3: top_influencing_hospitals_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_influencing_hospitals_r2480()
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_email text,
  call_count bigint,
  completed_count bigint,
  positive_count bigint,
  total_revenue_influenced_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.hospital_user_id,
         p.email::text AS hospital_email,
         COUNT(*)::bigint AS call_count,
         COUNT(*) FILTER (WHERE c.status = 'completed')::bigint AS completed_count,
         COUNT(*) FILTER (WHERE c.call_outcome = 'positive')::bigint AS positive_count,
         COALESCE(SUM(c.influenced_revenue_rupees), 0)::bigint AS total_revenue_influenced_rupees
  FROM public.customer_reference_calls_r2480 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  GROUP BY c.hospital_user_id, p.email
  ORDER BY total_revenue_influenced_rupees DESC, positive_count DESC
  LIMIT 50;
END $$;

REVOKE EXECUTE ON FUNCTION public.top_influencing_hospitals_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_influencing_hospitals_r2480() TO authenticated;

-- =====================================================================
-- RPC 4: topic_breakdown_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.topic_breakdown_r2480()
RETURNS TABLE(
  reference_topic text,
  total_calls bigint,
  willing_count bigint,
  positive_count bigint,
  high_or_critical_count bigint,
  total_revenue_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.reference_topic,
         COUNT(*)::bigint AS total_calls,
         COUNT(*) FILTER (WHERE c.willing)::bigint AS willing_count,
         COUNT(*) FILTER (WHERE c.call_outcome = 'positive')::bigint AS positive_count,
         COUNT(*) FILTER (WHERE c.deal_influence IN ('high','critical'))::bigint AS high_or_critical_count,
         COALESCE(SUM(c.influenced_revenue_rupees), 0)::bigint AS total_revenue_rupees
  FROM public.customer_reference_calls_r2480 c
  GROUP BY c.reference_topic
  ORDER BY total_revenue_rupees DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.topic_breakdown_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.topic_breakdown_r2480() TO authenticated;

-- =====================================================================
-- RPC 5: outcome_summary_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.outcome_summary_r2480()
RETURNS TABLE(
  call_outcome text,
  count_total bigint,
  total_revenue_influenced_rupees bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*)::bigint INTO v_total FROM public.customer_reference_calls_r2480;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT c.call_outcome,
         COUNT(*)::bigint AS count_total,
         COALESCE(SUM(c.influenced_revenue_rupees), 0)::bigint AS total_revenue_influenced_rupees,
         ROUND((COUNT(*)::numeric * 100.0) / v_total, 1) AS pct_of_total
  FROM public.customer_reference_calls_r2480 c
  GROUP BY c.call_outcome
  ORDER BY count_total DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.outcome_summary_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_summary_r2480() TO authenticated;

-- =====================================================================
-- RPC 6: pending_thank_yous_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.pending_thank_yous_r2480()
RETURNS TABLE(
  reference_id uuid,
  prospect_name text,
  reference_topic text,
  call_completed_at timestamptz,
  days_since_call int,
  hospital_email text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id AS reference_id,
         c.prospect_name,
         c.reference_topic,
         c.call_completed_at,
         GREATEST(0, EXTRACT(DAY FROM (now() - c.call_completed_at))::int) AS days_since_call,
         p.email::text AS hospital_email,
         c.owner_email
  FROM public.customer_reference_calls_r2480 c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'completed'
    AND c.call_completed_at IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.reference_call_thank_you_log_r2480 t
      WHERE t.reference_id = c.id AND t.thank_you_sent_at IS NOT NULL
    )
  ORDER BY c.call_completed_at ASC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.pending_thank_yous_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pending_thank_yous_r2480() TO authenticated;

-- =====================================================================
-- RPC 7: monthly_revenue_influenced_r2480
-- =====================================================================
CREATE OR REPLACE FUNCTION public.monthly_revenue_influenced_r2480()
RETURNS TABLE(
  month_label text,
  call_count bigint,
  positive_count bigint,
  revenue_influenced_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', c.created_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS call_count,
         COUNT(*) FILTER (WHERE c.call_outcome = 'positive')::bigint AS positive_count,
         COALESCE(SUM(c.influenced_revenue_rupees), 0)::bigint AS revenue_influenced_rupees
  FROM public.customer_reference_calls_r2480 c
  GROUP BY date_trunc('month', c.created_at)
  ORDER BY date_trunc('month', c.created_at) DESC
  LIMIT 24;
END $$;

REVOKE EXECUTE ON FUNCTION public.monthly_revenue_influenced_r2480() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_revenue_influenced_r2480() TO authenticated;
