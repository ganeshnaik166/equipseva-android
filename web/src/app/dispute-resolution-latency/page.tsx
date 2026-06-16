import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Dispute resolution latency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; resolved_cnt: number; avg_hours: number; p50_hours: number; p90_hours: number; unresolved_now: number };

function fmt(h: number) {
  if (h < 24) return `${h.toFixed(1)}h`;
  return `${(h / 24).toFixed(1)}d`;
}

export default async function DisputeResolutionLatencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_resolution_latency");
  if (error) throw new Error(`founder_dispute_resolution_latency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const pending = rows[0]?.unresolved_now ?? 0;
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.resolved_cnt)}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums">{fmt(Number(r.avg_hours))}</span> },
    { key: "50", header: "p50", render: (r) => <span className="text-xs tabular-nums">{fmt(Number(r.p50_hours))}</span> },
    { key: "90", header: "p90",
      render: (r) => {
        const h = Number(r.p90_hours);
        const tone = h > 168 ? "text-[var(--color-danger)]" : h > 72 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{fmt(h)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute resolution latency</h1>
        <span className="text-xs text-[var(--color-muted)]">submitted → mediator decision</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Pending now" value={formatNumber(pending)} tone={pending > 0 ? "warn" : "ok"} />
          <StatCard label="7d resolved" value={formatNumber(w7?.resolved_cnt ?? 0)} />
          <StatCard label="7d p90" value={fmt(Number(w7?.p90_hours ?? 0))} tone={Number(w7?.p90_hours ?? 0) > 72 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No resolved disputes." />
    </div>
  );
}
