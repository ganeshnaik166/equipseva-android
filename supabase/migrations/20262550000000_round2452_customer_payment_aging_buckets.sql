-- Round 2452: customer-payment-aging-buckets
-- Tables: invoice_aging_r2452, invoice_collection_actions_r2452
-- 7 RPCs: list_aging_r2452, list_collection_actions_r2452, age_bucket_summary_r2452,
--        dunning_level_breakdown_r2452, top_overdue_hospitals_r2452,
--        write_off_candidates_r2452, this_week_action_calendar_r2452

CREATE TABLE IF NOT EXISTS public.invoice_aging_r2452 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_external_ref text NOT NULL,
  invoice_issued_at timestamptz NOT NULL,
  invoice_due_at timestamptz NOT NULL,
  invoice_amount_rupees bigint NOT NULL CHECK (invoice_amount_rupees >= 0),
  days_overdue int NOT NULL DEFAULT 0,
  age_bucket text NOT NULL CHECK (age_bucket IN ('current','0_30','31_60','61_90','91_180','180_plus')),
  dunning_level text NOT NULL CHECK (dunning_level IN ('none','email_1','email_2','call','legal_notice','write_off_proposed')),
  promise_to_pay_at timestamptz,
  promise_amount_rupees bigint CHECK (promise_amount_rupees IS NULL OR promise_amount_rupees >= 0),
  probability_collect_pct int NOT NULL DEFAULT 50 CHECK (probability_collect_pct BETWEEN 0 AND 100),
  write_off_candidate boolean NOT NULL DEFAULT false,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.invoice_collection_actions_r2452 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public.invoice_aging_r2452(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('email','call','visit','legal','payment_received','write_off')),
  action_summary text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','no_response')),
  follow_up_at timestamptz,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.invoice_aging_r2452 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_collection_actions_r2452 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.invoice_aging_r2452;
