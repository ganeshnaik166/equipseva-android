import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts by status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; cnt_90d: number; rupees_90d: number };

export default async function SparePartsByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_by_status");
  if (error) throw new Error(`founder_spare_parts_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRevenue = rows.reduce((n, r) => n + (r.rupees_90d ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "s", header: "Status", render: (r) => <span className="text-xs font-semibold">{r.status}</span> },
    { key: "c", header: "Count (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt_90d)}</span> },
    { key: "r", header: "Rupees (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.rupees_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts by status (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total ₹{formatNumber(totalRevenue)} across all statuses</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No spare part orders." />
    </div>
  );
}
