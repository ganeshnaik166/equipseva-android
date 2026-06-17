import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded intake cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; rows_in: number; cum_rows: number; qty: number; cum_qty: number; cum_cost: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function BondedIntakeCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_intake_cumulative");
  if (error) throw new Error(`founder_bonded_intake_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "n", header: "Intake (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.rows_in)}</span> },
    { key: "cn", header: "Cum rows", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_rows)}</span> },
    { key: "q", header: "Qty (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.qty)}</span> },
    { key: "cq", header: "Cum qty", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_qty)}</span> },
    { key: "cc", header: "Cum cost", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.cum_cost))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded intake cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative bonded parts intake</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No bonded intake." />
    </div>
  );
}
