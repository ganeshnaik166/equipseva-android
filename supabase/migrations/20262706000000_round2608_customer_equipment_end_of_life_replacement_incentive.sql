-- Round r2608 — customer equipment end-of-life replacement incentive

CREATE TABLE IF NOT EXISTS public.customer_replacement_incentives_r2608 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  old_equipment_label text NOT NULL,
  trade_in_value_rupees bigint NOT NULL DEFAULT 0,
  replacement_upgrade_value_rupees bigint NOT NULL DEFAULT 0,
  incentive_kind text NOT NULL CHECK (incentive_kind IN ('trade_in_credit','loyalty_discount','buyback','extended_warranty','free_install')),
  close_probability_pct int NOT NULL DEFAULT 0 CHECK (close_probability_pct BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','negotiating','accepted','rejected','dropped')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.replacement_incentive_close_log_r2608 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  incentive_id uuid NOT NULL REFERENCES public.customer_replacement_incentives_r2608(id) ON DELETE CASCADE,
  closed_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL CHECK (decision_kind IN ('closed_won','closed_lost','postponed')),
  realized_arr_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.customer_replacement_incentives_r2608 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.replacement_incentive_close_log_r2608 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_replacement_incentives_r2608;
CREATE POLICY founder_all ON public.customer_replacement_incentives_r2608 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.replacement_incentive_close_log_r2608;
CREATE POLICY founder_all ON public.replacement_incentive_close_log_r2608 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.customer_replacement_incentives_r2608 (old_equipment_label, trade_in_value_rupees, replacement_upgrade_value_rupees, incentive_kind, close_probability_pct, owner_email, status, notes) VALUES
  ('Phillips MX400 monitor 9yr', 45000, 380000, 'trade_in_credit', 70, 'sales1@equipseva.local', 'negotiating', 'eol unit hospital wants new gen'),
  ('GE CT scanner 11yr', 850000, 6500000, 'buyback', 55, 'sales2@equipseva.local', 'proposed', 'chain-wide replacement pitch'),
  ('Mindray ventilator 8yr', 28000, 240000, 'loyalty_discount', 80, 'sales1@equipseva.local', 'accepted', 'closing soon'),
  ('Drager anaesthesia 12yr', 60000, 520000, 'extended_warranty', 35, 'sales3@equipseva.local', 'negotiating', 'cfo pushback on price'),
  ('Siemens ultrasound 7yr', 32000, 290000, 'free_install', 50, 'sales2@equipseva.local', 'rejected', 'went with competitor');

INSERT INTO public.replacement_incentive_close_log_r2608 (incentive_id, decision_kind, realized_arr_rupees, owner_email, status, notes)
SELECT id, 'closed_won', 240000, owner_email, 'done', 'vent deal locked' FROM public.customer_replacement_incentives_r2608 WHERE old_equipment_label = 'Mindray ventilator 8yr' LIMIT 1;

INSERT INTO public.replacement_incentive_close_log_r2608 (incentive_id, decision_kind, realized_arr_rupees, owner_email, status, notes)
SELECT id, 'closed_lost', 0, owner_email, 'done', 'lost to competitor' FROM public.customer_replacement_incentives_r2608 WHERE old_equipment_label = 'Siemens ultrasound 7yr' LIMIT 1;

INSERT INTO public.replacement_incentive_close_log_r2608 (incentive_id, decision_kind, realized_arr_rupees, owner_email, status, notes)
SELECT id, 'postponed', 0, owner_email, 'open', 'cfo review pending' FROM public.customer_replacement_incentives_r2608 WHERE old_equipment_label = 'Drager anaesthesia 12yr' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_incentives_r2608()
RETURNS TABLE(id uuid, created_at timestamptz, old_equipment_label text, trade_in_value_rupees bigint, replacement_upgrade_value_rupees bigint, incentive_kind text, close_probability_pct int, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.created_at, i.old_equipment_label, i.trade_in_value_rupees, i.replacement_upgrade_value_rupees, i.incentive_kind, i.close_probability_pct, i.owner_email, i.status, i.notes
  FROM public.customer_replacement_incentives_r2608 i
  ORDER BY i.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_incentives_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_incentives_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_close_log_r2608()
RETURNS TABLE(id uuid, incentive_id uuid, old_equipment_label text, closed_at timestamptz, decision_kind text, realized_arr_rupees bigint, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.incentive_id, i.old_equipment_label, l.closed_at, l.decision_kind, l.realized_arr_rupees, l.owner_email, l.status, l.notes
  FROM public.replacement_incentive_close_log_r2608 l
  LEFT JOIN public.customer_replacement_incentives_r2608 i ON i.id = l.incentive_id
  ORDER BY l.closed_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_close_log_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_close_log_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_close_prob_focus_r2608()
RETURNS TABLE(id uuid, old_equipment_label text, incentive_kind text, close_probability_pct int, replacement_upgrade_value_rupees bigint, status text, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.old_equipment_label, i.incentive_kind, i.close_probability_pct, i.replacement_upgrade_value_rupees, i.status, i.owner_email
  FROM public.customer_replacement_incentives_r2608 i
  WHERE i.status IN ('proposed','negotiating')
  ORDER BY i.close_probability_pct DESC, i.replacement_upgrade_value_rupees DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_close_prob_focus_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_close_prob_focus_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.incentive_kind_distribution_r2608()
RETURNS TABLE(incentive_kind text, total_count bigint, accepted_count bigint, total_upgrade_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.incentive_kind,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE i.status = 'accepted')::bigint,
         COALESCE(SUM(i.replacement_upgrade_value_rupees), 0)::bigint
  FROM public.customer_replacement_incentives_r2608 i
  GROUP BY i.incentive_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.incentive_kind_distribution_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.incentive_kind_distribution_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_realized_arr_summary_r2608()
RETURNS TABLE(total_closed bigint, won_count bigint, lost_count bigint, postponed_count bigint, total_realized_arr_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE l.decision_kind = 'closed_won')::bigint,
         COUNT(*) FILTER (WHERE l.decision_kind = 'closed_lost')::bigint,
         COUNT(*) FILTER (WHERE l.decision_kind = 'postponed')::bigint,
         COALESCE(SUM(l.realized_arr_rupees) FILTER (WHERE l.decision_kind = 'closed_won'), 0)::bigint
  FROM public.replacement_incentive_close_log_r2608 l;
END $$;
REVOKE EXECUTE ON FUNCTION public.total_realized_arr_summary_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_realized_arr_summary_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_close_trend_r2608()
RETURNS TABLE(month_label text, total_closed bigint, won_count bigint, total_realized_arr_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', l.closed_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE l.decision_kind = 'closed_won')::bigint,
         COALESCE(SUM(l.realized_arr_rupees) FILTER (WHERE l.decision_kind = 'closed_won'), 0)::bigint
  FROM public.replacement_incentive_close_log_r2608 l
  GROUP BY date_trunc('month', l.closed_at)
  ORDER BY date_trunc('month', l.closed_at) DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_close_trend_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_close_trend_r2608() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2608()
RETURNS TABLE(status text, total_count bigint, total_upgrade_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.status,
         COUNT(*)::bigint,
         COALESCE(SUM(i.replacement_upgrade_value_rupees), 0)::bigint
  FROM public.customer_replacement_incentives_r2608 i
  GROUP BY i.status
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2608() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2608() TO authenticated;
