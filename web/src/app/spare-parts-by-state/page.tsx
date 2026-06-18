import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; buyers: number; orders_90d: number; rupees_90d: number };

export default async function SparePartsByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_by_state");
  if (error) throw new Error(`founder_spare_parts_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "b", header: "Buyers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.buyers)}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders_90d)}</span> },
    { key: "r", header: "Rupees (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.rupees_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts by state (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 states by 90d spare-part order rupees</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No spare part orders." />
    </div>
  );
}
