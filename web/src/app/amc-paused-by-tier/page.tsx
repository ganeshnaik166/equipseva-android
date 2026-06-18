import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC paused by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; paused_cnt: number; frozen_mrr: number; avg_days_paused: number };

export default async function AmcPausedByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_paused_by_tier");
  if (error) throw new Error(`founder_amc_paused_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalFrozen = rows.reduce((n, r) => n + (r.frozen_mrr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paused_cnt)}</span> },
    { key: "m", header: "Frozen MRR (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)] font-semibold">{formatNumber(r.frozen_mrr)}</span> },
    { key: "d", header: "Avg days paused",
      render: (r) => {
        const tone = r.avg_days_paused > 30 ? "text-[var(--color-danger)]"
          : r.avg_days_paused > 7 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.avg_days_paused}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC paused by tier</h1>
        <span className="text-xs text-[var(--color-muted)]">Total frozen MRR ₹{formatNumber(totalFrozen)} · paused contracts by tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No paused contracts." />
    </div>
  );
}
