import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC contracts by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  new_amcs: number;
  total_mrr_inr: number;
  distinct_tiers: number;
};

export default async function AmcContractsByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_contracts_by_day_30d");
  if (error) throw new Error(`founder_amc_contracts_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalNew = rows.reduce((a, r) => a + (r.new_amcs ?? 0), 0);
  const totalMrr = rows.reduce((a, r) => a + Number(r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "n", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.new_amcs)}</span> },
    { key: "m", header: "MRR added", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "t", header: "Tiers used", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_tiers)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC contracts by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d total: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalNew)}</span> new · <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span> MRR added
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No new AMCs in last 30 days." />
    </div>
  );
}
