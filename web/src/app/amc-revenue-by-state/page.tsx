import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC revenue by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; hospital_cnt: number; paid_orders: number; paid_rupees: number };

export default async function AmcRevenueByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_by_state");
  if (error) throw new Error(`founder_amc_revenue_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospital_cnt)}</span> },
    { key: "o", header: "Paid orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paid_orders)}</span> },
    { key: "r", header: "Paid (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.paid_rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue by state (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 states by 90d AMC paid revenue</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No paid orders." />
    </div>
  );
}
