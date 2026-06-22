BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_snapshots_r2021 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_label text NOT NULL,
  snapshot_date date NOT NULL,
  total_shares bigint NOT NULL DEFAULT 0,
  founder_shares bigint NOT NULL DEFAULT 0,
  investor_shares bigint NOT NULL DEFAULT 0,
  option_pool_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_cap_table_snapshot_review_log_r2021 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid NOT NULL REFERENCES public.investor_cap_table_snapshots_r2021(id) ON DELETE CASCADE,
  review_type text NOT NULL CHECK (review_type IN ('periodic','triggered','incident','audit')),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  finding_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_snapshots_r2021 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_cap_table_snapshot_review_log_r2021 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_snap_r2021 ON public.investor_cap_table_snapshots_r2021;
CREATE POLICY founder_all_snap_r2021 ON public.investor_cap_table_snapshots_r2021
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_rev_r2021 ON public.investor_cap_table_snapshot_review_log_r2021;
CREATE POLICY founder_all_rev_r2021 ON public.investor_cap_table_snapshot_review_log_r2021
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_cap_snapshots_r2021()
RETURNS SETOF public.investor_cap_table_snapshots_r2021
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_snapshots_r2021 ORDER BY snapshot_date DESC, captured_at DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.log_cap_snapshot_r2021(
  p_label text, p_date date, p_total bigint, p_founder bigint, p_investor bigint, p_pool bigint, p_status text DEFAULT 'active'
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_snapshots_r2021(snapshot_label, snapshot_date, total_shares, founder_shares, investor_shares, option_pool_shares, status)
  VALUES (p_label, p_date, p_total, p_founder, p_investor, p_pool, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cap_snapshot_r2021', jsonb_build_object('id', v_id, 'label', p_label), now());
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.list_cap_snapshot_reviews_r2021()
RETURNS SETOF public.investor_cap_table_snapshot_review_log_r2021
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_snapshot_review_log_r2021 ORDER BY reviewed_at DESC;
END;$$;

CREATE OR REPLACE FUNCTION public.log_cap_snapshot_review_r2021(
  p_snapshot_id uuid, p_review_type text, p_by_email text, p_finding_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_snapshot_review_log_r2021(snapshot_id, review_type, by_email, finding_md)
  VALUES (p_snapshot_id, p_review_type, p_by_email, p_finding_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cap_snapshot_review_r2021', jsonb_build_object('id', v_id, 'snapshot_id', p_snapshot_id, 'type', p_review_type), now());
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.mark_cap_snapshot_status_r2021(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_snapshots_r2021 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_cap_snapshot_status_r2021', jsonb_build_object('id', p_id, 'status', p_status), now());
END;$$;

CREATE OR REPLACE FUNCTION public.latest_cap_snapshot_r2021()
RETURNS SETOF public.investor_cap_table_snapshots_r2021
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_snapshots_r2021 WHERE status = 'active' ORDER BY snapshot_date DESC, captured_at DESC LIMIT 1;
END;$$;

CREATE OR REPLACE FUNCTION public.recent_cap_snapshot_reviews_r2021(p_limit int DEFAULT 20)
RETURNS SETOF public.investor_cap_table_snapshot_review_log_r2021
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_cap_table_snapshot_review_log_r2021 ORDER BY reviewed_at DESC LIMIT COALESCE(p_limit, 20);
END;$$;

REVOKE EXECUTE ON FUNCTION public.list_cap_snapshots_r2021() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cap_snapshot_r2021(text, date, bigint, bigint, bigint, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_cap_snapshot_reviews_r2021() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cap_snapshot_review_r2021(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_cap_snapshot_status_r2021(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.latest_cap_snapshot_r2021() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_cap_snapshot_reviews_r2021(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cap_snapshots_r2021() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cap_snapshot_r2021(text, date, bigint, bigint, bigint, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_cap_snapshot_reviews_r2021() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cap_snapshot_review_r2021(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_cap_snapshot_status_r2021(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.latest_cap_snapshot_r2021() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_cap_snapshot_reviews_r2021(int) TO authenticated;

COMMIT;
