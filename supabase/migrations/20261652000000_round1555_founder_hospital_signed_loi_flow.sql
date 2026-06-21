BEGIN;

-- ============================================================
-- r1555 — Hospital Signed-LOI Flow
-- Track LOI -> AMC conversion, per-LOI status, founder follow-up SLA, lost reasons
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_hospital_lois (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  signed_at timestamptz NOT NULL DEFAULT now(),
  signatory_name text,
  signatory_designation text,
  intended_amc_tier text CHECK (intended_amc_tier IN ('basic','standard','premium','enterprise')),
  intended_monthly_fee_rupees integer NOT NULL DEFAULT 0,
  intended_equipment_count integer NOT NULL DEFAULT 0,
  expected_close_date date,
  status text NOT NULL DEFAULT 'signed' CHECK (status IN ('signed','in_discussion','contract_drafted','awaiting_payment','converted','lost','expired')),
  converted_amc_contract_id uuid REFERENCES public.amc_contracts(id) ON DELETE SET NULL,
  converted_at timestamptz,
  lost_reason text CHECK (lost_reason IN ('price','timing','competitor','no_budget','requirement_change','no_response','internal_block','other')),
  lost_notes text,
  next_followup_at timestamptz,
  last_touched_at timestamptz NOT NULL DEFAULT now(),
  followup_sla_hours integer NOT NULL DEFAULT 48,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_hospital_lois_status ON public.founder_hospital_lois(status);
CREATE INDEX IF NOT EXISTS idx_founder_hospital_lois_hospital ON public.founder_hospital_lois(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_founder_hospital_lois_next_followup ON public.founder_hospital_lois(next_followup_at) WHERE status NOT IN ('converted','lost','expired');

ALTER TABLE public.founder_hospital_lois ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_lois ON public.founder_hospital_lois;
CREATE POLICY founder_only_lois ON public.founder_hospital_lois
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_hospital_loi_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loi_id uuid NOT NULL REFERENCES public.founder_hospital_lois(id) ON DELETE CASCADE,
  touched_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('call','email','whatsapp','meeting','site_visit','other')),
  outcome text CHECK (outcome IN ('positive','neutral','negative','no_answer','rescheduled')),
  next_step text,
  notes text,
  logged_by_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loi_touchpoints_loi ON public.founder_hospital_loi_touchpoints(loi_id, touched_at DESC);

ALTER TABLE public.founder_hospital_loi_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_loi_touchpoints ON public.founder_hospital_loi_touchpoints;
CREATE POLICY founder_only_loi_touchpoints ON public.founder_hospital_loi_touchpoints
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.founder_loi_pipeline_overview()
RETURNS TABLE(
  total_lois bigint,
  signed_count bigint,
  in_discussion_count bigint,
  contract_drafted_count bigint,
  awaiting_payment_count bigint,
  converted_count bigint,
  lost_count bigint,
  expired_count bigint,
  total_intended_arr_rupees bigint,
  converted_arr_rupees bigint,
  conversion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'signed'),
    COUNT(*) FILTER (WHERE status = 'in_discussion'),
    COUNT(*) FILTER (WHERE status = 'contract_drafted'),
    COUNT(*) FILTER (WHERE status = 'awaiting_payment'),
    COUNT(*) FILTER (WHERE status = 'converted'),
    COUNT(*) FILTER (WHERE status = 'lost'),
    COUNT(*) FILTER (WHERE status = 'expired'),
    COALESCE(SUM(intended_monthly_fee_rupees * 12), 0)::bigint,
    COALESCE(SUM(intended_monthly_fee_rupees * 12) FILTER (WHERE status = 'converted'), 0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE status IN ('converted','lost','expired')) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'converted')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('converted','lost','expired')), 0), 2)
      ELSE 0 END
  FROM public.founder_hospital_lois;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_pipeline_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_pipeline_overview() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_active_list()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  city text,
  state text,
  status text,
  intended_amc_tier text,
  intended_monthly_fee_rupees integer,
  intended_equipment_count integer,
  signed_at timestamptz,
  expected_close_date date,
  days_since_signed integer,
  signatory_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    o.name,
    o.city,
    o.state,
    l.status,
    l.intended_amc_tier,
    l.intended_monthly_fee_rupees,
    l.intended_equipment_count,
    l.signed_at,
    l.expected_close_date,
    EXTRACT(EPOCH FROM (now() - l.signed_at))::numeric / 86400.0 AS days_since_signed_raw,
    l.signatory_name
  FROM public.founder_hospital_lois l
  JOIN public.organizations o ON o.id = l.hospital_org_id
  WHERE l.status NOT IN ('converted','lost','expired')
  ORDER BY l.signed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_active_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_active_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_followup_due()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  status text,
  next_followup_at timestamptz,
  hours_overdue numeric,
  intended_monthly_fee_rupees integer,
  last_touched_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    o.name,
    l.status,
    l.next_followup_at,
    EXTRACT(EPOCH FROM (now() - l.next_followup_at)) / 3600.0,
    l.intended_monthly_fee_rupees,
    l.last_touched_at
  FROM public.founder_hospital_lois l
  JOIN public.organizations o ON o.id = l.hospital_org_id
  WHERE l.status NOT IN ('converted','lost','expired')
    AND l.next_followup_at IS NOT NULL
    AND l.next_followup_at < now()
  ORDER BY l.next_followup_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_followup_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_followup_due() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_lost_reason_breakdown()
