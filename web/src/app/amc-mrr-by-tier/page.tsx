import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC MRR by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; active_cnt: number; mrr_rupees: number; arr_rupees: number; avg_fee: number; share_pct: number };

export default async function AmcMrrByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_mrr_by_tier");
  if (error) throw new Error(`founder_amc_mrr_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrr = rows.reduce((n, r) => n + (r.mrr_rupees ?? 0), 0);
  const totalArr = rows.reduce((n, r) => n + (r.arr_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_cnt)}</span> },
    { key: "m", header: "MRR (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.mrr_rupees)}</span> },
    { key: "r", header: "ARR (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.arr_rupees)}</span> },
    { key: "f", header: "Avg fee", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.avg_fee)}</span> },
    { key: "s", header: "Share %", render: (r) => <span className="text-xs tabular-nums">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC MRR by tier</h1>
        <span className="text-xs text-[var(--color-muted)]">Total MRR ₹{formatNumber(totalMrr)} · ARR ₹{formatNumber(totalArr)}</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No tiers." />
    </div>
  );
}
