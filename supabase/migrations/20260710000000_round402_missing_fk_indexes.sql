-- Round 402 — two missing FK indexes confirmed after scout audit.
--
-- Scout flagged 9 FK columns lacking covering indexes. Manual verification
-- found 7 were false positives — already covered by round 308 (FK indexes
-- pass) or earlier composite indexes that lead with the FK column. The
-- remaining 2 are genuine gaps:
--
-- 1. spot_audit_invitations.engineer_id (FK to engineers, ON DELETE SET NULL)
--    — only spot_audit_invitations_lookup_idx exists, keyed on
--    (hospital_user_id, expires_at). DELETE on engineers row triggers a
--    SET NULL on every invitation row via seq scan.
--
-- 2. amc_engineer_rotation.engineer_id (FK to engineers, ON DELETE RESTRICT)
--    — only amc_engineer_rotation_lookup_idx exists, keyed on
--    (amc_contract_id, priority) WHERE active = true. DELETE on engineers
--    row triggers a RESTRICT check via seq scan.
--
-- Cheap one-column indexes (low write churn on either table at v1
-- volume) but pays off at the moment an engineer is removed.

CREATE INDEX IF NOT EXISTS idx_spot_audit_invitations_engineer_id
  ON public.spot_audit_invitations (engineer_id)
  WHERE engineer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_amc_engineer_rotation_engineer_id
  ON public.amc_engineer_rotation (engineer_id);
