import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool balance by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; contracts: number; total_balance: number; mrr: number };

export default async function AmcPoolBalanceByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_balance_by_state");
  if (error) throw new Error(`founder_amc_pool_balance_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "c", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.contracts)}</span> },
    { key: "b", header: "Balance (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_balance)}</span> },
    { key: "m", header: "MRR (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.mrr)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool balance by state</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 states by active-contract pool balance</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No active contracts." />
    </div>
  );
}
