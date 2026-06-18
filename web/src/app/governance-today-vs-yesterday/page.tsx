import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Governance today vs yesterday — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  metric_order: number;
  today_val: number;
  yesterday_val: number;
  delta: number;
};

export default async function GovernanceTodayVsYesterdayPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_governance_today_vs_yesterday");
  if (error) throw new Error(`founder_governance_today_vs_yesterday: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Metric", render: (r) => <span className="text-xs font-medium">{r.metric}</span> },
    { key: "t", header: "Today", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.today_val)}</span> },
    { key: "y", header: "Yesterday", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.yesterday_val)}</span> },
    { key: "d", header: "Δ", render: (r) => {
        const d = r.delta;
        if (d === 0) return <span className="text-xs tabular-nums text-[var(--color-muted)]">0</span>;
        const tone = d > 0
          ? (r.metric === "Failed" ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]")
          : (r.metric === "Failed" ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]");
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{d > 0 ? "+" : ""}{formatNumber(d)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Governance today vs yesterday</h1>
        <span className="text-xs text-[var(--color-muted)]">6 governance metrics · today vs yesterday delta · "Failed" delta flips color</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.metric_order)} emptyMessage="No data." />
    </div>
  );
}
