-- Cost-revision lifecycle table. When the engineer arrives on-site
-- and discovers more issues than the original bid covered, they
-- propose a revised quote in-app via propose_cost_revision (next
-- migration). Hospital decides via decide_cost_revision. Approve →
-- repair_jobs.contracted_amount_rupees is overwritten. Reject →
-- engineer can still proceed at the original price OR submit another
-- revision (max 3 per job, enforced in the RPC).
--
-- Status flow:
--   proposed → approved      (hospital tapped Approve)
--   proposed → rejected      (hospital tapped Reject)
--   proposed → expired       (cron after 24h with no decision)
--
-- Partial-unique index enforces "at most one pending revision per
-- job" at the DB level so two engineers / two tabs / replayed RPC
-- can't double-stack proposals; the RPC also checks but defense-
-- in-depth saves us if the RPC is bypassed.
--
-- RLS: SELECT to participants only. INSERT/UPDATE/DELETE blocked at
-- the policy level → the SECURITY DEFINER RPCs are the only writers.

CREATE TYPE public.repair_cost_revision_status AS ENUM (
  'proposed',
  'approved',
  'rejected',
  'expired'
);

CREATE TABLE public.repair_job_cost_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_amount_rupees numeric(10,2) NOT NULL,
  revised_amount_rupees numeric(10,2) NOT NULL,
  reason text NOT NULL,
  status public.repair_cost_revision_status NOT NULL DEFAULT 'proposed',
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decision_by uuid REFERENCES auth.users(id),

  CONSTRAINT cost_revision_revised_gt_original
    CHECK (revised_amount_rupees > original_amount_rupees),
  CONSTRAINT cost_revision_reason_length
    CHECK (char_length(reason) BETWEEN 50 AND 500)
);

CREATE INDEX repair_job_cost_revisions_job_status_idx
  ON public.repair_job_cost_revisions (repair_job_id, status);

CREATE INDEX repair_job_cost_revisions_engineer_idx
  ON public.repair_job_cost_revisions (engineer_user_id, created_at DESC);

CREATE UNIQUE INDEX one_pending_revision_per_job
  ON public.repair_job_cost_revisions (repair_job_id)
  WHERE status = 'proposed';

ALTER TABLE public.repair_job_cost_revisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY repair_job_cost_revisions_select_participant
  ON public.repair_job_cost_revisions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
        FROM public.repair_jobs rj
       WHERE rj.id = repair_job_cost_revisions.repair_job_id
         AND (
           rj.hospital_user_id = auth.uid()
           OR repair_job_cost_revisions.engineer_user_id = auth.uid()
         )
    )
  );

-- INSERT/UPDATE/DELETE: no policy → only SECURITY DEFINER RPCs (which
-- bypass RLS as table owner) may write. Mirrors the
-- virtual_call_sessions / payments table patterns from earlier
-- security passes.

REVOKE ALL ON public.repair_job_cost_revisions FROM anon;
GRANT SELECT ON public.repair_job_cost_revisions TO authenticated;

ALTER TABLE public.repair_job_cost_revisions OWNER TO postgres;
