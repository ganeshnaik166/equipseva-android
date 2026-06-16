import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal pipeline — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  expiring_count: number;
  auto_renew_count: number;
  manual_count: number;
  monthly_mrr_rupees: number;
  annual_arr_rupees: number;
};

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcRenewalPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_pipeline");
  if (error) throw new Error(`founder_amc_renewal_pipeline: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const w30 = rows.find((r) => r.window_label === "0-30d");
  const totalActive = rows.reduce((s, r) => s + r.expiring_count, 0);
  const totalMrr = rows.reduce((s, r) => s + Number(r.monthly_mrr_rupees), 0);
  const manual30 = w30?.manual_count ?? 0;

  const cols: Column<Row>[] = [
    {
      key: "w", header: "Window",
      render: (r) => {
        const tone = r.window_label === "0-30d" ? "text-[var(--color-danger)]"
          : r.window_label === "31-60d" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.window_label}</span>;
      }
    },
    { key: "c", header: "Expiring", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.expiring_count)}</span> },
    { key: "a", header: "Auto-renew", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.auto_renew_count)}</span> },
    { key: "m", header: "Manual", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.manual_count)}</span> },
    { key: "mrr", header: "MRR at stake", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_mrr_rupees))}</span> },
    { key: "arr", header: "ARR proxy (12×)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.annual_arr_rupees))}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal pipeline</h1>
        <span className="text-xs text-[var(--color-muted)]">forward look · active contracts only</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Active AMCs" value={formatNumber(totalActive)} />
          <StatCard label="Expiring 30d" value={formatNumber(w30?.expiring_count ?? 0)} tone={(w30?.expiring_count ?? 0) > 0 ? "warn" : "ok"} />
          <StatCard label="Manual 30d (need outreach)" value={formatNumber(manual30)} tone={manual30 > 0 ? "danger" : "ok"} />
          <StatCard label="Total MRR" value={inr(totalMrr)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No active AMCs." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this surface.</strong> Auto-renew contracts charge themselves;
        manual contracts need explicit outreach before <em>end_date</em>. Manual
        count in 0-30d bucket = founder action queue. ARR proxy = current
        monthly fee × 12 (does not account for upsell/churn).
      </section>
    </div>
  );
}
