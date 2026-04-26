-- S1: Buyer KYC gate at checkout.
--
-- Every paying account must upload one of six trade docs before the first
-- successful Razorpay flow. Once verified, the status is permanent. This
-- migration ships the table, RLS, the founder admin RPCs, and a denormalised
-- `profiles.buyer_kyc_status` column kept in sync via trigger so the
-- CheckoutViewModel can gate without an extra round-trip.

CREATE TABLE IF NOT EXISTS public.buyer_kyc_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doc_type text NOT NULL,
  doc_url text NOT NULL,
  gst_number text,
  status text NOT NULL DEFAULT 'pending',
  rejection_reason text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT buyer_kyc_doc_type_check CHECK (
    doc_type IN ('shop_registration','gst','drug_license','mci','dci','medical_id')
  ),
  CONSTRAINT buyer_kyc_status_check CHECK (
    status IN ('pending','verified','rejected')
  ),
  CONSTRAINT buyer_kyc_gst_required CHECK (
    doc_type <> 'gst' OR (gst_number IS NOT NULL AND char_length(gst_number) BETWEEN 10 AND 20)
  )
);

CREATE INDEX IF NOT EXISTS buyer_kyc_user_idx
  ON public.buyer_kyc_verifications (user_id, submitted_at DESC);

CREATE INDEX IF NOT EXISTS buyer_kyc_pending_idx
  ON public.buyer_kyc_verifications (submitted_at DESC) WHERE status = 'pending';

ALTER TABLE public.buyer_kyc_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS buyer_kyc_select_own ON public.buyer_kyc_verifications;
CREATE POLICY buyer_kyc_select_own
  ON public.buyer_kyc_verifications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS buyer_kyc_insert_own ON public.buyer_kyc_verifications;
CREATE POLICY buyer_kyc_insert_own
  ON public.buyer_kyc_verifications FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- No client UPDATE/DELETE — only founders mutate via the admin RPC below.

-- Denormalised buyer_kyc_status on profiles. Default 'unsubmitted' so the
-- CheckoutViewModel doesn't need a NULL-vs-string branch. Updated by trigger
-- on the verifications table.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS buyer_kyc_status text NOT NULL DEFAULT 'unsubmitted';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_buyer_kyc_status_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_buyer_kyc_status_check CHECK (
    buyer_kyc_status IN ('unsubmitted','pending','verified','rejected')
  );

-- Trigger: any insert / status update on the verifications table refreshes
-- profiles.buyer_kyc_status to the latest row's status for that user.
CREATE OR REPLACE FUNCTION public._sync_buyer_kyc_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status
    FROM public.buyer_kyc_verifications
   WHERE user_id = NEW.user_id
   ORDER BY
     CASE status WHEN 'verified' THEN 0 WHEN 'pending' THEN 1 WHEN 'rejected' THEN 2 ELSE 3 END,
     submitted_at DESC
   LIMIT 1;
  IF v_status IS NULL THEN v_status := 'unsubmitted'; END IF;
  UPDATE public.profiles SET buyer_kyc_status = v_status, updated_at = now()
   WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_buyer_kyc ON public.buyer_kyc_verifications;
CREATE TRIGGER trg_sync_buyer_kyc
  AFTER INSERT OR UPDATE OF status ON public.buyer_kyc_verifications
  FOR EACH ROW EXECUTE FUNCTION public._sync_buyer_kyc_status();

-- Founder admin RPCs. Mirrors the engineer KYC pattern.

CREATE OR REPLACE FUNCTION public.admin_pending_buyer_kyc()
RETURNS TABLE (
  request_id uuid,
  user_id uuid,
  full_name text,
  email text,
  phone text,
  doc_type text,
  doc_url text,
  gst_number text,
  status text,
  submitted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
    SELECT b.id, b.user_id,
           coalesce(p.full_name, '(unnamed)'),
           p.email, p.phone,
           b.doc_type, b.doc_url, b.gst_number,
           b.status, b.submitted_at
      FROM public.buyer_kyc_verifications b
      LEFT JOIN public.profiles p ON p.id = b.user_id
     WHERE b.status = 'pending'
     ORDER BY b.submitted_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_pending_buyer_kyc() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_buyer_kyc_status(
  p_request_id uuid,
  p_status text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  IF p_status NOT IN ('verified','rejected') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
  END IF;
  UPDATE public.buyer_kyc_verifications
     SET status         = p_status,
         rejection_reason = CASE WHEN p_status = 'rejected' THEN p_reason ELSE NULL END,
         reviewed_at    = now(),
         reviewed_by    = auth.uid()
   WHERE id = p_request_id
     AND status = 'pending';
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_buyer_kyc_status(uuid, text, text) TO authenticated;
