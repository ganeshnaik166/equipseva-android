import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; paid: number; released: number; refunded: number; disputed: number };

export default async function EscrowByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_by_month_by_status");
  if (error) throw new Error(`founder_escrow_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "p", header: "Paid in", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paid)}</span> },
    { key: "rl", header: "Released", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.released)}</span> },
    { key: "rf", header: "Refunded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refunded)}</span> },
    { key: "d", header: "Disputed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.disputed)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Cross-tab counts: paid-in (created month) · released/refunded/disputed (updated month)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No escrow activity." />
    </div>
  );
}
