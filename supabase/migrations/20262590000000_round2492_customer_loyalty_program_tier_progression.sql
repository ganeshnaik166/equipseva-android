-- Round 2492: customer-loyalty-program-tier-progression
-- Tables: customer_loyalty_status_r2492, loyalty_tier_progression_history_r2492

BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_loyalty_status_r2492 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  loyalty_tier text NOT NULL CHECK (loyalty_tier IN ('bronze','silver','gold','platinum','diamond')),
  points_total int NOT NULL DEFAULT 0,
  points_this_month int NOT NULL DEFAULT 0,
  renewals_count int NOT NULL DEFAULT 0,
  benefits_unlocked_md text,
  next_tier_threshold_points int NOT NULL DEFAULT 0,
  points_to_next_tier int NOT NULL DEFAULT 0,
  tier_up_alert_kind text NOT NULL DEFAULT 'none' CHECK (tier_up_alert_kind IN ('none','within_10pct','within_5pct','eligible_now')),
  tier_up_alert_sent_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','at_risk','lapsed','churned')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_tier_progression_history_r2492 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  change_at timestamptz NOT NULL DEFAULT now(),
  prior_tier text,
  new_tier text,
  reason_kind text NOT NULL CHECK (reason_kind IN ('renewal','manual_adjust','promotion','downgrade','freeze')),
  points_at_change int NOT NULL DEFAULT 0,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_loyalty_status_r2492 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_tier_progression_history_r2492 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_loyalty_status_r2492;
CREATE POLICY founder_all ON public.customer_loyalty_status_r2492
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.loyalty_tier_progression_history_r2492;
CREATE POLICY founder_all ON public.loyalty_tier_progression_history_r2492
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed status rows from existing hospital_admin profiles
INSERT INTO public.customer_loyalty_status_r2492
  (hospital_user_id, loyalty_tier, points_total, points_this_month, renewals_count, benefits_unlocked_md, next_tier_threshold_points, points_to_next_tier, tier_up_alert_kind, tier_up_alert_sent_at, status, notes)
SELECT p.id, 'gold', 4750, 420, 3,
       '- Priority engineer dispatch\n- Free quarterly preventive\n- 5pct AMC renewal discount',
       5000, 250, 'within_5pct', '2026-06-18T09:00:00Z'::timestamptz,
       'active', 'Close to platinum — push renewal'
FROM public.profiles p
WHERE p.role = 'hospital_admin'
ORDER BY p.created_at ASC
LIMIT 1;

INSERT INTO public.customer_loyalty_status_r2492
  (hospital_user_id, loyalty_tier, points_total, points_this_month, renewals_count, benefits_unlocked_md, next_tier_threshold_points, points_to_next_tier, tier_up_alert_kind, tier_up_alert_sent_at, status, notes)
SELECT p.id, 'silver', 2300, 180, 2,
       '- 4hr response SLA\n- Free spare-part sourcing assist',
       3000, 700, 'within_10pct', '2026-06-15T10:00:00Z'::timestamptz,
       'active', 'Stable customer'
FROM public.profiles p
WHERE p.role = 'hospital_admin'
ORDER BY p.created_at ASC
OFFSET 1 LIMIT 1;

INSERT INTO public.customer_loyalty_status_r2492
  (hospital_user_id, loyalty_tier, points_total, points_this_month, renewals_count, benefits_unlocked_md, next_tier_threshold_points, points_to_next_tier, tier_up_alert_kind, tier_up_alert_sent_at, status, notes)
SELECT p.id, 'platinum', 8200, 90, 5,
       '- Dedicated account manager\n- Quarterly business review\n- 10pct AMC discount\n- Free loaner equipment',
       10000, 1800, 'none', NULL,
       'at_risk', 'Points momentum slowed — engagement review'
FROM public.profiles p
WHERE p.role = 'hospital_admin'
ORDER BY p.created_at ASC
OFFSET 2 LIMIT 1;

