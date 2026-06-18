import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare part orders recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { order_id: string; order_number: string; buyer_name: string; total_amount: number; payment_status: string; order_status: string; created_at: string };

export default async function SparePartOrdersRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_part_orders_recent");
  if (error) throw new Error(`founder_spare_part_orders_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "o", header: "Order #", render: (r) => <span className="text-xs font-mono">{r.order_number}</span> },
    { key: "n", header: "Buyer", render: (r) => <span className="text-xs">{r.buyer_name}</span> },
    { key: "a", header: "Amount (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_amount)}</span> },
    { key: "p", header: "Payment", render: (r) => <span className="text-xs">{r.payment_status}</span> },
    { key: "s", header: "Order", render: (r) => <span className="text-xs">{r.order_status}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare part orders recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 orders</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.order_id} emptyMessage="No spare part orders." />
    </div>
  );
}
