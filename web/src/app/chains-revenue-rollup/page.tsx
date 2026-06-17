import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Chains revenue rollup — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { chain_id: string; name: string; member_count: number; amc_paid_90d: number; jobs_gross_90d: number; total_rupees_90d: number };

export default async function ChainsRevenueRollupPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_revenue_rollup");
  if (error) throw new Error(`founder_chains_revenue_rollup: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Chain", render: (r) => <span className="text-xs font-semibold">{r.name}</span> },
    { key: "m", header: "Members", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.member_count)}</span> },
    { key: "a", header: "AMC paid 90d (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_paid_90d)}</span> },
    { key: "j", header: "Jobs gross 90d (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_gross_90d)}</span> },
    { key: "t", header: "Total 90d (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_rupees_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains revenue rollup (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 chains by total 90d revenue (AMC + jobs)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_id} emptyMessage="No chains." />
    </div>
  );
}
