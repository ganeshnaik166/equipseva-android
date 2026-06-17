import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; submitted: number; cum_submitted: number; accepted: number; rejected: number };

export default async function DisputesCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_cumulative");
  if (error) throw new Error(`founder_disputes_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "s", header: "Submitted (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.submitted)}</span> },
    { key: "cs", header: "Cum submitted", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_submitted)}</span> },
    { key: "a", header: "Accepted (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Rejected (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative disputes</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No disputes." />
    </div>
  );
}
