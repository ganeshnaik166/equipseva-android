import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC base growth — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; new_amcs: number; new_mrr: number; cumulative: number; cum_mrr: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcBaseGrowthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_base_growth");
  if (error) throw new Error(`founder_amc_base_growth: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "n", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.new_amcs)}</span> },
    { key: "nm", header: "New MRR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.new_mrr))}</span> },
    { key: "c", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cumulative)}</span> },
    { key: "cm", header: "Cum MRR", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.cum_mrr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC base growth</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative AMCs + MRR</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No AMCs." />
    </div>
  );
}
