import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC churn — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  active_now: number;
  new_contracts: number;
  cancelled: number;
  expired: number;
  renewal_failed: number;
  churn_pct: number;
};

export default async function AmcChurnPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_churn");
  if (error) throw new Error(`founder_amc_churn: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const active = rows[0]?.active_now ?? 0;
  const churn90 = rows.find((r) => r.window_label === "90d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "n", header: "New", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.new_contracts)}</span> },
    { key: "c", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cancelled)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.expired)}</span> },
    { key: "rf", header: "Renewal fail", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.renewal_failed)}</span> },
    {
      key: "p", header: "Churn %",
      render: (r) => {
        const tone = r.churn_pct >= 10 ? "text-[var(--color-danger)]"
          : r.churn_pct >= 5 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.churn_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC churn</h1>
        <span className="text-xs text-[var(--color-muted)]">Active vs churn over rolling windows</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Active now" value={formatNumber(active)} />
          <StatCard label="New (90d)" value={formatNumber(churn90?.new_contracts ?? 0)} tone="ok" />
          <StatCard label="Churned (90d)" value={formatNumber((churn90?.cancelled ?? 0) + (churn90?.expired ?? 0) + (churn90?.renewal_failed ?? 0))} tone={(churn90?.churn_pct ?? 0) >= 5 ? "warn" : "ok"} />
          <StatCard label="Churn % (90d)" value={`${churn90?.churn_pct ?? 0}%`} tone={(churn90?.churn_pct ?? 0) >= 10 ? "danger" : (churn90?.churn_pct ?? 0) >= 5 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No churn data." />
    </div>
  );
}
