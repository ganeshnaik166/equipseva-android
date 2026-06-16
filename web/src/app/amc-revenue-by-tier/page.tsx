import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC revenue by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; active_contracts: number; monthly_mrr: number; annual_arr: number; share_pct: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcRevenueByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_by_tier");
  if (error) throw new Error(`founder_amc_revenue_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrr = rows.reduce((s, r) => s + Number(r.monthly_mrr), 0);
  const totalArr = rows.reduce((s, r) => s + Number(r.annual_arr), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold capitalize">{r.tier}</span> },
    { key: "c", header: "Active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_contracts)}</span> },
    { key: "m", header: "MRR", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.monthly_mrr))}</span> },
    { key: "a", header: "ARR (12x)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.annual_arr))}</span> },
    { key: "s", header: "MRR share", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue by tier</h1>
        <span className="text-xs text-[var(--color-muted)]">active contracts only · MRR + ARR per tier</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Total MRR" value={inr(totalMrr)} />
          <StatCard label="Total ARR" value={inr(totalArr)} />
          <StatCard label="Tiers with revenue" value={formatNumber(rows.filter((r) => Number(r.monthly_mrr) > 0).length)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No active AMCs." />
    </div>
  );
}
