-- Round 297 — cap repair_job_bids.note length server-side.
--
-- The engineer's "Submit bid" composer in RepairJobDetailScreen
-- clamps the optional note TextField at 500 chars (NOTE_MAX_LEN).
-- But repair_job_bids.note is `text` with no length bound; a non-UI
-- caller (Postman, scripts, future bulk import) can persist a
-- multi-MB blob. The hospital's bid-card render then either renders
-- the wall of text or silently truncates client-side — and the
-- bids list query pulls the full column on every fetch.
--
-- Bound at 1000 chars: 2× the UI clamp for headroom on legacy /
-- queued offline bids, while still tight enough that a single bid
-- card stays under a screen-height in the hospital's bid review.
--
-- Same row-boundary capping pattern as rounds 268 / 276 / 281 /
-- 283 / 284 / 286 / 289 / 290 / 295.

ALTER TABLE public.repair_job_bids
  DROP CONSTRAINT IF EXISTS repair_job_bids_note_length_chk;

ALTER TABLE public.repair_job_bids
  ADD CONSTRAINT repair_job_bids_note_length_chk
    CHECK (note IS NULL OR char_length(note) <= 1000);