RETURNS TABLE(
  lost_reason text,
  loi_count bigint,
  lost_arr_rupees bigint,
  pct_of_lost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  total_lost bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_lost FROM public.founder_hospital_lois WHERE status = 'lost';
  RETURN QUERY
  SELECT
    COALESCE(l.lost_reason, 'other'),
    COUNT(*),
    COALESCE(SUM(l.intended_monthly_fee_rupees * 12), 0)::bigint,
    CASE WHEN total_lost > 0 THEN ROUND(100.0 * COUNT(*)::numeric / total_lost, 2) ELSE 0 END
  FROM public.founder_hospital_lois l
  WHERE l.status = 'lost'
  GROUP BY COALESCE(l.lost_reason, 'other')
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_lost_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_lost_reason_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_conversion_funnel()
RETURNS TABLE(
  stage text,
  loi_count bigint,
  arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stage, COALESCE(c.cnt, 0), COALESCE(c.arr, 0)::bigint
  FROM (VALUES ('signed',1),('in_discussion',2),('contract_drafted',3),('awaiting_payment',4),('converted',5)) AS s(stage, ord)
  LEFT JOIN (
    SELECT status, COUNT(*) AS cnt, COALESCE(SUM(intended_monthly_fee_rupees * 12), 0) AS arr
    FROM public.founder_hospital_lois
    GROUP BY status
  ) c ON c.status = s.stage
  ORDER BY s.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_conversion_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_conversion_funnel() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_recent_touchpoints()
RETURNS TABLE(
  id uuid,
  loi_id uuid,
  hospital_name text,
  touched_at timestamptz,
  channel text,
  outcome text,
  next_step text,
  logged_by_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id, t.loi_id, o.name, t.touched_at, t.channel, t.outcome, t.next_step, t.logged_by_email
  FROM public.founder_hospital_loi_touchpoints t
  JOIN public.founder_hospital_lois l ON l.id = t.loi_id
  JOIN public.organizations o ON o.id = l.hospital_org_id
  ORDER BY t.touched_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_recent_touchpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_recent_touchpoints() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_loi_aging_buckets()
RETURNS TABLE(
  bucket text,
  loi_count bigint,
  arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bucket, COUNT(l.id), COALESCE(SUM(l.intended_monthly_fee_rupees * 12), 0)::bigint
  FROM (VALUES ('0-7d',1),('8-14d',2),('15-30d',3),('31-60d',4),('60d+',5)) AS b(bucket, ord)
  LEFT JOIN public.founder_hospital_lois l ON
    l.status NOT IN ('converted','lost','expired') AND
    CASE
      WHEN EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0 <= 7 THEN '0-7d'
      WHEN EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0 <= 14 THEN '8-14d'
      WHEN EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0 <= 30 THEN '15-30d'
      WHEN EXTRACT(EPOCH FROM (now() - l.signed_at))/86400.0 <= 60 THEN '31-60d'
      ELSE '60d+'
    END = b.bucket
  GROUP BY b.bucket, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_loi_aging_buckets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_loi_aging_buckets() TO authenticated;

-- ============================================================
-- WRITE / LOG helpers (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_founder_loi_status_change(p_loi_id uuid, p_new_status text, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_hospital_lois
  SET status = p_new_status,
      last_touched_at = now(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_loi_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_status_change',
    jsonb_build_object('loi_id', p_loi_id, 'new_status', p_new_status, 'notes', p_notes));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_loi_status_change(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_loi_status_change(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_loi_mark_lost(p_loi_id uuid, p_lost_reason text, p_lost_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_hospital_lois
  SET status = 'lost', lost_reason = p_lost_reason, lost_notes = p_lost_notes, last_touched_at = now()
  WHERE id = p_loi_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_mark_lost',
    jsonb_build_object('loi_id', p_loi_id, 'lost_reason', p_lost_reason, 'lost_notes', p_lost_notes));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_loi_mark_lost(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_loi_mark_lost(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_loi_log_touchpoint(p_loi_id uuid, p_channel text, p_outcome text, p_next_step text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tp_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_hospital_loi_touchpoints(loi_id, channel, outcome, next_step, notes, logged_by_email)
  VALUES (p_loi_id, p_channel, p_outcome, p_next_step, p_notes, (auth.jwt()->>'email'))
  RETURNING id INTO v_tp_id;
  UPDATE public.founder_hospital_lois SET last_touched_at = now() WHERE id = p_loi_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_log_touchpoint',
    jsonb_build_object('loi_id', p_loi_id, 'touchpoint_id', v_tp_id, 'channel', p_channel, 'outcome', p_outcome));
  RETURN v_tp_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_loi_log_touchpoint(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_loi_log_touchpoint(uuid, text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_loi_schedule_followup(p_loi_id uuid, p_next_followup_at timestamptz)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_hospital_lois
  SET next_followup_at = p_next_followup_at, last_touched_at = now()
  WHERE id = p_loi_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'loi_schedule_followup',
    jsonb_build_object('loi_id', p_loi_id, 'next_followup_at', p_next_followup_at));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_loi_schedule_followup(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_loi_schedule_followup(uuid, timestamptz) TO authenticated;

COMMIT;