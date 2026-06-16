import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand signals trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; signals: number; distinct_skus: number; distinct_users: number };

export default async function DemandSignalsTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_signals_trend");
  if (error) throw new Error(`founder_demand_signals_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total14d = rows.reduce((s, r) => s + r.signals, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "s", header: "Signals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signals)}</span> },
    { key: "k", header: "Distinct SKUs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_skus)}</span> },
    { key: "u", header: "Distinct reporters", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.distinct_users)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand signals trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d signals" value={formatNumber(total14d)} />
          <StatCard label="Daily avg" value={(total14d / 14).toFixed(1)} />
          <StatCard label="Today" value={formatNumber(rows[0]?.signals ?? 0)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No demand signals." />
    </div>
  );
}
