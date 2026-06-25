-- Round 2644: customer monthly loyalty tier promotion track
-- Founder-only tables + RPCs to track monthly loyalty tier progression
-- and promotion log per hospital customer.

CREATE TABLE IF NOT EXISTS public.customer_loyalty_tier_track_r2644 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  month_label text NOT NULL,
  current_tier text NOT NULL CHECK (current_tier IN ('bronze','silver','gold','platinum','diamond')),
  points_total int NOT NULL DEFAULT 0,
  next_tier text NOT NULL CHECK (next_tier IN ('silver','gold','platinum','diamond','none')),
  points_to_next int NOT NULL DEFAULT 0,
  projected_promotion_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'progressing' CHECK (status IN ('progressing','stalled','promoted','lapsed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tier_promotion_log_r2644 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id uuid REFERENCES public.customer_loyalty_tier_track_r2644(id) ON DELETE CASCADE,
  promoted_at timestamptz NOT NULL DEFAULT now(),
  from_tier text NOT NULL,
  to_tier text NOT NULL,
  summary_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_loyalty_tier_track_r2644 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tier_promotion_log_r2644 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_loyalty_tier_track_r2644;
CREATE POLICY founder_all ON public.customer_loyalty_tier_track_r2644
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.tier_promotion_log_r2644;
CREATE POLICY founder_all ON public.tier_promotion_log_r2644
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed rows (no apostrophes)
INSERT INTO public.customer_loyalty_tier_track_r2644
  (month_label, current_tier, points_total, next_tier, points_to_next, projected_promotion_at, owner_email, status, notes)
VALUES
  ('2026-06', 'gold', 4200, 'platinum', 800, '2026-07-15T00:00:00Z'::timestamptz, 'loyalty@equipseva.com', 'progressing', 'On pace for platinum after July AMC renewal'),
  ('2026-06', 'silver', 1800, 'gold', 700, '2026-08-01T00:00:00Z'::timestamptz, 'loyalty@equipseva.com', 'stalled', 'Two months no repair bookings'),
  ('2026-06', 'platinum', 9100, 'diamond', 900, '2026-07-25T00:00:00Z'::timestamptz, 'loyalty@equipseva.com', 'progressing', 'Hospital chain expanding'),
  ('2026-05', 'bronze', 400, 'silver', 600, NULL, 'loyalty@equipseva.com', 'lapsed', 'Trial customer churned'),
  ('2026-05', 'gold', 5000, 'platinum', 0, '2026-05-30T00:00:00Z'::timestamptz, 'loyalty@equipseva.com', 'promoted', 'Promoted last cycle');

INSERT INTO public.tier_promotion_log_r2644
  (track_id, promoted_at, from_tier, to_tier, summary_md, owner_email, status, notes)
SELECT id, '2026-05-30T00:00:00Z'::timestamptz, 'gold', 'platinum', '## Promotion\nReached 5000 points via AMC renewal', 'loyalty@equipseva.com', 'done', 'Welcome kit sent'
  FROM public.customer_loyalty_tier_track_r2644 WHERE month_label = '2026-05' AND current_tier = 'gold' LIMIT 1;

INSERT INTO public.tier_promotion_log_r2644
  (track_id, promoted_at, from_tier, to_tier, summary_md, owner_email, status, notes)
SELECT id, '2026-07-15T00:00:00Z'::timestamptz, 'gold', 'platinum', '## Planned\nAwait AMC renewal points', 'loyalty@equipseva.com', 'planned', 'Renewal scheduled'
  FROM public.customer_loyalty_tier_track_r2644 WHERE month_label = '2026-06' AND current_tier = 'gold' LIMIT 1;

INSERT INTO public.tier_promotion_log_r2644
  (track_id, promoted_at, from_tier, to_tier, summary_md, owner_email, status, notes)
SELECT id, '2026-07-25T00:00:00Z'::timestamptz, 'platinum', 'diamond', '## Planned\nChain expansion bonus', 'loyalty@equipseva.com', 'planned', 'Awaiting final contract'
  FROM public.customer_loyalty_tier_track_r2644 WHERE month_label = '2026-06' AND current_tier = 'platinum' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_loyalty_track_r2644()
RETURNS TABLE (
  id uuid,
  month_label text,
  current_tier text,
  points_total int,
  next_tier text,
  points_to_next int,
  projected_promotion_at timestamptz,
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
  SELECT t.id, t.month_label, t.current_tier, t.points_total, t.next_tier, t.points_to_next,
         t.projected_promotion_at, t.owner_email, t.status, t.notes, t.created_at
  FROM public.customer_loyalty_tier_track_r2644 t
  ORDER BY t.month_label DESC, t.points_total DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_loyalty_track_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loyalty_track_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_promotion_log_r2644()
RETURNS TABLE (
  id uuid,
  track_id uuid,
  promoted_at timestamptz,
  from_tier text,
  to_tier text,
  summary_md text,
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
  SELECT l.id, l.track_id, l.promoted_at, l.from_tier, l.to_tier, l.summary_md,
         l.owner_email, l.status, l.notes, l.created_at
  FROM public.tier_promotion_log_r2644 l
  ORDER BY l.promoted_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_promotion_log_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_promotion_log_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_points_focus_r2644()
RETURNS TABLE (
  id uuid,
  month_label text,
  current_tier text,
  next_tier text,
  points_to_next int,
  points_total int,
  owner_email text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.month_label, t.current_tier, t.next_tier, t.points_to_next, t.points_total,
         t.owner_email, t.status
  FROM public.customer_loyalty_tier_track_r2644 t
  WHERE t.status IN ('progressing','stalled')
  ORDER BY t.points_to_next ASC, t.points_total DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_points_focus_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_points_focus_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.tier_distribution_r2644()
RETURNS TABLE (tier text, track_count bigint, total_points bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.current_tier AS tier, COUNT(*)::bigint AS track_count, COALESCE(SUM(t.points_total),0)::bigint AS total_points
  FROM public.customer_loyalty_tier_track_r2644 t
  GROUP BY t.current_tier
  ORDER BY t.current_tier;
END $$;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2644()
RETURNS TABLE (status text, track_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status, COUNT(*)::bigint
  FROM public.customer_loyalty_tier_track_r2644 t
  GROUP BY t.status
  ORDER BY t.status;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_promotion_trend_r2644()
RETURNS TABLE (month_bucket text, promotions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.promoted_at), 'YYYY-MM') AS month_bucket,
         COUNT(*)::bigint AS promotions
  FROM public.tier_promotion_log_r2644 l
  WHERE l.status = 'done'
  GROUP BY 1
  ORDER BY 1 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_promotion_trend_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_promotion_trend_r2644() TO authenticated;

CREATE OR REPLACE FUNCTION public.projected_promotions_30d_summary_r2644()
RETURNS TABLE (
  total_projected bigint,
  progressing_count bigint,
  stalled_count bigint,
  avg_points_to_next numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE t.projected_promotion_at IS NOT NULL AND t.projected_promotion_at <= (now() + interval '30 days'))::bigint AS total_projected,
    COUNT(*) FILTER (WHERE t.status = 'progressing')::bigint AS progressing_count,
    COUNT(*) FILTER (WHERE t.status = 'stalled')::bigint AS stalled_count,
    COALESCE(AVG(t.points_to_next), 0)::numeric AS avg_points_to_next
  FROM public.customer_loyalty_tier_track_r2644 t;
END $$;
REVOKE EXECUTE ON FUNCTION public.projected_promotions_30d_summary_r2644() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.projected_promotions_30d_summary_r2644() TO authenticated;
