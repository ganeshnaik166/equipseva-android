-- PAN number column on engineers. The doc itself piggy-backs on the existing
-- certificates jsonb (type='pan') so no separate path column is needed.
-- Optional — not every engineer registers a PAN at first onboarding, but
-- KYC stepper requires it before submit.

ALTER TABLE public.engineers
    ADD COLUMN IF NOT EXISTS pan_number text;
