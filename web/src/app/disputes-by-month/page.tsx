import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; submitted: number; accepted: number; rejected: number };

export default async function DisputesByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_by_month");
  if (error) throw new Error(`founder_disputes_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.submitted)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month trend of submitted/accepted/rejected</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No disputes." />
    </div>
  );
}
