import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";
import { PayoutActions } from "../PayoutActions";

export const metadata = { title: "Payout detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type PayoutRow = {
  id: string;
  repair_job_id: string | null;
  job_number: string | null;
  engineer_user_id: string;
  engineer_name: string | null;
  engineer_phone: string | null;
  amount_paise: number | null;
  status: string;
  mode: string | null;
  utr: string | null;
  failure_reason: string | null;
  destination_label: string | null;
  attempts: number | null;
  queued_at: string | null;
  processed_at: string | null;
};

type WebhookRow = {
  id: string;
  razorpay_payout_id: string;
  event_kind: string;
  utr: string | null;
  mode: string | null;
  failure_reason: string | null;
  applied: boolean;
  apply_outcome: string | null;
  received_at: string;
};

type AuditRow = {
  id: string;
  op_name: string;
  target_table: string | null;
  outcome: string | null;
  reason: string | null;
  before_value: unknown;
  after_value: unknown;
  created_at: string;
};

export default async function PayoutDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  // Compose: pull a wide payout list (no detail-by-id RPC) and find this
  // row. Also pull webhook events that match — but webhook rows key on
  // razorpay_payout_id (Cashfree's id), not our internal payout id.
  // We discover the link after we have the payout row.
  const [listAllRes, listSettledRes, auditRes] = await Promise.all([
    supabase.rpc("admin_list_engineer_payouts", { p_status: null, p_limit: 500 }),
    supabase.rpc("admin_list_engineer_payouts", { p_status: "paid", p_limit: 500 }),
    supabase
      .from("founder_action_log")
      .select(
        "id, op_name, target_table, outcome, reason, before_value, after_value, created_at",
      )
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  if (listAllRes.error)
    throw new Error(`admin_list_engineer_payouts: ${listAllRes.error.message}`);

  const combined = [
    ...((listAllRes.data ?? []) as PayoutRow[]),
    ...((listSettledRes.error ? [] : (listSettledRes.data ?? [])) as PayoutRow[]),
  ];
  const payout = combined.find((r) => r.id === id);
  const audit = (auditRes.error ? [] : (auditRes.data ?? [])) as AuditRow[];

  if (!payout) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Payout not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          No row in <code>admin_list_engineer_payouts</code> matches <code>{id}</code>.
          Could be very old (beyond the 1000-row window) or a stale link.
        </p>
        <Link
          href="/payouts"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to payouts
        </Link>
      </div>
    );
  }

  // Pull webhook events keyed by *Cashfree* payout id. We don't have
  // that on our row (yet), so fall back to a wide table query and find
  // events whose timestamps overlap this payout's lifecycle.
  // Quick approach: search by failure_reason or destination_label match
  // is unreliable — best signal is webhook events around processed_at.
  // For now we expose a search field instead of guessing.
  const { data: webhookByGuess } = await supabase
    .from("payouts_webhook_events")
    .select(
      "id, razorpay_payout_id, event_kind, utr, mode, failure_reason, applied, apply_outcome, received_at",
    )
    .eq("utr", payout.utr ?? "__no_match__")
    .order("received_at", { ascending: false })
    .limit(20);
  const webhookEvents = (webhookByGuess ?? []) as WebhookRow[];

  const statusTone =
    payout.status === "paid" || payout.status === "processed"
      ? "ok"
      : payout.status === "failed" || payout.status === "cancelled"
        ? "danger"
        : "warn";

  const webhookCols: Column<WebhookRow>[] = [
    {
      key: "when",
      header: "Received",
      render: (r) => <span title={r.received_at}>{formatRelativeTime(r.received_at)}</span>,
    },
    { key: "kind", header: "Event", render: (r) => <code className="text-xs">{r.event_kind}</code> },
    {
      key: "cf",
      header: "Cashfree id",
      render: (r) => (
        <code className="text-xs" title={r.razorpay_payout_id}>
          {shortId(r.razorpay_payout_id)}
        </code>
      ),
    },
    { key: "utr", header: "UTR", render: (r) => <code className="text-xs">{r.utr ?? "—"}</code> },
    {
      key: "fail",
      header: "Failure",
      render: (r) => <span className="text-xs text-[var(--color-danger)]">{r.failure_reason ?? ""}</span>,
    },
    {
      key: "applied",
      header: "Applied",
      render: (r) =>
        r.applied ? (
          <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
            {r.apply_outcome ?? "applied"}
          </span>
        ) : (
          <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs text-[var(--color-warn)]">
            pending
          </span>
        ),
    },
  ];

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
          href="/payouts"
          className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
        >
          ← payouts
        </Link>
        <h1 className="mt-1 text-xl font-semibold">
          Payout to {payout.engineer_name ?? shortId(payout.engineer_user_id)}
        </h1>
        <p className="text-xs text-[var(--color-muted)]">
          payout_id <code>{payout.id}</code>
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Amount"
            value={formatRupees(payout.amount_paise != null ? payout.amount_paise / 100 : null)}
          />
          <StatCard label="Status" value={payout.status} tone={statusTone} />
          <StatCard label="Attempts" value={formatNumber(payout.attempts)} />
          <StatCard
            label="UTR"
            value={payout.utr ?? "—"}
            subtext={payout.mode ?? undefined}
          />
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-4 text-sm">
        <h2 className="mb-2 text-sm font-semibold">Engineer + destination</h2>
        <dl className="grid grid-cols-1 gap-y-1.5 text-sm sm:grid-cols-2 md:grid-cols-3">
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Engineer</dt>
            <dd>
              <Link
                href={`/engineers/${payout.engineer_user_id}`}
                className="text-[var(--color-accent)] hover:underline"
              >
                {payout.engineer_name ?? shortId(payout.engineer_user_id)}
              </Link>
            </dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Phone</dt>
            <dd>{payout.engineer_phone ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Job</dt>
            <dd>
              <code className="text-xs">
                {payout.job_number ?? shortId(payout.repair_job_id)}
              </code>
            </dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Destination</dt>
            <dd className="text-xs">{payout.destination_label ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Queued</dt>
            <dd className="text-xs">{formatRelativeTime(payout.queued_at)}</dd>
          </div>
          <div>
            <dt className="text-xs text-[var(--color-muted)]">Processed</dt>
            <dd className="text-xs">{formatRelativeTime(payout.processed_at)}</dd>
          </div>
        </dl>
        {payout.failure_reason && (
          <div className="mt-3 rounded border border-[var(--color-danger)] bg-red-50 p-2 text-sm text-[var(--color-danger)]">
            <span className="font-medium">Last failure:</span> {payout.failure_reason}
          </div>
        )}
      </section>

      <section>
        <div className="mb-2 flex items-baseline justify-between">
          <h2 className="text-sm font-semibold">Action</h2>
          <span className="text-xs text-[var(--color-muted)]">
            Settled rows render a status badge instead.
          </span>
        </div>
        <PayoutActions payoutId={payout.id} status={payout.status} />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Cashfree webhook events matched by UTR{" "}
          <span className="text-[var(--color-muted)]">({webhookEvents.length})</span>
        </h2>
        <p className="mb-2 text-xs text-[var(--color-muted)]">
          We match on UTR rather than Cashfree payout id (the latter isn&rsquo;t on our row).
          Empty when the row has no UTR yet OR when no event was captured.
        </p>
        <DataTable
          columns={webhookCols}
          rows={webhookEvents}
          rowKey={(r) => r.id}
          emptyMessage="No matching webhook events."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log targeting this payout id{" "}
          <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions targeting this payout."
        />
      </section>
    </div>
  );
}
