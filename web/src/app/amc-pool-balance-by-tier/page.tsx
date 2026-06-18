import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool balance by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; active_contracts: number; total_balance: number; mrr: number; avg_buffer_months: number };

export default async function AmcPoolBalanceByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_balance_by_tier");
  if (error) throw new Error(`founder_amc_pool_balance_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "c", header: "Active contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_contracts)}</span> },
    { key: "b", header: "Balance (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_balance)}</span> },
    { key: "m", header: "MRR (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.mrr)}</span> },
    { key: "a", header: "Avg buffer (mo)",
      render: (r) => {
        const tone = r.avg_buffer_months < 1 ? "text-[var(--color-danger)]"
          : r.avg_buffer_months < 2 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.avg_buffer_months}×</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool balance by tier</h1>
        <span className="text-xs text-[var(--color-muted)]">Total pool balance + avg buffer (in months of MRR) per tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No active tiers." />
    </div>
  );
}