INSERT INTO public.customer_loyalty_status_r2492
  (hospital_user_id, loyalty_tier, points_total, points_this_month, renewals_count, benefits_unlocked_md, next_tier_threshold_points, points_to_next_tier, tier_up_alert_kind, tier_up_alert_sent_at, status, notes)
SELECT p.id, 'bronze', 480, 0, 0,
       '- Standard SLA\n- Monthly newsletter',
       1000, 520, 'none', NULL,
       'lapsed', 'No activity 60 days'
FROM public.profiles p
WHERE p.role = 'hospital_admin'
ORDER BY p.created_at ASC
OFFSET 3 LIMIT 1;

INSERT INTO public.customer_loyalty_status_r2492
  (hospital_user_id, loyalty_tier, points_total, points_this_month, renewals_count, benefits_unlocked_md, next_tier_threshold_points, points_to_next_tier, tier_up_alert_kind, tier_up_alert_sent_at, status, notes)
SELECT p.id, 'diamond', 14200, 1100, 7,
       '- White-glove service\n- Direct founder line\n- 15pct AMC discount\n- Annual strategy session\n- Co-marketing eligibility',
       14200, 0, 'eligible_now', '2026-06-20T08:00:00Z'::timestamptz,
       'active', 'Top-tier — protect at all costs'
FROM public.profiles p
WHERE p.role = 'hospital_admin'
ORDER BY p.created_at ASC
OFFSET 4 LIMIT 1;

-- Seed progression history
INSERT INTO public.loyalty_tier_progression_history_r2492
  (hospital_user_id, change_at, prior_tier, new_tier, reason_kind, points_at_change, owner_email, notes)
SELECT s.hospital_user_id, '2026-03-10T10:00:00Z'::timestamptz, 'silver', 'gold', 'renewal', 3000, 'cs@equipseva.in', 'Renewed AMC tier-2'
FROM public.customer_loyalty_status_r2492 s WHERE s.loyalty_tier = 'gold' LIMIT 1;

INSERT INTO public.loyalty_tier_progression_history_r2492
  (hospital_user_id, change_at, prior_tier, new_tier, reason_kind, points_at_change, owner_email, notes)
SELECT s.hospital_user_id, '2026-02-20T09:00:00Z'::timestamptz, 'bronze', 'silver', 'renewal', 1000, 'cs@equipseva.in', 'First annual renewal'
FROM public.customer_loyalty_status_r2492 s WHERE s.loyalty_tier = 'silver' LIMIT 1;

INSERT INTO public.loyalty_tier_progression_history_r2492
  (hospital_user_id, change_at, prior_tier, new_tier, reason_kind, points_at_change, owner_email, notes)
SELECT s.hospital_user_id, '2026-01-15T11:00:00Z'::timestamptz, 'gold', 'platinum', 'promotion', 5500, 'founder@equipseva.in', 'Strategic upgrade'
FROM public.customer_loyalty_status_r2492 s WHERE s.loyalty_tier = 'platinum' LIMIT 1;

INSERT INTO public.loyalty_tier_progression_history_r2492
  (hospital_user_id, change_at, prior_tier, new_tier, reason_kind, points_at_change, owner_email, notes)
SELECT s.hospital_user_id, '2026-04-25T14:00:00Z'::timestamptz, 'silver', 'bronze', 'downgrade', 480, 'cs@equipseva.in', 'Lapsed renewal'
FROM public.customer_loyalty_status_r2492 s WHERE s.loyalty_tier = 'bronze' LIMIT 1;

INSERT INTO public.loyalty_tier_progression_history_r2492
  (hospital_user_id, change_at, prior_tier, new_tier, reason_kind, points_at_change, owner_email, notes)
SELECT s.hospital_user_id, '2026-05-30T16:00:00Z'::timestamptz, 'platinum', 'diamond', 'promotion', 14200, 'founder@equipseva.in', 'Top customer milestone'
FROM public.customer_loyalty_status_r2492 s WHERE s.loyalty_tier = 'diamond' LIMIT 1;

