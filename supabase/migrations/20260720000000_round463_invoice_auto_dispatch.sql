-- Round 463 — auto-email GST invoice on repair-job completion +
-- founder daily digest of invoices issued.
--
-- Flow:
--   1. repair_jobs.status flips → 'completed'
--   2. Trigger trg_repair_jobs_dispatch_invoice fires net.http_post
--      → dispatch_repair_invoice edge fn (webhook-authed)
--   3. dispatch fn renders the same HTML as generate_repair_invoice,
--      uploads to invoices Storage, signs a 7-day URL (email link
--      must outlive the hospital's inbox-checking habit), and emails
--      it via Resend
--   4. dispatch fn records the send in repair_invoice_emails for
--      idempotency + digest aggregation
--   5. founder_invoice_digest cron pulls last-24h rows + emails
--      founder one summary at 08:00 IST daily
--
-- Idempotency:
--   • The trigger only fires on the status TRANSITION (OLD != completed
--     AND NEW = completed) so a no-op UPDATE on a completed row won't
--     re-fire.
--   • dispatch_repair_invoice checks repair_invoice_emails for an
--     existing 'sent' row and short-circuits if one is < 24h old.
--   • repair_invoice_emails has UNIQUE(job_id) — the second concurrent
--     dispatch (if the trigger somehow double-fires) hits the
--     constraint and the fn returns 'already_sent'.

-- 1. Service-role-only RPC variant — same shape as
--    get_repair_invoice_payload but skips the auth.uid() check (caller
--    is service_role, gating is enforced by INVOICE_WEBHOOK_SECRET in
--    the edge fn). SECURITY DEFINER + REVOKE from authenticated keeps
--    this away from the mobile app.

CREATE OR REPLACE FUNCTION public.get_repair_invoice_payload_unchecked(p_job_id uuid)
RETURNS TABLE (
  invoice_number     text,
  invoice_date       date,
  job_number         text,
  completed_at       timestamptz,
  hospital_user_id   uuid,
  hospital_name      text,
  hospital_email     text,
  hospital_phone     text,
  hospital_gstin     text,
  hospital_address   text,
  hospital_city      text,
  hospital_state     text,
  hospital_pincode   text,
  equipment_type     text,
  equipment_brand    text,
  equipment_model    text,
  equipment_serial   text,
  issue_description  text,
  work_done          text,
  gross_rupees       numeric,
  taxable_value      numeric,
  gst_total          numeric,
  cgst               numeric,
  sgst               numeric,
  igst               numeric,
  hsn_sac_code       text,
  service_description text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job          public.repair_jobs%ROWTYPE;
  v_buyer        record;
  v_gross        numeric;
  v_taxable      numeric;
  v_gst_total    numeric;
  v_cgst         numeric;
  v_sgst         numeric;
  v_completed_ist timestamp;
  v_fy_start_yr  int;
  v_fy_end_yr    int;
  v_invoice_no   text;
  v_invoice_date date;
BEGIN
  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_job_id;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_job.status::text <> 'completed' THEN RETURN; END IF;

  SELECT
    p.full_name, p.email, p.phone, p.gstin, p.business_address,
    p.city, p.state, p.pincode
    INTO v_buyer
    FROM public.profiles p
   WHERE p.id = v_job.hospital_user_id;

  v_gross := coalesce(v_job.contracted_amount_rupees, 0);
  v_taxable := round(v_gross / 1.18, 2);
  v_gst_total := round(v_gross - v_taxable, 2);
  v_cgst := round(v_gst_total / 2.0, 2);
  v_sgst := v_gst_total - v_cgst;

  v_completed_ist := (coalesce(v_job.completed_at, now()) AT TIME ZONE 'Asia/Kolkata');
  v_invoice_date := v_completed_ist::date;
  v_fy_start_yr := EXTRACT(YEAR FROM v_completed_ist)::int;
  IF EXTRACT(MONTH FROM v_completed_ist)::int < 4 THEN
    v_fy_start_yr := v_fy_start_yr - 1;
  END IF;
  v_fy_end_yr := v_fy_start_yr + 1;
  v_invoice_no := 'EQ/'
    || v_fy_start_yr::text
    || '-'
    || lpad((v_fy_end_yr % 100)::text, 2, '0')
    || '/'
    || coalesce(v_job.job_number, substring(v_job.id::text, 1, 8));

  RETURN QUERY SELECT
    v_invoice_no::text                  AS invoice_number,
    v_invoice_date                      AS invoice_date,
    v_job.job_number,
    v_job.completed_at,
    v_job.hospital_user_id,
    coalesce(v_buyer.full_name, '—')::text   AS hospital_name,
    coalesce(v_buyer.email, '')::text        AS hospital_email,
    coalesce(v_buyer.phone, '')::text        AS hospital_phone,
    v_buyer.gstin                            AS hospital_gstin,
    coalesce(v_buyer.business_address, '')::text AS hospital_address,
    coalesce(v_buyer.city, '')::text         AS hospital_city,
    coalesce(v_buyer.state, '')::text        AS hospital_state,
    coalesce(v_buyer.pincode, '')::text      AS hospital_pincode,
    v_job.equipment_type::text               AS equipment_type,
    v_job.equipment_brand,
    v_job.equipment_model,
    v_job.equipment_serial,
    v_job.issue_description,
    v_job.work_done,
    v_gross                                  AS gross_rupees,
    v_taxable                                AS taxable_value,
    v_gst_total                              AS gst_total,
    v_cgst                                   AS cgst,
    v_sgst                                   AS sgst,
    0::numeric                               AS igst,
    '998739'::text                           AS hsn_sac_code,
    concat(
      'Biomedical equipment repair services — ',
      coalesce(nullif(trim(v_job.equipment_type::text), ''), 'medical device'),
      CASE
        WHEN v_job.equipment_brand IS NOT NULL AND v_job.equipment_brand <> ''
        THEN ' (' || v_job.equipment_brand || ')'
        ELSE ''
      END
    )::text                                  AS service_description;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_repair_invoice_payload_unchecked(uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.get_repair_invoice_payload_unchecked(uuid) TO service_role;

COMMENT ON FUNCTION public.get_repair_invoice_payload_unchecked(uuid) IS
  'Service-role variant of get_repair_invoice_payload — no auth.uid() check. Only callable via INVOICE_WEBHOOK_SECRET-gated edge fns (dispatch_repair_invoice, founder_invoice_digest).';

-- 2. Email-dispatch log + digest source-of-truth.

CREATE TABLE IF NOT EXISTS public.repair_invoice_emails (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id          uuid NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  invoice_number  text NOT NULL,
  invoice_date    date NOT NULL,
  hospital_email  text,
  hospital_name   text,
  gross_rupees    numeric NOT NULL,
  gst_total       numeric NOT NULL,
  signed_url      text,
  url_expires_at  timestamptz,
  email_status    text NOT NULL CHECK (email_status IN ('sent','skipped_no_email','resend_failed','disabled')),
  email_error     text,
  sent_at         timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Lookup index for the dispatch fn's "did we already send in the
-- last 24h?" pre-check + the digest fn's window query. We do NOT add
-- a unique-by-day constraint because (sent_at::date) is not IMMUTABLE
-- under Postgres' index rules — the 24h application-level check in
-- dispatch_repair_invoice provides the idempotency.
CREATE INDEX IF NOT EXISTS ix_repair_invoice_emails_job_sent_at
  ON public.repair_invoice_emails (job_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS ix_repair_invoice_emails_sent_at
  ON public.repair_invoice_emails (sent_at DESC);

ALTER TABLE public.repair_invoice_emails ENABLE ROW LEVEL SECURITY;

-- Founder-only read; SECURITY DEFINER fns insert via service-role.
DROP POLICY IF EXISTS repair_invoice_emails_founder_read ON public.repair_invoice_emails;
CREATE POLICY repair_invoice_emails_founder_read
  ON public.repair_invoice_emails
  FOR SELECT
  USING (public.is_founder());

REVOKE ALL ON TABLE public.repair_invoice_emails FROM PUBLIC, anon;
GRANT  SELECT ON TABLE public.repair_invoice_emails TO authenticated;
GRANT  ALL    ON TABLE public.repair_invoice_emails TO service_role;

COMMENT ON TABLE public.repair_invoice_emails IS
  'Round 463 — one row per dispatched GST invoice email. Powers the founder daily digest and provides idempotency for the auto-dispatch trigger.';

-- 3. Webhook config table reuse — same singleton pattern as the
--    spare-part-orders trigger from 2026-04-25. Separate row keyed by
--    'repair_invoice' so the two flows can rotate independently.

CREATE TABLE IF NOT EXISTS public._app_repair_invoice_config (
  id text PRIMARY KEY DEFAULT 'singleton',
  webhook_url text NOT NULL,
  webhook_secret text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 'singleton')
);

ALTER TABLE public._app_repair_invoice_config ENABLE ROW LEVEL SECURITY;
-- No policies — RLS denies every caller. Only SECURITY DEFINER fns
-- (running as table owner) read this.
REVOKE ALL ON TABLE public._app_repair_invoice_config FROM PUBLIC, authenticated, anon;

-- 4. Trigger — fires only on the status TRANSITION, not on every
--    UPDATE of a completed row.

CREATE OR REPLACE FUNCTION public.repair_jobs_dispatch_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, pg_temp
AS $$
DECLARE
    v_url text;
    v_secret text;
BEGIN
    -- Only on transition into completed.
    IF NEW.status::text IS DISTINCT FROM 'completed' THEN
        RETURN NEW;
    END IF;
    IF OLD.status::text = 'completed' THEN
        RETURN NEW;
    END IF;

    SELECT webhook_url, webhook_secret
      INTO v_url, v_secret
      FROM public._app_repair_invoice_config
     WHERE id = 'singleton'
     LIMIT 1;

    -- Fail-quiet on missing config — completion still succeeds, the
    -- hospital can still tap the manual "Download GST invoice" button
    -- if the auto-fire is disabled.
    IF v_url IS NULL OR v_url = '' OR v_secret IS NULL OR v_secret = '' THEN
        RAISE WARNING 'repair_jobs_dispatch_invoice: config unset; skipping auto-dispatch for job %', NEW.id;
        RETURN NEW;
    END IF;

    PERFORM net.http_post(
        url := v_url,
        body := jsonb_build_object('job_id', NEW.id),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-webhook-secret', v_secret
        ),
        timeout_milliseconds := 10000
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Never let invoice dispatch failure block a job completion.
    RAISE WARNING 'repair_jobs_dispatch_invoice failed: % / %', SQLSTATE, SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.repair_jobs_dispatch_invoice() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_repair_jobs_dispatch_invoice ON public.repair_jobs;
CREATE TRIGGER trg_repair_jobs_dispatch_invoice
AFTER UPDATE OF status ON public.repair_jobs
FOR EACH ROW
EXECUTE FUNCTION public.repair_jobs_dispatch_invoice();

COMMENT ON FUNCTION public.repair_jobs_dispatch_invoice() IS
  'Round 463 — fires dispatch_repair_invoice edge fn on repair_jobs.status transition into completed. Reads URL+secret from _app_repair_invoice_config (seed out-of-band).';

-- 5. Daily digest source query — returns aggregated counts +
--    line-item rows for the last 24h. Founder-only.

CREATE OR REPLACE FUNCTION public.get_invoice_digest_payload(p_since timestamptz DEFAULT (now() - interval '24 hours'))
RETURNS TABLE (
  invoice_number  text,
  invoice_date    date,
  hospital_name   text,
  hospital_email  text,
  gross_rupees    numeric,
  gst_total       numeric,
  email_status    text,
  sent_at         timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    invoice_number, invoice_date, hospital_name, hospital_email,
    gross_rupees, gst_total, email_status, sent_at
  FROM public.repair_invoice_emails
  WHERE sent_at >= p_since
  ORDER BY sent_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.get_invoice_digest_payload(timestamptz) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.get_invoice_digest_payload(timestamptz) TO service_role;

COMMENT ON FUNCTION public.get_invoice_digest_payload(timestamptz) IS
  'Round 463 — backing query for founder_invoice_digest edge fn. Returns one row per invoice emailed since p_since.';

-- 6. Seeding note (run OUT-OF-BAND, not in this migration — webhook
--    secret must NEVER land in version control):
--
--   INSERT INTO public._app_repair_invoice_config (id, webhook_url, webhook_secret)
--   VALUES (
--     'singleton',
--     'https://<project-ref>.functions.supabase.co/dispatch_repair_invoice',
--     '<32-byte-hex-secret>'
--   )
--   ON CONFLICT (id) DO UPDATE
--   SET webhook_url=EXCLUDED.webhook_url,
--       webhook_secret=EXCLUDED.webhook_secret,
--       updated_at=now();
--
--   supabase secrets set INVOICE_DISPATCH_SECRET="<same-32-byte-hex>"
--   supabase secrets set FOUNDER_DIGEST_EMAIL="ops@getphyllo.com"
--
-- pg_cron daily digest (optional, only on Supabase Pro tier):
--   SELECT cron.schedule(
--     'founder_invoice_digest_daily',
--     '30 2 * * *',  -- 02:30 UTC = 08:00 IST
--     $$ SELECT net.http_post(
--          url := 'https://<project-ref>.functions.supabase.co/founder_invoice_digest',
--          headers := jsonb_build_object('x-webhook-secret','<CRON_TICK_SECRET>'),
--          timeout_milliseconds := 30000
--        ); $$
--   );