CREATE POLICY founder_all ON public.invoice_aging_r2452
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.invoice_collection_actions_r2452;
CREATE POLICY founder_all ON public.invoice_collection_actions_r2452
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_inv1 uuid;
  v_inv2 uuid;
  v_inv3 uuid;
  v_inv4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role='hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role='hospital_admin' AND id <> COALESCE(v_h1,'00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role='hospital_admin' AND id NOT IN (COALESCE(v_h1,'00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2,'00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at ASC LIMIT 1;

  IF v_h1 IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.invoice_aging_r2452 (hospital_user_id, invoice_external_ref, invoice_issued_at, invoice_due_at, invoice_amount_rupees, days_overdue, age_bucket, dunning_level, promise_to_pay_at, promise_amount_rupees, probability_collect_pct, write_off_candidate, owner_email, notes)
  VALUES (v_h1, 'INV-2026-001', '2026-06-01'::timestamptz, '2026-06-15'::timestamptz, 4500000, 8, '0_30', 'email_1', '2026-07-05'::timestamptz, 4500000, 85, false, 'collections@equipseva.com', 'first reminder sent');
  SELECT id INTO v_inv1 FROM public.invoice_aging_r2452 WHERE invoice_external_ref='INV-2026-001';

  INSERT INTO public.invoice_aging_r2452 (hospital_user_id, invoice_external_ref, invoice_issued_at, invoice_due_at, invoice_amount_rupees, days_overdue, age_bucket, dunning_level, promise_to_pay_at, promise_amount_rupees, probability_collect_pct, write_off_candidate, owner_email, notes)
  VALUES (COALESCE(v_h2, v_h1), 'INV-2026-002', '2026-04-10'::timestamptz, '2026-04-25'::timestamptz, 8200000, 59, '31_60', 'call', '2026-07-10'::timestamptz, 5000000, 60, false, 'collections@equipseva.com', 'partial promise');
  SELECT id INTO v_inv2 FROM public.invoice_aging_r2452 WHERE invoice_external_ref='INV-2026-002';

  INSERT INTO public.invoice_aging_r2452 (hospital_user_id, invoice_external_ref, invoice_issued_at, invoice_due_at, invoice_amount_rupees, days_overdue, age_bucket, dunning_level, promise_to_pay_at, promise_amount_rupees, probability_collect_pct, write_off_candidate, owner_email, notes)
  VALUES (COALESCE(v_h3, v_h1), 'INV-2026-003', '2026-01-15'::timestamptz, '2026-01-30'::timestamptz, 12500000, 144, '91_180', 'legal_notice', NULL, NULL, 30, true, 'legal@equipseva.com', 'legal notice sent');
  SELECT id INTO v_inv3 FROM public.invoice_aging_r2452 WHERE invoice_external_ref='INV-2026-003';

  INSERT INTO public.invoice_aging_r2452 (hospital_user_id, invoice_external_ref, invoice_issued_at, invoice_due_at, invoice_amount_rupees, days_overdue, age_bucket, dunning_level, promise_to_pay_at, promise_amount_rupees, probability_collect_pct, write_off_candidate, owner_email, notes)
  VALUES (v_h1, 'INV-2025-099', '2025-10-01'::timestamptz, '2025-10-15'::timestamptz, 3000000, 251, '180_plus', 'write_off_proposed', NULL, NULL, 5, true, 'founder@equipseva.com', 'write-off candidate');
  SELECT id INTO v_inv4 FROM public.invoice_aging_r2452 WHERE invoice_external_ref='INV-2025-099';

  INSERT INTO public.invoice_collection_actions_r2452 (invoice_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, notes)
  VALUES (v_inv1, '2026-06-20'::timestamptz, 'email', 'sent first dunning email', 'positive', '2026-07-05'::timestamptz, 'collections@equipseva.com', 'hospital acknowledged');

  INSERT INTO public.invoice_collection_actions_r2452 (invoice_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, notes)
  VALUES (v_inv2, '2026-06-18'::timestamptz, 'call', 'spoke to finance head, partial payment promised', 'neutral', '2026-07-10'::timestamptz, 'collections@equipseva.com', 'partial');

  INSERT INTO public.invoice_collection_actions_r2452 (invoice_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, notes)
  VALUES (v_inv3, '2026-06-15'::timestamptz, 'legal', 'legal notice issued via counsel', 'negative', '2026-07-15'::timestamptz, 'legal@equipseva.com', 'no response');

  INSERT INTO public.invoice_collection_actions_r2452 (invoice_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, notes)
  VALUES (v_inv4, '2026-06-10'::timestamptz, 'write_off', 'recommending write-off to board', 'negative', NULL, 'founder@equipseva.com', 'board approval pending');

  INSERT INTO public.invoice_collection_actions_r2452 (invoice_id, action_at, action_kind, action_summary, outcome, follow_up_at, owner_email, notes)
  VALUES (v_inv1, '2026-06-25'::timestamptz, 'email', 'second reminder scheduled', 'neutral', '2026-06-28'::timestamptz, 'collections@equipseva.com', 'follow-up this week');
END
$seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_aging_r2452()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  invoice_external_ref text,
  invoice_issued_at timestamptz,
  invoice_due_at timestamptz,
  invoice_amount_rupees bigint,
  days_overdue int,
  age_bucket text,
  dunning_level text,
  promise_to_pay_at timestamptz,
  promise_amount_rupees bigint,
  probability_collect_pct int,
  write_off_candidate boolean,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, a.invoice_external_ref, a.invoice_issued_at, a.invoice_due_at,
         a.invoice_amount_rupees, a.days_overdue, a.age_bucket, a.dunning_level,
         a.promise_to_pay_at, a.promise_amount_rupees, a.probability_collect_pct,
         a.write_off_candidate, a.owner_email, a.notes, a.created_at
  FROM public.invoice_aging_r2452 a
  ORDER BY a.days_overdue DESC NULLS LAST, a.invoice_amount_rupees DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_aging_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_aging_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_collection_actions_r2452()
RETURNS TABLE (
  id uuid,
  invoice_id uuid,
  invoice_external_ref text,
  action_at timestamptz,
  action_kind text,
  action_summary text,
  outcome text,
  follow_up_at timestamptz,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.invoice_id, a.invoice_external_ref, c.action_at, c.action_kind,
         c.action_summary, c.outcome, c.follow_up_at, c.owner_email, c.notes, c.created_at
  FROM public.invoice_collection_actions_r2452 c
  JOIN public.invoice_aging_r2452 a ON a.id = c.invoice_id
  ORDER BY c.action_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_collection_actions_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_collection_actions_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.age_bucket_summary_r2452()
RETURNS TABLE (
  age_bucket text,
  invoice_count bigint,
  total_amount_rupees bigint,
  avg_probability_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.age_bucket,
         COUNT(*)::bigint AS invoice_count,
         COALESCE(SUM(a.invoice_amount_rupees),0)::bigint AS total_amount_rupees,
         ROUND(AVG(a.probability_collect_pct)::numeric, 1) AS avg_probability_pct
  FROM public.invoice_aging_r2452 a
  GROUP BY a.age_bucket
  ORDER BY
    CASE a.age_bucket
      WHEN 'current' THEN 0
      WHEN '0_30' THEN 1
      WHEN '31_60' THEN 2
      WHEN '61_90' THEN 3
      WHEN '91_180' THEN 4
      WHEN '180_plus' THEN 5
      ELSE 99
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.age_bucket_summary_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.age_bucket_summary_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.dunning_level_breakdown_r2452()
RETURNS TABLE (
  dunning_level text,
  invoice_count bigint,
  total_amount_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.dunning_level,
         COUNT(*)::bigint AS invoice_count,
         COALESCE(SUM(a.invoice_amount_rupees),0)::bigint AS total_amount_rupees
  FROM public.invoice_aging_r2452 a
  GROUP BY a.dunning_level
  ORDER BY total_amount_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.dunning_level_breakdown_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dunning_level_breakdown_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_overdue_hospitals_r2452()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  invoice_count bigint,
  total_overdue_rupees bigint,
  max_days_overdue int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.hospital_user_id,
         p.email AS hospital_email,
         COUNT(*)::bigint AS invoice_count,
         COALESCE(SUM(a.invoice_amount_rupees),0)::bigint AS total_overdue_rupees,
         COALESCE(MAX(a.days_overdue),0) AS max_days_overdue
  FROM public.invoice_aging_r2452 a
  JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE a.days_overdue > 0
  GROUP BY a.hospital_user_id, p.email
  ORDER BY total_overdue_rupees DESC
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_overdue_hospitals_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_overdue_hospitals_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.write_off_candidates_r2452()
RETURNS TABLE (
  id uuid,
  invoice_external_ref text,
  hospital_email text,
  invoice_amount_rupees bigint,
  days_overdue int,
  dunning_level text,
  probability_collect_pct int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.invoice_external_ref, p.email AS hospital_email, a.invoice_amount_rupees,
         a.days_overdue, a.dunning_level, a.probability_collect_pct, a.notes
  FROM public.invoice_aging_r2452 a
  JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE a.write_off_candidate = true OR a.dunning_level = 'write_off_proposed'
  ORDER BY a.invoice_amount_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.write_off_candidates_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.write_off_candidates_r2452() TO authenticated;

CREATE OR REPLACE FUNCTION public.this_week_action_calendar_r2452()
RETURNS TABLE (
  id uuid,
  invoice_id uuid,
  invoice_external_ref text,
  follow_up_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  action_summary text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.invoice_id, a.invoice_external_ref, c.follow_up_at, c.action_kind,
         c.outcome, c.owner_email, c.action_summary
  FROM public.invoice_collection_actions_r2452 c
  JOIN public.invoice_aging_r2452 a ON a.id = c.invoice_id
  WHERE c.follow_up_at IS NOT NULL
    AND c.follow_up_at >= now()
    AND c.follow_up_at <= now() + interval '7 days'
  ORDER BY c.follow_up_at ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.this_week_action_calendar_r2452() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.this_week_action_calendar_r2452() TO authenticated;
