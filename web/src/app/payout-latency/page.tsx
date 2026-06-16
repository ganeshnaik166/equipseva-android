import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payout latency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  window_label: string;
  paid_count: number;
  avg_hours: number;
  p50_hours: number;
  p90_hours: number;
  pending_count: number;
  failed_count: number;
};

function fmt(h: number | null) {
  if (h == null) return "—";
  if (h < 24) return `${h.toFixed(1)}h`;
  return `${(h / 24).toFixed(1)}d`;
}

export default async function PayoutLatencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payout_settlement_latency");
  if (error) throw new Error(`founder_payout_settlement_latency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const w7 = rows.find((r) => r.window_label === "7d");
  const w30 = rows.find((r) => r.window_label === "30d");
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_count)}</span> },
    { key: "pn", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending_count)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_count)}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums">{fmt(r.avg_hours)}</span> },
    { key: "50", header: "p50", render: (r) => <span className="text-xs tabular-nums">{fmt(r.p50_hours)}</span> },
    {
      key: "90", header: "p90",
      render: (r) => {
        const tone = r.p90_hours > 72 ? "text-[var(--color-danger)]"
          : r.p90_hours > 24 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{fmt(r.p90_hours)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payout settlement latency</h1>
        <span className="text-xs text-[var(--color-muted)]">queued → processed time</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="7d paid" value={formatNumber(w7?.paid_count ?? 0)} />
          <StatCard label="7d p90" value={fmt(w7?.p90_hours ?? null)} tone={(w7?.p90_hours ?? 0) > 24 ? "warn" : "ok"} />
          <StatCard label="Pending now (7d)" value={formatNumber(w7?.pending_count ?? 0)} tone={(w7?.pending_count ?? 0) > 0 ? "warn" : "ok"} />
          <StatCard label="Failed (30d)" value={formatNumber(w30?.failed_count ?? 0)} tone={(w30?.failed_count ?? 0) > 0 ? "danger" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No payout data." />
    </div>
  );
}
