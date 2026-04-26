-- S2: Multi-address book with optional reverse-geocoded coordinates.
--
-- Replaces the inline single-shot address form on CheckoutScreen with a
-- proper saved-addresses table. Each row captures the postal payload, an
-- optional label ("Home", "Mumbai HQ"), an is_default flag (single-default
-- enforced via partial unique index), and the lat/lng captured at the time
-- of address entry — used later for delivery-zone routing.

CREATE TABLE IF NOT EXISTS public.user_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label text,
  full_name text NOT NULL,
  phone text NOT NULL,
  line1 text NOT NULL,
  line2 text,
  landmark text,
  city text NOT NULL,
  state text NOT NULL,
  pincode text NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  latitude double precision,
  longitude double precision,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_addresses_pincode_check CHECK (char_length(pincode) BETWEEN 4 AND 10),
  CONSTRAINT user_addresses_phone_check CHECK (char_length(phone) BETWEEN 6 AND 20)
);

-- One default per user. Partial unique index lets the rest stay unconstrained.
CREATE UNIQUE INDEX IF NOT EXISTS user_addresses_one_default_per_user
  ON public.user_addresses (user_id) WHERE is_default = true;

CREATE INDEX IF NOT EXISTS user_addresses_user_idx
  ON public.user_addresses (user_id, created_at DESC);

ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_addresses_select_own ON public.user_addresses;
CREATE POLICY user_addresses_select_own
  ON public.user_addresses FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_insert_own ON public.user_addresses;
CREATE POLICY user_addresses_insert_own
  ON public.user_addresses FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_update_own ON public.user_addresses;
CREATE POLICY user_addresses_update_own
  ON public.user_addresses FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_addresses_delete_own ON public.user_addresses;
CREATE POLICY user_addresses_delete_own
  ON public.user_addresses FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Convenience RPC: atomically set one row as default and clear the others.
-- Avoids races between two PATCH requests trying to flip is_default.
CREATE OR REPLACE FUNCTION public.address_set_default(p_address_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid;
BEGIN
  SELECT user_id INTO v_user
  FROM public.user_addresses WHERE id = p_address_id;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'address_not_found' USING ERRCODE='42P01';
  END IF;
  IF v_user <> auth.uid() THEN
    RAISE EXCEPTION 'not_owner' USING ERRCODE='42501';
  END IF;
  UPDATE public.user_addresses SET is_default = false, updated_at = now()
   WHERE user_id = v_user AND is_default = true AND id <> p_address_id;
  UPDATE public.user_addresses SET is_default = true,  updated_at = now()
   WHERE id = p_address_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.address_set_default(uuid) TO authenticated;
