import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Reconciliation — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type ReconRow = {
  run_date: string;
  status: string;
  rzp_total_inflow_rupees: number | null;
  cf_total_outflow_rupees: number | null;
  gst_owed_rupees: number | null;
  expected_retained_rupees: number | null;
  anomaly_count: number | null;
  ran_at: string | null;
};

type AnomalyRow = {
  id: string;
  run_date: string;
  anomaly_kind: string;
  source_kind: string | null;
  source_id: string | null;
  delta_rupees: number | null;
  details: unknown;
  created_at: string;
};

export default async function ReconciliationPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [recentRes, anomaliesRes] = await Promise.all([
    supabase.rpc("founder_reconciliation_recent", { p_days: 14 }),
    supabase.rpc("founder_reconciliation_anomalies_open", { p_limit: 100 }),
  ]);
  if (recentRes.error) throw new Error(`founder_reconciliation_recent: ${recentRes.error.message}`);
  if (anomaliesRes.error) throw new Error(`founder_reconciliation_anomalies_open: ${anomaliesRes.error.message}`);
  const recent = (recentRes.data ?? []) as ReconRow[];
  const anomalies = (anomaliesRes.data ?? []) as AnomalyRow[];

  const recentCols: Column<ReconRow>[] = [
    { key: "date", header: "Run date", render: (r) => r.run_date },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          className={`rounded px-1.5 py-0.5 text-xs ${
            r.status === "clean"
              ? "bg-green-100 text-[var(--color-ok)]"
              : r.status === "anomaly"
                ? "bg-yellow-100 text-[var(--color-warn)]"
                : "bg-red-100 text-[var(--color-danger)]"
          }`}
        >
          {r.status}
        </span>
      ),
    },
    { key: "rzp", header: "Razorpay in", render: (r) => formatRupees(r.rzp_total_inflow_rupees) },
    { key: "cf", header: "Cashfree out", render: (r) => formatRupees(r.cf_total_outflow_rupees) },
    { key: "gst", header: "GST owed", render: (r) => formatRupees(r.gst_owed_rupees) },
    { key: "retained", header: "Expected retained", render: (r) => formatRupees(r.expected_retained_rupees) },
    {
      key: "anom",
      header: "Anomalies",
      render: (r) => (
        <span className={(r.anomaly_count ?? 0) > 0 ? "font-semibold text-[var(--color-danger)]" : ""}>
          {r.anomaly_count ?? 0}
        </span>
      ),
    },
  ];

  const anomalyCols: Column<AnomalyRow>[] = [
    { key: "created", header: "Detected", render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span> },
    { key: "date", header: "Run", render: (r) => r.run_date },
    { key: "kind", header: "Kind", render: (r) => r.anomaly_kind },
    { key: "source", header: "Source", render: (r) => `${r.source_kind ?? "—"} · ${shortId(r.source_id)}` },
    { key: "delta", header: "Delta", render: (r) => formatRupees(r.delta_rupees) },
    {
      key: "details",
      header: "Details",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-xs overflow-auto text-xs">{JSON.stringify(r.details, null, 2)}</pre>
        </details>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Three-way reconciliation</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Daily RZP + CF + GST tally from r489. Anomalies need triage; consider rerunning the cron
          via the cron-tick edge fn if a date is missing.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Last 14 days</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r) => r.run_date} emptyMessage="No runs in window." />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Open anomalies <span className="text-[var(--color-muted)]">({anomalies.length})</span>
        </h2>
        <DataTable columns={anomalyCols} rows={anomalies} rowKey={(r) => r.id} emptyMessage="No open anomalies." />
      </section>
    </div>
  );
}
