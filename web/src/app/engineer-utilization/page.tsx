import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer utilization — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; total_verified: number; active_count: number; active_pct: number };

export default async function EngineerUtilizationPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_utilization");
  if (error) throw new Error(`founder_engineer_utilization: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const w30 = rows.find((r) => r.window_label === "30d");
  const w90 = rows.find((r) => r.window_label === "90d");
  const total = rows[0]?.total_verified ?? 0;
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_count)}</span> },
    { key: "t", header: "Total verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.total_verified)}</span> },
    { key: "p", header: "Active %",
      render: (r) => {
        const tone = r.active_pct < 30 ? "text-[var(--color-danger)]"
          : r.active_pct < 60 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.active_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer utilization</h1>
        <span className="text-xs text-[var(--color-muted)]">verified engineers with ≥1 completed job</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Verified" value={formatNumber(total)} />
          <StatCard label="7d active" value={formatNumber(w7?.active_count ?? 0)} subtext={`${w7?.active_pct ?? 0}%`} />
          <StatCard label="30d active" value={formatNumber(w30?.active_count ?? 0)} subtext={`${w30?.active_pct ?? 0}%`} />
          <StatCard label="90d active" value={formatNumber(w90?.active_count ?? 0)} subtext={`${w90?.active_pct ?? 0}%`} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No engineer data." />
    </div>
  );
}
