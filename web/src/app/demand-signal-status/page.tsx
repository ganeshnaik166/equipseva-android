import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand signal status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number };

export default async function DemandSignalStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_signal_status");
  if (error) throw new Error(`founder_demand_signal_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const high = rows.find((r) => r.bucket.includes("high"))?.cnt ?? 0;
  const unp = rows.find((r) => r.bucket.includes("unprioritized"))?.cnt ?? 0;
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket",
      render: (r) => {
        const tone = r.bucket.includes("high") ? "text-[var(--color-danger)]"
          : r.bucket.includes("med") ? "text-[var(--color-warn)]"
          : r.bucket === "Resolved" ? "text-[var(--color-ok)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.bucket}</span>;
      }
    },
    { key: "c", header: "Signals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand signal status</h1>
        <span className="text-xs text-[var(--color-muted)]">open by priority + resolved · all-time</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="High priority open" value={formatNumber(high)} tone={high > 0 ? "danger" : "ok"} />
          <StatCard label="Unprioritized open" value={formatNumber(unp)} tone={unp > 0 ? "warn" : "ok"} />
          <StatCard label="Total signals" value={formatNumber(total)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No demand signals." />
    </div>
  );
}
