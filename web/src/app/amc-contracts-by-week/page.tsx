import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC contracts by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; new_amcs: number; net_mrr: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcContractsByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_contracts_by_week");
  if (error) throw new Error(`founder_amc_contracts_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "n", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.new_amcs)}</span> },
    { key: "m", header: "New MRR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.net_mrr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC contracts by week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 13 weeks · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No AMCs." />
    </div>
  );
}
