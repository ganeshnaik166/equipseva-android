import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC tier distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; active_cnt: number; total_cnt: number; monthly_mrr: number; avg_fee: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcTierDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_tier_distribution");
  if (error) throw new Error(`founder_amc_tier_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold capitalize">{r.tier}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_cnt)}</span> },
    { key: "c", header: "Total ever", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.total_cnt)}</span> },
    { key: "m", header: "MRR", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.monthly_mrr))}</span> },
    { key: "v", header: "Avg fee", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.avg_fee))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC tier distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">contracts grouped by tier · MRR roll-up</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No AMCs." />
    </div>
  );
}
