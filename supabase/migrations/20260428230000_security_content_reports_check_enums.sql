-- ContentReport.kt comments claim "Matches the CHECK constraint on
-- content_reports.target_type / .reason" but the table currently has
-- no constraints. Reporters can submit arbitrary text in target_type,
-- reason, status, notes — admin reviews catch misuse downstream, but
-- nothing stops a script from spamming the table with junk rows.
-- Lock down to the documented enums and cap the free-text fields.
--
-- The table is empty today, so the constraints land safely.

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_target_type_chk
    CHECK (target_type IN ('chat_message','part_listing','repair_job','rfq','profile'));

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_reason_chk
    CHECK (reason IN ('spam','scam','abuse','harassment','inappropriate','illegal','other'));

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_status_chk
    CHECK (status IN ('pending','reviewed','dismissed','actioned'));

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_notes_length_chk
    CHECK (notes IS NULL OR length(notes) <= 4000);

ALTER TABLE public.content_reports
  ADD CONSTRAINT content_reports_target_id_length_chk
    CHECK (length(target_id) BETWEEN 1 AND 64);
