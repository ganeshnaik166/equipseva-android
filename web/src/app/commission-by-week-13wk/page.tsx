import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Commission by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  total_fees_inr: number;
  invoice_cnt: number;
};

export default async function CommissionByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_commission_by_week_13wk");
  if (error) throw new Error(`founder_commission_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalFees = rows.reduce((a, r) => a + Number(r.total_fees_inr ?? 0), 0);
  const totalCnt = rows.reduce((a, r) => a + (r.invoice_cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "i", header: "Invoices", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.invoice_cnt)}</span> },
    { key: "f", header: "Platform fees", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatRupees(Number(r.total_fees_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Commission (platform fees) by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk: <span className="font-mono tabular-nums">{formatNumber(totalCnt)}</span> invoices · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatRupees(totalFees)}</span> platform-fee revenue
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No platform-fee invoices in last 13 weeks." />
    </div>
  );
}
