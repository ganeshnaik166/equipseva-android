import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts buyer mix — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { buyer_role: string; orders_90d: number; rupees_90d: number; share_pct: number };

export default async function SparePartsBuyerMixPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_buyer_mix");
  if (error) throw new Error(`founder_spare_parts_buyer_mix: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "r", header: "Buyer role", render: (r) => <span className="text-xs font-semibold">{r.buyer_role}</span> },
    { key: "o", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.orders_90d)}</span> },
    { key: "u", header: "Rupees (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.rupees_90d)}</span> },
    { key: "s", header: "Share %", render: (r) => <span className="text-xs tabular-nums">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts buyer mix (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineer vs hospital vs other · who actually buys</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.buyer_role} emptyMessage="No spare part orders." />
    </div>
  );
}
