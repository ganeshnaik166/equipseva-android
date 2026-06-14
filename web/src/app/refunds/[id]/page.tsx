import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { RefundActions } from "../RefundActions";

export const metadata = { title: "Refund detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type RefundRow = {
  id: string;
  source_kind: string | null;
  source_id: string | null;
  amount_rupees: number | null;
  reason: string | null;
  requested_by: string | null;
  requester_email: string | null;
  expires_at: string | null;
  created_at: string;
};

type AuditRow = {
  id: string;
  op_name: string;
  outcome: string | null;
  reason: string | null;
  before_value: unknown;
  after_value: unknown;
  created_at: string;
};

export default async function RefundDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  const [pendingRes, auditRes] = await Promise.all([
    supabase.rpc("founder_pending_refund_authorizations", { p_limit: 500 }),
    supabase
      .from("founder_action_log")
      .select("id, op_name, outcome, reason, before_value, after_value, created_at")
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  if (pendingRes.error)
    throw new Error(`founder_pending_refund_authorizations: ${pendingRes.error.message}`);

  const refund = ((pendingRes.data ?? []) as RefundRow[]).find((r) => r.id === id);
  const audit = (auditRes.error ? [] : (auditRes.data ?? [])) as AuditRow[];

  // If not in the pending list, the request was already approved /
  // rejected / expired. Reconstruct from audit log if available.
  const lastAction = audit[audit.length - 1];

  if (!refund && audit.length === 0) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Refund request not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Not in pending queue AND no audit log entries for <code>{id}</code>. Either a stale
          link or beyond the 500-row pending window.
        </p>
        <Link
          href="/refunds"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to refunds
        </Link>
      </div>
    );
  }

  const isPending = refund != null;
  const expired =
    refund?.expires_at != null && new Date(refund.expires_at).getTime() < Date.now();

  const auditCols: Column<AuditRow>[] = [
    { key: "when", header: "When", render: (r) => formatRelativeTime(r.created_at) },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    { key: "outcome", header: "Outcome", render: (r) => r.outcome ?? "—" },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
    {
      key: "diff",
      header: "Before → After",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-md overflow-auto text-xs">
            {JSON.stringify({ before: r.before_value, after: r.after_value }, null, 2)}
          </pre>
        </details>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header>
        <Link
          href="/refunds"
          className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
        >
          ← refunds
        </Link>
        <h1 className="mt-1 text-xl font-semibold">
          Refund request <code>{shortId(id)}</code>
        </h1>
        <p className="text-xs text-[var(--color-muted)]">
          request_id <code>{id}</code> ·{" "}
          {isPending ? (
            <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-[var(--color-warn)]">
              pending
            </span>
          ) : (
            <span className="rounded bg-gray-100 px-1.5 py-0.5">settled / expired</span>
          )}
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Amount" value={formatRupees(refund?.amount_rupees ?? null)} />
          <StatCard
            label="Requested"
            value={formatRelativeTime(refund?.created_at ?? lastAction?.created_at ?? null)}
          />
          <StatCard
            label="Expires"
            value={formatRelativeTime(refund?.expires_at ?? null)}
            tone={expired ? "danger" : isPending ? "warn" : "neutral"}
            subtext={expired ? "EXPIRED" : isPending ? "founder action window" : undefined}
          />
          <StatCard
            label="Source"
            value={refund?.source_kind ?? "—"}
            subtext={refund?.source_id ? shortId(refund.source_id) : undefined}
          />
        </div>
      </section>

      {refund && (
        <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
          <h2 className="mb-2 text-sm font-semibold">Request details</h2>
          <dl className="grid grid-cols-1 gap-y-1.5 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Requested by</dt>
              <dd>{refund.requester_email ?? shortId(refund.requested_by)}</dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-muted)]">Source</dt>
              <dd className="text-xs">
                {refund.source_kind ?? "—"} ·{" "}
                <code>{shortId(refund.source_id)}</code>
              </dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-xs text-[var(--color-muted)]">Reason</dt>
              <dd className="whitespace-pre-wrap">{refund.reason ?? "—"}</dd>
            </div>
          </dl>
        </section>
      )}

      {isPending && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">Action</h2>
          <RefundActions requestId={id} />
          <p className="mt-2 text-xs text-[var(--color-muted)]">
            Approve / reject writes to <code>founder_action_log</code> via SECDEF RPC. Approval
            triggers the downstream gateway refund; rejection requires a reason ≥1 char.
          </p>
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log for this request{" "}
          <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions yet."
        />
      </section>
    </div>
  );
}
