-- Round 233 finding: a founder could call admin_set_engineer_verification with
-- p_status='verified' on an engineer row that had no KYC docs uploaded, and
-- the engineer would then surface in the public directory at full visibility.
-- The buyer-facing engineers_directory_search filters only on verification_status,
-- so an empty-cert "verified" engineer is indistinguishable from a real one.
--
-- Tighten the admin RPC: refuse to flip a row to 'verified' unless the
-- engineer has at least submitted Aadhaar (aadhaar_verified=true) AND has at
-- least one entry in the certificates JSONB. Admin can still mark rejected or
-- reset to pending without the docs constraint.

CREATE OR REPLACE FUNCTION public.admin_set_engineer_verification(
    p_user_id uuid,
    p_status text,
    p_reason text DEFAULT NULL,
    p_rejected_doc_types text[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_aadhaar_verified boolean;
    v_cert_count int;
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
    END IF;
    IF p_status NOT IN ('pending','verified','rejected') THEN
        RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
    END IF;
    IF p_rejected_doc_types IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM unnest(p_rejected_doc_types) t
            WHERE t NOT IN ('aadhaar','selfie','cert')
        ) THEN
            RAISE EXCEPTION 'invalid_doc_type' USING ERRCODE='22023';
        END IF;
    END IF;

    -- Gate: 'verified' requires both Aadhaar marker and at least one cert
    -- entry. Pulled once per call rather than as a subquery in the UPDATE so
    -- the error message is precise.
    IF p_status = 'verified' THEN
        SELECT coalesce(aadhaar_verified, false), coalesce(jsonb_array_length(certificates), 0)
          INTO v_aadhaar_verified, v_cert_count
          FROM public.engineers
         WHERE user_id = p_user_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'engineer_not_found' USING ERRCODE='02000';
        END IF;
        IF NOT v_aadhaar_verified OR v_cert_count = 0 THEN
            RAISE EXCEPTION 'kyc_incomplete' USING ERRCODE='22023';
        END IF;
    END IF;

    UPDATE public.engineers
    SET verification_status = p_status::verification_status,
        verification_notes  = CASE WHEN p_status='rejected' THEN p_reason ELSE NULL END,
        rejected_doc_types  = CASE
            WHEN p_status='rejected' THEN coalesce(p_rejected_doc_types, ARRAY[]::text[])
            ELSE NULL
        END
    WHERE user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_engineer_verification(uuid, text, text, text[]) TO authenticated;
