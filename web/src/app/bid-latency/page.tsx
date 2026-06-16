import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bid acceptance latency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  jobs_with_accept: number;
  avg_minutes: number;
  p50_minutes: number;
  p90_minutes: number;
  max_minutes: number;
};

function fmt(m: number | null) {
  if (m == null) return "—";
  if (m < 60) return `${m.toFixed(0)}m`;
  if (m < 1440) return `${(m / 60).toFixed(1)}h`;
  return `${(m / 1440).toFixed(1)}d`;
}

export default async function BidLatencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bid_acceptance_latency");
  if (error) throw new Error(`founder_bid_acceptance_latency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "n", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_with_accept)}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums">{fmt(r.avg_minutes)}</span> },
    { key: "50", header: "p50", render: (r) => <span className="text-xs tabular-nums">{fmt(r.p50_minutes)}</span> },
    {
      key: "90", header: "p90",
      render: (r) => {
        const tone = r.p90_minutes > 1440 ? "text-[var(--color-danger)]"
          : r.p90_minutes > 240 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{fmt(r.p90_minutes)}</span>;
      }
    },
    { key: "m", header: "Max", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{fmt(r.max_minutes)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bid acceptance latency</h1>
        <span className="text-xs text-[var(--color-muted)]">Job-posted → bid-accepted time</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="7d avg" value={fmt(w7?.avg_minutes ?? null)} />
          <StatCard label="7d p90" value={fmt(w7?.p90_minutes ?? null)} tone={(w7?.p90_minutes ?? 0) > 240 ? "warn" : "ok"} />
          <StatCard label="30d avg" value={fmt(w30?.avg_minutes ?? null)} />
          <StatCard label="30d jobs" value={formatNumber(w30?.jobs_with_accept ?? 0)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No bid acceptance data." />
    </div>
  );
}
