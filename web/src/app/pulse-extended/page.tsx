import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Pulse extended — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { metric: string; this_week: number; last_week: number; delta_pct: number | null; ord: number };

export default async function PulseExtendedPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_pulse_extended");
  if (error) throw new Error(`founder_pulse_extended: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Metric", render: (r) => <span className="text-xs font-semibold">{r.metric}</span> },
    { key: "t", header: "This week", render: (r) => <span className="text-xs tabular-nums">{formatNumber(Number(r.this_week))}</span> },
    { key: "l", header: "Last week", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(Number(r.last_week))}</span> },
    { key: "d", header: "Δ %",
      render: (r) => {
        if (r.delta_pct == null) return <span className="text-xs text-[var(--color-muted)]">—</span>;
        const v = Number(r.delta_pct);
        const isDispute = r.metric === "Disputes opened";
        const tone = v > 0 ? (isDispute ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]")
          : v < 0 ? (isDispute ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]") : "";
        const sign = v > 0 ? "+" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{sign}{v}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Pulse extended</h1>
        <span className="text-xs text-[var(--color-muted)]">r780 milestone · 10 KPIs · this-week vs last-week</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.metric} emptyMessage="No data." />
    </div>
  );
}
