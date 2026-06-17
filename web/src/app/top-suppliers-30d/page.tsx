import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Top suppliers (30d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { supplier_name: string; supplier_tier: string; intake_rows: number; total_qty: number; total_cost: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function TopSuppliers30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_suppliers_30d");
  if (error) throw new Error(`founder_top_suppliers_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Supplier", render: (r) => <span className="text-xs">{r.supplier_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.supplier_tier}</span> },
    { key: "r", header: "Intake rows", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.intake_rows)}</span> },
    { key: "q", header: "Qty (30d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_qty)}</span> },
    { key: "c", header: "Cost", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.total_cost))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top suppliers (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">top 25 active bonded suppliers · last 30d intake</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.supplier_name}|${r.supplier_tier}`} emptyMessage="No intake last 30d." />
    </div>
  );
}
