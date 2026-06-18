import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; requested: number; successful: number; failed: number; declined: number };

export default async function SupervisedByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_by_month_by_status");
  if (error) throw new Error(`founder_supervised_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "r", header: "Requested", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.requested)}</span> },
    { key: "s", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "d", header: "Declined", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.declined)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Monthly trainee assignment funnel keyed by request month</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No supervised assignments." />
    </div>
  );
}
