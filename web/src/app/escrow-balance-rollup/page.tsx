import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow balance rollup — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; job_count: number; total_rupees: number; avg_rupees: number; oldest_days: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

const LIVE = new Set(["pending", "held", "in_dispute"]);

export default async function EscrowBalanceRollupPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_balance_rollup");
  if (error) throw new Error(`founder_escrow_balance_rollup: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const liveTotal = rows.filter((r) => LIVE.has(r.status)).reduce((s, r) => s + Number(r.total_rupees), 0);
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "in_dispute" ? "text-[var(--color-danger)]"
          : r.status === "held" ? "text-[var(--color-warn)]"
          : r.status === "pending" ? "text-[var(--color-muted)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.job_count)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.total_rupees))}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{inr(Number(r.avg_rupees))}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.oldest_days)}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow balance rollup</h1>
        <span className="text-xs text-[var(--color-muted)]">r650 milestone · per-status totals</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Live escrow balance" value={inr(liveTotal)} tone={liveTotal > 0 ? "warn" : "ok"} />
          <StatCard label="Statuses tracked" value={formatNumber(rows.length)} />
          <StatCard label="Oldest holding" value={formatNumber(Math.max(0, ...rows.filter((r) => LIVE.has(r.status)).map((r) => r.oldest_days)))} subtext="days" />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No escrow rows." />
    </div>
  );
}
