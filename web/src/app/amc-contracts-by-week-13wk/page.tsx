import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC contracts by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  new_amcs: number;
  total_mrr_inr: number;
  distinct_tiers: number;
};

export default async function AmcContractsByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_contracts_by_week_13wk");
  if (error) throw new Error(`founder_amc_contracts_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalNew = rows.reduce((a, r) => a + (r.new_amcs ?? 0), 0);
  const totalMrr = rows.reduce((a, r) => a + Number(r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "n", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.new_amcs)}</span> },
    { key: "m", header: "MRR added", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "t", header: "Tiers used", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_tiers)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC contracts by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalNew)}</span> new AMCs · <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span> MRR added
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No new AMCs in last 13 weeks." />
    </div>
  );
}
