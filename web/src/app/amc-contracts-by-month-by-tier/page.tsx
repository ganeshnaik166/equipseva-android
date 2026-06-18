import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "New AMCs by month × tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; tier: string; new_count: number; new_mrr: number };

export default async function AmcContractsByMonthByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_contracts_by_month_by_tier");
  if (error) throw new Error(`founder_amc_contracts_by_month_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "c", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.new_count)}</span> },
    { key: "r", header: "New MRR (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.new_mrr)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">New AMCs by month × tier (6mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Acquisition cohorts split by tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.month_ist}-${r.tier}`} emptyMessage="No new AMCs." />
    </div>
  );
}
