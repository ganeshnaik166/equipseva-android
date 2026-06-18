import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spare parts by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; total: number; paid: number; pending: number; failed: number; refunded: number };

export default async function SparePartsByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_by_month_by_status");
  if (error) throw new Error(`founder_spare_parts_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid)}</span> },
    { key: "x", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "r", header: "Refunded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.refunded)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Cross-tab of payment_status per creation month</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No spare part orders." />
    </div>
  );
}
