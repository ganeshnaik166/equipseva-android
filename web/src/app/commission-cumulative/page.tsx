import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Commission cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; monthly_commission: number; cum_commission: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function CommissionCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_commission_cumulative");
  if (error) throw new Error(`founder_commission_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "c", header: "Commission (month)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_commission))}</span> },
    { key: "cc", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.cum_commission))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Commission cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month platform take @ 7% estimate</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No completed jobs." />
    </div>
  );
}
