-- Per-doc KYC rejection: admin can reject individual doc types (aadhaar /
-- selfie / cert) instead of failing the whole submission. Engineer sees only
-- the rejected docs flagged red on re-open and re-uploads just those.
--
-- Two new columns on engineers:
--   verification_notes  text       — free-text reason shown to engineer
--   rejected_doc_types  text[]     — subset of {'aadhaar','selfie','cert'}
--                                    that admin flagged. Empty / NULL means
--                                    everything is fine (or full-submission
--                                    rejection where notes covers it).
--
-- The existing RPC already wrote to verification_notes but the column never
-- existed (silent failure). This migration adds the column AND extends the
-- RPC signature to take p_rejected_doc_types.

ALTER TABLE public.engineers
    ADD COLUMN IF NOT EXISTS verification_notes text,
    ADD COLUMN IF NOT EXISTS rejected_doc_types text[];

DROP FUNCTION IF EXISTS public.admin_set_engineer_verification(uuid, text, text);

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
BEGIN
    IF NOT public.is_founder() THEN
        RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
    END IF;
    IF p_status NOT IN ('pending','verified','rejected') THEN
        RAISE EXCEPTION 'invalid_status' USING ERRCODE='22023';
    END IF;
    -- Validate every rejected doc type up-front so admin can't smuggle a
    -- typo into the column. Only the three current KYC doc kinds are valid.
    IF p_rejected_doc_types IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM unnest(p_rejected_doc_types) t
            WHERE t NOT IN ('aadhaar','selfie','cert')
        ) THEN
            RAISE EXCEPTION 'invalid_doc_type' USING ERRCODE='22023';
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
