import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; assigned: number; successful: number; failed: number };

export default async function SupervisedByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_by_month");
  if (error) throw new Error(`founder_supervised_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "a", header: "Assigned", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.assigned)}</span> },
    { key: "s", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month supervised assignments trend</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No supervised assignments." />
    </div>
  );
}