-- RPC 1: list loyalty status
CREATE OR REPLACE FUNCTION public.list_loyalty_status_r2492()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  loyalty_tier text,
  points_total int,
  points_this_month int,
  renewals_count int,
  benefits_unlocked_md text,
  next_tier_threshold_points int,
  points_to_next_tier int,
  tier_up_alert_kind text,
  tier_up_alert_sent_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.loyalty_tier, s.points_total, s.points_this_month, s.renewals_count,
         s.benefits_unlocked_md, s.next_tier_threshold_points, s.points_to_next_tier,
         s.tier_up_alert_kind, s.tier_up_alert_sent_at, s.status, s.notes, s.created_at
  FROM public.customer_loyalty_status_r2492 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.points_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_loyalty_status_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loyalty_status_r2492() TO authenticated;

-- RPC 2: list progression history
CREATE OR REPLACE FUNCTION public.list_tier_progression_history_r2492()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  change_at timestamptz,
  prior_tier text,
  new_tier text,
  reason_kind text,
  points_at_change int,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, p.email, h.change_at, h.prior_tier, h.new_tier, h.reason_kind,
         h.points_at_change, h.owner_email, h.notes
  FROM public.loyalty_tier_progression_history_r2492 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.change_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_tier_progression_history_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_tier_progression_history_r2492() TO authenticated;

-- RPC 3: eligible for upgrade
CREATE OR REPLACE FUNCTION public.eligible_for_upgrade_r2492()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  loyalty_tier text,
  points_total int,
  next_tier_threshold_points int,
  points_to_next_tier int,
  tier_up_alert_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.loyalty_tier, s.points_total, s.next_tier_threshold_points,
         s.points_to_next_tier, s.tier_up_alert_kind
  FROM public.customer_loyalty_status_r2492 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.tier_up_alert_kind IN ('within_10pct','within_5pct','eligible_now')
  ORDER BY s.points_to_next_tier ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.eligible_for_upgrade_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eligible_for_upgrade_r2492() TO authenticated;

-- RPC 4: top points hospitals
CREATE OR REPLACE FUNCTION public.top_points_hospitals_r2492()
RETURNS TABLE (
  hospital_email text,
  loyalty_tier text,
  points_total int,
  renewals_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email, s.loyalty_tier, s.points_total, s.renewals_count, s.status
  FROM public.customer_loyalty_status_r2492 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.points_total DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_points_hospitals_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_points_hospitals_r2492() TO authenticated;

-- RPC 5: tier distribution
CREATE OR REPLACE FUNCTION public.tier_distribution_r2492()
RETURNS TABLE (
  loyalty_tier text,
  hospital_count bigint,
  total_points bigint,
  avg_renewals numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.loyalty_tier,
         COUNT(*)::bigint,
         COALESCE(SUM(s.points_total),0)::bigint,
         ROUND(AVG(s.renewals_count)::numeric, 2)
  FROM public.customer_loyalty_status_r2492 s
  GROUP BY s.loyalty_tier
  ORDER BY total_points DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r2492() TO authenticated;

-- RPC 6: monthly progression trend
CREATE OR REPLACE FUNCTION public.monthly_progression_trend_r2492()
RETURNS TABLE (
  month_label text,
  change_count bigint,
  promotions bigint,
  downgrades bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', h.change_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE h.reason_kind IN ('promotion','renewal'))::bigint,
         COUNT(*) FILTER (WHERE h.reason_kind = 'downgrade')::bigint
  FROM public.loyalty_tier_progression_history_r2492 h
  GROUP BY date_trunc('month', h.change_at)
  ORDER BY date_trunc('month', h.change_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_progression_trend_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_progression_trend_r2492() TO authenticated;

-- RPC 7: churn risk focus
CREATE OR REPLACE FUNCTION public.churn_risk_focus_r2492()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  loyalty_tier text,
  points_total int,
  points_this_month int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, p.email, s.loyalty_tier, s.points_total, s.points_this_month, s.status, s.notes
  FROM public.customer_loyalty_status_r2492 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.status IN ('at_risk','lapsed','churned')
  ORDER BY s.points_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.churn_risk_focus_r2492() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.churn_risk_focus_r2492() TO authenticated;

