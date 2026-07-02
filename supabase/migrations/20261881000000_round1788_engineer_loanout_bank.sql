BEGIN;
-- Round 1788 — Engineer Equipment Loanout Bank (HEAVY)
-- Central bank of tools/equipment loanable across engineers + checkout system.


-- =====================================================================
-- TABLES
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_loanout_bank_inventory_r1788 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_name text NOT NULL,
  equipment_type text NOT NULL CHECK (equipment_type IN ('diagnostic','calibration','specialized_tool','safety_gear','measurement')),
  total_units int NOT NULL DEFAULT 1 CHECK (total_units >= 0),
  currently_out int NOT NULL DEFAULT 0 CHECK (currently_out >= 0),
  condition text NOT NULL DEFAULT 'good' CHECK (condition IN ('new','good','fair','poor')),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','limited','out_of_stock')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_loanout_checkouts_r1788 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL REFERENCES public.engineer_loanout_bank_inventory_r1788(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  checked_out_at timestamptz NOT NULL DEFAULT now(),
  expected_return_at timestamptz NOT NULL,
  returned_at timestamptz,
  status text NOT NULL DEFAULT 'checked_out' CHECK (status IN ('checked_out','overdue','returned','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_loanout_inv_r1788_status ON public.engineer_loanout_bank_inventory_r1788(status);
CREATE INDEX IF NOT EXISTS idx_loanout_chk_r1788_inv ON public.engineer_loanout_checkouts_r1788(inventory_id);
CREATE INDEX IF NOT EXISTS idx_loanout_chk_r1788_eng ON public.engineer_loanout_checkouts_r1788(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_loanout_chk_r1788_status ON public.engineer_loanout_checkouts_r1788(status);

-- =====================================================================
-- RLS
-- =====================================================================

ALTER TABLE public.engineer_loanout_bank_inventory_r1788 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_loanout_checkouts_r1788 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_loanout_inv_r1788 ON public.engineer_loanout_bank_inventory_r1788;
CREATE POLICY founder_all_loanout_inv_r1788 ON public.engineer_loanout_bank_inventory_r1788
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_loanout_chk_r1788 ON public.engineer_loanout_checkouts_r1788;
CREATE POLICY founder_all_loanout_chk_r1788 ON public.engineer_loanout_checkouts_r1788
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.engineer_loanout_bank_inventory_r1788 FROM PUBLIC, anon;
REVOKE ALL ON public.engineer_loanout_checkouts_r1788 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.engineer_loanout_bank_inventory_r1788 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.engineer_loanout_checkouts_r1788 TO authenticated;

-- =====================================================================
-- RPC 1: list_inventory
-- =====================================================================

DROP FUNCTION IF EXISTS public.list_loanout_inventory_r1788();
CREATE OR REPLACE FUNCTION public.list_loanout_inventory_r1788()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  equipment_type text,
  total_units int,
  currently_out int,
  available_units int,
  condition text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.equipment_name, i.equipment_type, i.total_units, i.currently_out,
         GREATEST(i.total_units - i.currently_out, 0) AS available_units,
         i.condition, i.status, i.notes, i.created_at
  FROM public.engineer_loanout_bank_inventory_r1788 i
  ORDER BY i.equipment_type, i.equipment_name;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loanout_inventory_r1788() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loanout_inventory_r1788() TO authenticated;

-- =====================================================================
-- RPC 2: add_inventory
-- =====================================================================

DROP FUNCTION IF EXISTS public.add_loanout_inventory_r1788(text, text, int, text, text);
CREATE OR REPLACE FUNCTION public.add_loanout_inventory_r1788(
  p_equipment_name text,
  p_equipment_type text,
  p_total_units int,
  p_condition text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_loanout_bank_inventory_r1788(
    equipment_name, equipment_type, total_units, condition, notes, status
  ) VALUES (
    p_equipment_name, p_equipment_type, COALESCE(p_total_units, 1),
    COALESCE(p_condition, 'good'), p_notes,
    CASE WHEN COALESCE(p_total_units, 1) <= 0 THEN 'out_of_stock' ELSE 'available' END
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_loanout_inventory_r1788',
          jsonb_build_object('id', v_id, 'name', p_equipment_name, 'type', p_equipment_type, 'units', p_total_units));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_loanout_inventory_r1788(text, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_loanout_inventory_r1788(text, text, int, text, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_checkouts
-- =====================================================================

DROP FUNCTION IF EXISTS public.list_loanout_checkouts_r1788();
CREATE OR REPLACE FUNCTION public.list_loanout_checkouts_r1788()
RETURNS TABLE (
  id uuid,
  inventory_id uuid,
  equipment_name text,
  equipment_type text,
  engineer_user_id uuid,
  engineer_email text,
  checked_out_at timestamptz,
  expected_return_at timestamptz,
  returned_at timestamptz,
  status text,
  days_out int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.inventory_id, i.equipment_name, i.equipment_type,
         c.engineer_user_id, p.email AS engineer_email,
         c.checked_out_at, c.expected_return_at, c.returned_at, c.status,
         EXTRACT(DAY FROM (COALESCE(c.returned_at, now()) - c.checked_out_at))::int AS days_out
  FROM public.engineer_loanout_checkouts_r1788 c
  JOIN public.engineer_loanout_bank_inventory_r1788 i ON i.id = c.inventory_id
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.checked_out_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loanout_checkouts_r1788() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loanout_checkouts_r1788() TO authenticated;

-- =====================================================================
-- RPC 4: checkout_item
-- =====================================================================

DROP FUNCTION IF EXISTS public.checkout_loanout_item_r1788(uuid, uuid, timestamptz, text);
CREATE OR REPLACE FUNCTION public.checkout_loanout_item_r1788(
  p_inventory_id uuid,
  p_engineer_user_id uuid,
  p_expected_return_at timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_total int;
  v_out int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT total_units, currently_out INTO v_total, v_out
  FROM public.engineer_loanout_bank_inventory_r1788
  WHERE id = p_inventory_id
  FOR UPDATE;

  IF v_total IS NULL THEN RAISE EXCEPTION 'inventory not found'; END IF;
  IF v_out >= v_total THEN RAISE EXCEPTION 'no units available'; END IF;

  INSERT INTO public.engineer_loanout_checkouts_r1788(
    inventory_id, engineer_user_id, expected_return_at, notes
  ) VALUES (
    p_inventory_id, p_engineer_user_id, p_expected_return_at, p_notes
  )
  RETURNING id INTO v_id;

  UPDATE public.engineer_loanout_bank_inventory_r1788
  SET currently_out = currently_out + 1,
      status = CASE
        WHEN (currently_out + 1) >= total_units THEN 'out_of_stock'
        WHEN (currently_out + 1) >= (total_units / 2) THEN 'limited'
        ELSE 'available'
      END,
      updated_at = now()
  WHERE id = p_inventory_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'checkout_loanout_item_r1788',
          jsonb_build_object('checkout_id', v_id, 'inventory_id', p_inventory_id, 'engineer', p_engineer_user_id));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.checkout_loanout_item_r1788(uuid, uuid, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.checkout_loanout_item_r1788(uuid, uuid, timestamptz, text) TO authenticated;

-- =====================================================================
-- RPC 5: return_item
-- =====================================================================

DROP FUNCTION IF EXISTS public.return_loanout_item_r1788(uuid, text);
CREATE OR REPLACE FUNCTION public.return_loanout_item_r1788(
  p_checkout_id uuid,
  p_new_condition text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inv_id uuid;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT inventory_id, status INTO v_inv_id, v_status
  FROM public.engineer_loanout_checkouts_r1788
  WHERE id = p_checkout_id
  FOR UPDATE;

  IF v_inv_id IS NULL THEN RAISE EXCEPTION 'checkout not found'; END IF;
  IF v_status = 'returned' THEN RAISE EXCEPTION 'already returned'; END IF;

  UPDATE public.engineer_loanout_checkouts_r1788
  SET status = 'returned', returned_at = now(), updated_at = now()
  WHERE id = p_checkout_id;

  UPDATE public.engineer_loanout_bank_inventory_r1788
  SET currently_out = GREATEST(currently_out - 1, 0),
      condition = COALESCE(p_new_condition, condition),
      status = CASE
        WHEN GREATEST(currently_out - 1, 0) = 0 THEN 'available'
        WHEN GREATEST(currently_out - 1, 0) >= (total_units / 2) THEN 'limited'
        ELSE 'available'
      END,
      updated_at = now()
  WHERE id = v_inv_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'return_loanout_item_r1788',
          jsonb_build_object('checkout_id', p_checkout_id, 'new_condition', p_new_condition));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.return_loanout_item_r1788(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.return_loanout_item_r1788(uuid, text) TO authenticated;

-- =====================================================================
-- RPC 6: top_borrowed_items
-- =====================================================================

DROP FUNCTION IF EXISTS public.top_borrowed_loanout_items_r1788();
CREATE OR REPLACE FUNCTION public.top_borrowed_loanout_items_r1788()
RETURNS TABLE (
  inventory_id uuid,
  equipment_name text,
  equipment_type text,
  total_checkouts int,
  active_checkouts int,
  overdue_checkouts int,
  total_units int,
  currently_out int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id AS inventory_id,
         i.equipment_name,
         i.equipment_type,
         (COUNT(c.id))::int AS total_checkouts,
         (COUNT(c.id) FILTER (WHERE c.status = 'checked_out'))::int AS active_checkouts,
         (COUNT(c.id) FILTER (WHERE c.status = 'overdue' OR (c.status = 'checked_out' AND c.expected_return_at < now())))::int AS overdue_checkouts,
         i.total_units,
         i.currently_out
  FROM public.engineer_loanout_bank_inventory_r1788 i
  LEFT JOIN public.engineer_loanout_checkouts_r1788 c ON c.inventory_id = i.id
  GROUP BY i.id, i.equipment_name, i.equipment_type, i.total_units, i.currently_out
  ORDER BY total_checkouts DESC, i.equipment_name
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_borrowed_loanout_items_r1788() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_borrowed_loanout_items_r1788() TO authenticated;

-- =====================================================================
-- RPC 7: overdue_checkouts
-- =====================================================================

DROP FUNCTION IF EXISTS public.overdue_loanout_checkouts_r1788();
CREATE OR REPLACE FUNCTION public.overdue_loanout_checkouts_r1788()
RETURNS TABLE (
  id uuid,
  inventory_id uuid,
  equipment_name text,
  engineer_user_id uuid,
  engineer_email text,
  checked_out_at timestamptz,
  expected_return_at timestamptz,
  days_overdue int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.inventory_id, i.equipment_name,
         c.engineer_user_id, p.email AS engineer_email,
         c.checked_out_at, c.expected_return_at,
         EXTRACT(DAY FROM (now() - c.expected_return_at))::int AS days_overdue,
         c.status
  FROM public.engineer_loanout_checkouts_r1788 c
  JOIN public.engineer_loanout_bank_inventory_r1788 i ON i.id = c.inventory_id
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.status IN ('checked_out','overdue','lost')
    AND c.expected_return_at < now()
    AND c.returned_at IS NULL
  ORDER BY c.expected_return_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.overdue_loanout_checkouts_r1788() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_loanout_checkouts_r1788() TO authenticated;

COMMIT;