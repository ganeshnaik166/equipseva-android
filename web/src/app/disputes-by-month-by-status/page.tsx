import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; submitted: number; accepted: number; rejected: number; pending: number };

export default async function DisputesByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_by_month_by_status");
  if (error) throw new Error(`founder_disputes_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.submitted)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</span> },
    { key: "p", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Submitted (by submit month) · accepted/rejected (by decision month) · pending (unfinished)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No disputes." />
    </div>
  );
}
