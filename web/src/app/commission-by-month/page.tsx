import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Commission by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; gross_rupees: number; commission_est_rupees: number; commission_pct: number };

export default async function CommissionByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_commission_by_month");
  if (error) throw new Error(`founder_commission_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCommission = rows.reduce((n, r) => n + (r.commission_est_rupees ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.gross_rupees)}</span> },
    { key: "c", header: "Commission est. (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.commission_est_rupees)}</span> },
    { key: "p", header: "Rate", render: (r) => <span className="text-xs tabular-nums">{r.commission_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Commission by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total est. ₹{formatNumber(totalCommission)} · 7% take rate</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No completed jobs." />
    </div>
  );
}
