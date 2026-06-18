import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool credits by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  credit_cnt: number;
  credit_inr: number;
  distinct_contracts: number;
};

export default async function AmcPoolCreditsByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_credits_by_week_13wk");
  if (error) throw new Error(`founder_amc_pool_credits_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCredit = rows.reduce((a, r) => a + Number(r.credit_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "c", header: "Credit events", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.credit_cnt)}</span> },
    { key: "i", header: "Credit INR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatRupees(Number(r.credit_inr))}</span> },
    { key: "d", header: "Distinct AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_contracts)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool credits by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk cumulative credits: <span className="font-mono tabular-nums">{formatRupees(totalCredit)}</span> · top-up velocity
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No credit events in last 13 weeks." />
    </div>
  );
}
