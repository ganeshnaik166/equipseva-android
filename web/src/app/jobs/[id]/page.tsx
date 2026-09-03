import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Job detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Job = {
  id: string;
  job_number?: string | null;
  hospital_user_id: string;
  status: string;
  urgency?: string | null;
  equipment_type?: string | null;
  brand?: string | null;
  model?: string | null;
  serial?: string | null;
  issue?: string | null;
  estimated_cost_rupees?: number | null;
  contracted_amount_rupees?: number | null;
  site_address?: string | null;
  scheduled_date?: string | null;
  created_at: string;
  completed_at?: string | null;
  withdrawn_at?: string | null;
  cancelled_at?: string | null;
};

type Bid = {
  id: string;
  engineer_user_id: string;
  amount_rupees: number | null;
  eta_hours: number | null;
  note: string | null;
  status: string;
  responded_at: string | null;
  created_at: string;
};

type Escrow = {
  id: string;
  amount_rupees: number | null;
  status: string;
  funded_at: string | null;
  released_at: string | null;
  disputed_at: string | null;
};

type DsrRow = {
  id: string;
  status: string | null;
  engineer_signature_at: string | null;
  hospital_signature_at: string | null;
  iec_62353_passed: boolean | null;
  calibration_within_oem: boolean | null;
};

