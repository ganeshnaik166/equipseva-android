import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Webhooks — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type RzpRow = {
  id: string;
  razorpay_event_id: string;
  event_type: string;
  razorpay_payment_id: string | null;
  razorpay_order_id: string | null;
  razorpay_refund_id: string | null;
  amount_paise: number | null;
  currency: string | null;
  applied: boolean;
  apply_outcome: string | null;
  apply_error: string | null;
  received_at: string;
};

export default async function WebhooksPage({
  searchParams,
}: {
  searchParams?: Promise<{ filter?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const filter = params.filter ?? "all";
  const supabase = await getSupabaseServerClient();

  let query = supabase
    .from("razorpay_webhook_events")
    .select(
      "id, razorpay_event_id, event_type, razorpay_payment_id, razorpay_order_id, razorpay_refund_id, amount_paise, currency, applied, apply_outcome, apply_error, received_at",
    )
    .order("received_at", { ascending: false })
    .limit(100);

  if (filter === "unapplied") {
    query = query.eq("applied", false);
  } else if (filter === "failed") {
    query = query.not("apply_error", "is", null);
  }

  const { data, error } = await query;
  if (error) throw new Error(`razorpay_webhook_events: ${error.message}`);
  const rows = (data ?? []) as RzpRow[];

  // Top-of-page KPIs (over the full result set returned).
  const totalApplied = rows.filter((r) => r.applied).length;
  const totalFailed = rows.filter((r) => r.apply_error != null).length;
  const totalAmountPaise = rows
    .filter((r) => r.applied && r.amount_paise != null)
    .reduce((s, r) => s + (r.amount_paise ?? 0), 0);

  const cols: Column<RzpRow>[] = [
    {
      key: "received",
      header: "Received",
      render: (r) => (
        <span title={r.received_at}>{formatRelativeTime(r.received_at)}</span>
      ),
    },
    {
      key: "type",
      header: "Event",
      render: (r) => <code className="text-xs">{r.event_type}</code>,
    },
    {
      key: "ids",
      header: "Razorpay IDs",
      render: (r) => (
        <div className="space-y-0.5 text-xs">
          {r.razorpay_payment_id && (
            <div>
              <span className="text-[var(--color-muted)]">pay</span>{" "}
              <code>{r.razorpay_payment_id}</code>
            </div>
          )}
          {r.razorpay_order_id && (
            <div>
              <span className="text-[var(--color-muted)]">ord</span>{" "}
              <code>{r.razorpay_order_id}</code>
            </div>
          )}
          {r.razorpay_refund_id && (
            <div>
              <span className="text-[var(--color-muted)]">ref</span>{" "}
              <code>{r.razorpay_refund_id}</code>
            </div>
          )}
        </div>
      ),
    },
    {
      key: "amount",
      header: "Amount",
      render: (r) =>
        r.amount_paise != null ? formatRupees(r.amount_paise / 100) : "—",
    },
    {
      key: "status",
      header: "Applied",
      render: (r) => {
        if (r.apply_error) {
          return (
            <span className="rounded bg-red-100 px-1.5 py-0.5 text-xs text-[var(--color-danger)]">
              error
            </span>
          );
        }
        if (r.applied) {
          return (
            <span className="rounded bg-green-100 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">
              {r.apply_outcome ?? "applied"}
            </span>
          );
        }
        return (
          <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs text-[var(--color-warn)]">
            pending
          </span>
        );
      },
    },
    {
      key: "error",
      header: "Error / outcome",
      render: (r) => (
        <span className="text-xs text-[var(--color-danger)]">
          {r.apply_error ?? ""}
        </span>
      ),
    },
    {
      key: "event_id",
      header: "Event id",
      render: (r) => (
        <code className="text-xs text-[var(--color-muted)]" title={r.razorpay_event_id}>
          {shortId(r.razorpay_event_id)}
        </code>
      ),
    },
  ];

  const FILTERS = [
    { key: "all", label: "All" },
    { key: "unapplied", label: "Unapplied" },
    { key: "failed", label: "Failed" },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Razorpay webhook events</h1>
        <span className="text-xs text-[var(--color-muted)]">last 100 events</span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Events shown" value={formatNumber(rows.length)} />
          <StatCard
            label="Applied"
            value={formatNumber(totalApplied)}
            tone={totalApplied === rows.length ? "ok" : "warn"}
          />
          <StatCard
            label="Failed"
            value={formatNumber(totalFailed)}
            tone={totalFailed > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="Applied volume"
            value={formatRupees(totalAmountPaise / 100)}
          />
        </div>
      </section>

      <nav className="flex gap-2 text-sm">
        {FILTERS.map((f) => (
          <a
            key={f.key}
            href={`/webhooks?filter=${f.key}`}
            className={`rounded border px-2 py-1 ${
              f.key === filter
                ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                : "border-[var(--color-border)] hover:bg-gray-50"
            }`}
          >
            {f.label}
          </a>
        ))}
      </nav>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.id}
        emptyMessage={
          filter === "all"
            ? "No Razorpay webhook events received yet."
            : "No events match this filter."
        }
      />
    </div>
  );
}
