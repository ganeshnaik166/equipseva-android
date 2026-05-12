-- PR #551 added a docs gate to admin_set_engineer_verification: refuse
-- 'verified' unless aadhaar_verified=true AND certificates is non-empty.
-- Self-review surfaced a forward-compat gap: engineers verified BEFORE
-- aadhaar_verified existed as a column (or before certificates was
-- populated) sit on verification_status='verified' with NULL/empty
-- KYC markers. The gate currently refuses to re-stamp those rows
-- (e.g. an admin trying to fix a typo in verification_notes via a
-- second call), deadlocking maintenance.
--
-- Make the gate idempotent: it only fires when the status is changing
-- TO 'verified' from something other than 'verified'. Re-affirming an
-- already-verified row no longer triggers the docs check.

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
    v_current_status text;
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

    -- Pull row once. Decision: only enforce the docs gate on an actual
    -- promotion (pending/rejected/NULL -> verified). Re-stamping a row
    -- that is already 'verified' is safe to allow because the engineer
    -- got vetted previously; otherwise we'd lock out routine admin
    -- maintenance on legacy rows where aadhaar_verified is NULL.
    SELECT coalesce(verification_status::text, 'pending'),
           coalesce(aadhaar_verified, false),
           coalesce(jsonb_array_length(certificates), 0)
      INTO v_current_status, v_aadhaar_verified, v_cert_count
      FROM public.engineers
     WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'engineer_not_found' USING ERRCODE='02000';
    END IF;

    IF p_status = 'verified' AND v_current_status <> 'verified' THEN
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