type AuditRow = {
  id: string;
  op_name: string;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

type CostRevision = {
  id: string;
  original_amount_rupees: number | null;
  revised_amount_rupees: number | null;
  reason: string | null;
  status: string;
  created_at: string;
  decided_at: string | null;
};

export default async function JobDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  // We do best-effort selects with COALESCE fallback — different
  // migration generations have added different columns. Project a
  // generous SELECT and let unknown columns surface as null.
  const [jobRes, bidsRes, escrowRes, dsrRes, auditRes, costRevisionsRes] = await Promise.all([
    supabase
      .from("repair_jobs")
      .select(
        "id, job_number, hospital_user_id, status, urgency, equipment_type, brand, model, serial, issue, estimated_cost_rupees, contracted_amount_rupees, site_address, scheduled_date, created_at, completed_at, withdrawn_at, cancelled_at",
      )
      .eq("id", id)
      .maybeSingle(),
    supabase
      .from("repair_job_bids")
      .select(
        "id, engineer_user_id, amount_rupees, eta_hours, note, status, responded_at, created_at",
      )
      .eq("repair_job_id", id)
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("repair_job_escrow")
      .select("id, amount_rupees, status, funded_at, released_at, disputed_at")
      .eq("repair_job_id", id)
      .maybeSingle(),
    supabase
      .from("dsr_reports")
      .select(
        "id, status, engineer_signature_at, hospital_signature_at, iec_62353_passed, calibration_within_oem",
      )
      .eq("repair_job_id", id)
      .maybeSingle(),
    supabase
      .from("founder_action_log")
      .select("id, op_name, outcome, reason, created_at")
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(30),
    supabase
      .from("repair_job_cost_revisions")
      .select("id, original_amount_rupees, revised_amount_rupees, reason, status, created_at, decided_at")
      .eq("repair_job_id", id)
      .order("created_at", { ascending: false })
      .limit(20),
  ]);

  const job = (jobRes.error ? null : (jobRes.data as Job | null)) ?? null;
  if (!job) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Job not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          No row in <code>repair_jobs</code> matches <code>{id}</code>. Could be a stale
          link or beyond the row-level visibility window. RLS gates founders too;
          confirm <code>is_founder()</code> is true for your session.
        </p>
        <Link
          href="/disputes"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to disputes
        </Link>
      </div>
    );
  }

  const bids = (bidsRes.error ? [] : (bidsRes.data ?? [])) as Bid[];
  const escrow = (escrowRes.error ? null : (escrowRes.data as Escrow | null)) ?? null;
  const dsr = (dsrRes.error ? null : (dsrRes.data as DsrRow | null)) ?? null;
  const audit = (auditRes.error ? [] : (auditRes.data ?? [])) as AuditRow[];
  const costRevisions = (costRevisionsRes.error ? [] : (costRevisionsRes.data ?? [])) as CostRevision[];

  const acceptedBid = bids.find((b) => b.status === "accepted") ?? null;
  const amountAcceptedFor =
    acceptedBid?.amount_rupees ?? job.contracted_amount_rupees ?? null;
  // Round 3766 follow-up: contracted_amount_rupees is the authoritative,
  // revision-inclusive figure (accept_repair_bid sets it at accept-time;
  // decide_cost_revision keeps it current on every approved revision —
  // see round3764). "Accepted bid" above is deliberately the FROZEN
  // original bid amount for the record; this is the one to trust for
  // "what does the hospital actually owe / what will the engineer be
  // paid right now". They differ exactly when a revision was approved —
  // the Cost revisions table below explains why.
  const contractedAmount = job.contracted_amount_rupees ?? null;
  const hasApprovedRevision = costRevisions.some((r) => r.status === "approved");

  const statusTone =
    job.status === "completed"
      ? "ok"
      : job.status === "cancelled" || job.status === "withdrawn"
        ? "neutral"
        : "warn";

  const bidCols: Column<Bid>[] = [
    {
      key: "when",
      header: "Submitted",
      render: (b) => <span title={b.created_at}>{formatRelativeTime(b.created_at)}</span>,
    },
    {
      key: "engineer",
      header: "Engineer",
      render: (b) => (
        <Link
          href={`/engineers/${b.engineer_user_id}`}
          className="text-[var(--color-accent)] hover:underline"
        >
          {shortId(b.engineer_user_id)}
        </Link>
      ),
    },
    { key: "amount", header: "Bid", render: (b) => formatRupees(b.amount_rupees) },
    {
      key: "eta",
      header: "ETA",
      render: (b) => (b.eta_hours != null ? `${b.eta_hours}h` : "—"),
    },
    {
      key: "status",
      header: "Status",
      render: (b) => {
        const cls =
          b.status === "accepted"
            ? "bg-green-100 text-[var(--color-ok)]"
            : b.status === "rejected" || b.status === "withdrawn"
              ? "bg-gray-100"
              : "bg-yellow-100 text-[var(--color-warn)]";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{b.status}</span>;
      },
    },
    {
      key: "note",
      header: "Note",
      render: (b) => <span className="text-xs">{b.note ?? "—"}</span>,
    },
  ];

  const costRevisionCols: Column<CostRevision>[] = [
    { key: "when", header: "Proposed", render: (r) => formatRelativeTime(r.created_at) },
    { key: "original", header: "Original", render: (r) => formatRupees(r.original_amount_rupees) },
    { key: "revised", header: "Revised", render: (r) => formatRupees(r.revised_amount_rupees) },
    {
      key: "delta",
      header: "Delta",
      render: (r) => {
        const o = r.original_amount_rupees;
        const v = r.revised_amount_rupees;
        if (o == null || v == null) return "—";
        const delta = v - o;
        return (
          <span className={delta > 0 ? "text-red-700" : "text-emerald-700"}>
            {delta > 0 ? "+" : ""}
            {formatRupees(delta)}
          </span>
        );
      },
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const cls =
          r.status === "approved"
            ? "bg-green-100 text-[var(--color-ok)]"
            : r.status === "rejected"
              ? "bg-gray-100"
              : "bg-yellow-100 text-[var(--color-warn)]";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status}</span>;
      },
    },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
    {
      key: "decided",
      header: "Decided",
      render: (r) => <span className="text-xs">{formatRelativeTime(r.decided_at)}</span>,
    },
  ];

  const auditCols: Column<AuditRow>[] = [
    { key: "when", header: "When", render: (r) => formatRelativeTime(r.created_at) },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    { key: "outcome", header: "Outcome", render: (r) => r.outcome ?? "—" },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
  ];

  return (
    <div className="space-y-6">
      <header>
        <Link
          href="/disputes"
          className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
        >
          ← jobs
        </Link>
        <h1 className="mt-1 text-xl font-semibold">
          Job {job.job_number ?? shortId(job.id)}
        </h1>
        <p className="text-xs text-[var(--color-muted)]">
          job_id <code>{job.id}</code> ·{" "}
          <span
            className={`rounded px-1.5 py-0.5 text-xs ${
              statusTone === "ok"
                ? "bg-green-100 text-[var(--color-ok)]"
                : statusTone === "warn"
                  ? "bg-yellow-100 text-[var(--color-warn)]"
                  : "bg-gray-100"
            }`}
          >
            {job.status}
          </span>
          {job.urgency && (
            <span className="ml-2 rounded bg-gray-100 px-1.5 py-0.5 text-xs">
              {job.urgency}
            </span>
          )}
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Equipment"
            value={job.equipment_type ?? "—"}
            subtext={
              [job.brand, job.model].filter(Boolean).join(" ") || undefined
            }
          />
          <StatCard
            label="Hospital"
            value={shortId(job.hospital_user_id)}
            href={`/hospitals/${job.hospital_user_id}`}
          />
          <StatCard
            label="Accepted bid"
            value={formatRupees(amountAcceptedFor)}
            subtext={
              acceptedBid
                ? `eng ${shortId(acceptedBid.engineer_user_id)}`
                : "no acceptance yet"
            }
            tone={acceptedBid ? "ok" : "warn"}
          />
          <StatCard
            label="Contracted amount"
            value={formatRupees(contractedAmount)}
            subtext={
              hasApprovedRevision
                ? "revised — see Cost revisions below"
                : "current, revision-inclusive figure"
            }
            tone={hasApprovedRevision ? "warn" : "neutral"}
          />
          <StatCard
            label="Escrow"
            value={
              escrow ? `${escrow.status} · ${formatRupees(escrow.amount_rupees)}` : "—"
            }
            tone={
              escrow?.status === "released"
                ? "ok"
                : escrow?.status === "disputed"
                  ? "danger"
                  : escrow
                    ? "warn"
                    : "neutral"
            }
          />
        </div>
      </section>

      {(job.issue || job.site_address || job.serial) && (
        <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
          <h2 className="mb-2 text-sm font-semibold">Job context</h2>
          <dl className="grid grid-cols-1 gap-y-1.5 text-sm md:grid-cols-2">
            {job.serial && (
              <div>
                <dt className="text-xs text-[var(--color-muted)]">Equipment serial</dt>
                <dd>
                  <code className="text-xs">{job.serial}</code>
                </dd>
              </div>
            )}
            {job.scheduled_date && (
              <div>
                <dt className="text-xs text-[var(--color-muted)]">Scheduled</dt>
                <dd className="text-xs">{job.scheduled_date}</dd>
              </div>
            )}
            {job.site_address && (
              <div className="md:col-span-2">
                <dt className="text-xs text-[var(--color-muted)]">Site address</dt>
                <dd className="whitespace-pre-wrap text-xs">{job.site_address}</dd>
              </div>
            )}
            {job.issue && (
              <div className="md:col-span-2">
                <dt className="text-xs text-[var(--color-muted)]">Issue</dt>
                <dd className="whitespace-pre-wrap text-xs">{job.issue}</dd>
              </div>
            )}
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Created</dt>
              <dd className="text-xs">{formatRelativeTime(job.created_at)}</dd>
            </div>
            {job.completed_at && (
              <div>
                <dt className="text-xs text-[var(--color-muted)]">Completed</dt>
                <dd className="text-xs">{formatRelativeTime(job.completed_at)}</dd>
              </div>
            )}
            {job.cancelled_at && (
              <div>
                <dt className="text-xs text-[var(--color-muted)]">Cancelled</dt>
                <dd className="text-xs">{formatRelativeTime(job.cancelled_at)}</dd>
              </div>
            )}
          </dl>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Bids <span className="text-[var(--color-muted)]">({bids.length})</span>
        </h2>
        <DataTable
          columns={bidCols}
          rows={bids}
          rowKey={(b) => b.id}
          emptyMessage="No bids yet."
        />
      </section>

      {costRevisions.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">
            Cost revisions{" "}
            <span className="text-[var(--color-muted)]">({costRevisions.length})</span>
          </h2>
          <p className="mb-2 text-xs text-[var(--color-muted)]">
            Engineer-proposed contract amount changes (round3762/3764/3766). An{" "}
            <span className="rounded bg-green-100 px-1 py-0.5 text-[var(--color-ok)]">approved</span>{" "}
            row here is why &quot;Contracted amount&quot; above differs from &quot;Accepted bid&quot; —
            the escrow amount + engineer payout both follow the contracted amount, not the
            original bid.
          </p>
          <DataTable
            columns={costRevisionCols}
            rows={costRevisions}
            rowKey={(r) => r.id}
            emptyMessage="No cost revisions."
          />
        </section>
      )}

      {escrow && (
        <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
          <h2 className="mb-2 text-sm font-semibold">Escrow lifecycle</h2>
          <dl className="grid grid-cols-1 gap-y-1.5 text-sm md:grid-cols-3">
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Status</dt>
              <dd>
                <span
                  className={`rounded px-1.5 py-0.5 text-xs ${
                    escrow.status === "released"
                      ? "bg-green-100 text-[var(--color-ok)]"
                      : escrow.status === "disputed"
                        ? "bg-red-100 text-[var(--color-danger)]"
                        : "bg-yellow-100 text-[var(--color-warn)]"
                  }`}
                >
                  {escrow.status}
                </span>
              </dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Amount</dt>
              <dd>{formatRupees(escrow.amount_rupees)}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Funded</dt>
              <dd className="text-xs">{formatRelativeTime(escrow.funded_at)}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Released</dt>
              <dd className="text-xs">{formatRelativeTime(escrow.released_at)}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Disputed</dt>
              <dd className="text-xs">{formatRelativeTime(escrow.disputed_at)}</dd>
            </div>
          </dl>
        </section>
      )}

      {dsr && (
        <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
          <h2 className="mb-2 text-sm font-semibold">Digital Service Report</h2>
          <dl className="grid grid-cols-1 gap-y-1.5 text-sm md:grid-cols-3">
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Status</dt>
              <dd>{dsr.status ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">IEC 62353</dt>
              <dd>
                {dsr.iec_62353_passed === true
                  ? "PASS"
                  : dsr.iec_62353_passed === false
                    ? "FAIL"
                    : "—"}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Calibration ≤ OEM</dt>
              <dd>
                {dsr.calibration_within_oem === true
                  ? "PASS"
                  : dsr.calibration_within_oem === false
                    ? "FAIL"
                    : "—"}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Engineer signed</dt>
              <dd className="text-xs">{formatRelativeTime(dsr.engineer_signature_at)}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Hospital signed</dt>
              <dd className="text-xs">{formatRelativeTime(dsr.hospital_signature_at)}</dd>
            </div>
          </dl>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log targeting this job{" "}
          <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions targeting this job."
        />
      </section>
    </div>
  );
}
