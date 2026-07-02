BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_spare_parts_orders_r1728 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  part_name text NOT NULL,
  part_sku text,
  quantity int NOT NULL CHECK (quantity > 0),
  unit_cost_rupees int NOT NULL CHECK (unit_cost_rupees >= 0),
  ordered_at timestamptz NOT NULL DEFAULT now(),
  expected_at timestamptz,
  delivered_at timestamptz,
  status text NOT NULL DEFAULT 'ordered' CHECK (status IN ('ordered','in_transit','delivered','cancelled','returned')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_espo_r1728_engineer ON public.engineer_spare_parts_orders_r1728(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_espo_r1728_status ON public.engineer_spare_parts_orders_r1728(status);
CREATE INDEX IF NOT EXISTS idx_espo_r1728_ordered_at ON public.engineer_spare_parts_orders_r1728(ordered_at DESC);

ALTER TABLE public.engineer_spare_parts_orders_r1728 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS espo_r1728_founder_all ON public.engineer_spare_parts_orders_r1728;
CREATE POLICY espo_r1728_founder_all ON public.engineer_spare_parts_orders_r1728
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_spare_parts_usage_r1728 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.engineer_spare_parts_orders_r1728(id) ON DELETE CASCADE,
  used_in_repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  used_at timestamptz NOT NULL DEFAULT now(),
  returned_quantity int NOT NULL DEFAULT 0 CHECK (returned_quantity >= 0),
  return_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_espu_r1728_order ON public.engineer_spare_parts_usage_r1728(order_id);
CREATE INDEX IF NOT EXISTS idx_espu_r1728_used_at ON public.engineer_spare_parts_usage_r1728(used_at DESC);

ALTER TABLE public.engineer_spare_parts_usage_r1728 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS espu_r1728_founder_all ON public.engineer_spare_parts_usage_r1728;
CREATE POLICY espu_r1728_founder_all ON public.engineer_spare_parts_usage_r1728
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_orders
CREATE OR REPLACE FUNCTION public.list_engineer_spare_parts_orders_r1728()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  repair_job_id uuid,
  part_name text,
  part_sku text,
  quantity int,
  unit_cost_rupees int,
  total_cost_rupees int,
  ordered_at timestamptz,
  expected_at timestamptz,
  delivered_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.engineer_user_id, p.email::text, o.repair_job_id, o.part_name, o.part_sku,
    o.quantity, o.unit_cost_rupees, (o.quantity * o.unit_cost_rupees)::int AS total_cost_rupees,
    o.ordered_at, o.expected_at, o.delivered_at, o.status
  FROM public.engineer_spare_parts_orders_r1728 o
  LEFT JOIN public.profiles p ON p.id = o.engineer_user_id
  ORDER BY o.ordered_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engineer_spare_parts_orders_r1728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_spare_parts_orders_r1728() TO authenticated;

-- RPC 2: place_order
CREATE OR REPLACE FUNCTION public.place_engineer_spare_parts_order_r1728(
  p_engineer_user_id uuid,
  p_repair_job_id uuid,
  p_part_name text,
  p_part_sku text,
  p_quantity int,
  p_unit_cost_rupees int,
  p_expected_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_spare_parts_orders_r1728(engineer_user_id, repair_job_id, part_name, part_sku, quantity, unit_cost_rupees, expected_at)
  VALUES (p_engineer_user_id, p_repair_job_id, p_part_name, p_part_sku, p_quantity, p_unit_cost_rupees, p_expected_at)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'place_engineer_spare_parts_order_r1728',
    jsonb_build_object('order_id', v_id, 'engineer', p_engineer_user_id, 'part', p_part_name, 'qty', p_quantity));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.place_engineer_spare_parts_order_r1728(uuid, uuid, text, text, int, int, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_engineer_spare_parts_order_r1728(uuid, uuid, text, text, int, int, timestamptz) TO authenticated;

-- RPC 3: list_usage
CREATE OR REPLACE FUNCTION public.list_engineer_spare_parts_usage_r1728()
RETURNS TABLE (
  id uuid,
  order_id uuid,
  part_name text,
  used_in_repair_job_id uuid,
  used_at timestamptz,
  returned_quantity int,
  return_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.order_id, o.part_name, u.used_in_repair_job_id, u.used_at, u.returned_quantity, u.return_reason
  FROM public.engineer_spare_parts_usage_r1728 u
  LEFT JOIN public.engineer_spare_parts_orders_r1728 o ON o.id = u.order_id
  ORDER BY u.used_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engineer_spare_parts_usage_r1728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_spare_parts_usage_r1728() TO authenticated;

-- RPC 4: record_usage
CREATE OR REPLACE FUNCTION public.record_engineer_spare_parts_usage_r1728(
  p_order_id uuid,
  p_used_in_repair_job_id uuid,
  p_returned_quantity int,
  p_return_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_spare_parts_usage_r1728(order_id, used_in_repair_job_id, returned_quantity, return_reason)
  VALUES (p_order_id, p_used_in_repair_job_id, COALESCE(p_returned_quantity, 0), p_return_reason)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_engineer_spare_parts_usage_r1728',
    jsonb_build_object('usage_id', v_id, 'order_id', p_order_id, 'returned_qty', p_returned_quantity));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_engineer_spare_parts_usage_r1728(uuid, uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_engineer_spare_parts_usage_r1728(uuid, uuid, int, text) TO authenticated;

-- RPC 5: mark_delivered
CREATE OR REPLACE FUNCTION public.mark_engineer_spare_parts_delivered_r1728(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_spare_parts_orders_r1728
    SET status = 'delivered', delivered_at = now(), updated_at = now()
    WHERE id = p_order_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_engineer_spare_parts_delivered_r1728',
    jsonb_build_object('order_id', p_order_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_engineer_spare_parts_delivered_r1728(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_engineer_spare_parts_delivered_r1728(uuid) TO authenticated;

-- RPC 6: parts_spend_summary
CREATE OR REPLACE FUNCTION public.engineer_spare_parts_spend_summary_r1728()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_orders int,
  total_spend_rupees bigint,
  delivered_count int,
  cancelled_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.engineer_user_id, p.email::text,
    (COUNT(*))::int AS total_orders,
    SUM(o.quantity * o.unit_cost_rupees)::bigint AS total_spend_rupees,
    (COUNT(*) FILTER (WHERE o.status = 'delivered'))::int AS delivered_count,
    (COUNT(*) FILTER (WHERE o.status = 'cancelled'))::int AS cancelled_count
  FROM public.engineer_spare_parts_orders_r1728 o
  LEFT JOIN public.profiles p ON p.id = o.engineer_user_id
  GROUP BY o.engineer_user_id, p.email
  ORDER BY total_spend_rupees DESC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_spare_parts_spend_summary_r1728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_spare_parts_spend_summary_r1728() TO authenticated;

-- RPC 7: returns_audit
CREATE OR REPLACE FUNCTION public.engineer_spare_parts_returns_audit_r1728()
RETURNS TABLE (
  usage_id uuid,
  order_id uuid,
  part_name text,
  engineer_user_id uuid,
  engineer_email text,
  returned_quantity int,
  return_reason text,
  used_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id AS usage_id, u.order_id, o.part_name, o.engineer_user_id, p.email::text,
    u.returned_quantity, u.return_reason, u.used_at
  FROM public.engineer_spare_parts_usage_r1728 u
  JOIN public.engineer_spare_parts_orders_r1728 o ON o.id = u.order_id
  LEFT JOIN public.profiles p ON p.id = o.engineer_user_id
  WHERE u.returned_quantity > 0
  ORDER BY u.used_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_spare_parts_returns_audit_r1728() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_spare_parts_returns_audit_r1728() TO authenticated;

COMMIT;