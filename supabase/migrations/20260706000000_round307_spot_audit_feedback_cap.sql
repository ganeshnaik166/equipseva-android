-- Round 307 — text-cap row boundary cordon for two more free-form fields.
--
-- spot_audit_responses.feedback was text (unbounded) — client clamps at 500
-- in HomeHubScreen.kt, but any direct API call via service-role / sql editor
-- could persist arbitrary-length blobs. Cap at 500 matching the UI clamp.
--
-- amc_admin_escalations.notes is admin-only (created via service-role from
-- triggers). Defensive cap at 1000 — closes the surface even when an admin
-- panel is wired up later.
--
-- Same row-boundary cordon pattern as rounds 281, 283, 284, 286, 289, etc.

ALTER TABLE public.spot_audit_responses
  ADD CONSTRAINT spot_audit_responses_feedback_length_check
    CHECK (feedback IS NULL OR char_length(feedback) <= 500);

ALTER TABLE public.amc_admin_escalations
  ADD CONSTRAINT amc_admin_escalations_notes_length_check
    CHECK (notes IS NULL OR char_length(notes) <= 1000);
