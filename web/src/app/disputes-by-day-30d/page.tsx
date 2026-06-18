import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  submitted: number;
  resolved: number;
  open_eod: number;
};

export default async function DisputesByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_by_day_30d");
  if (error) throw new Error(`founder_disputes_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalSubmitted = rows.reduce((a, r) => a + (r.submitted ?? 0), 0);
  const totalResolved = rows.reduce((a, r) => a + (r.resolved ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.submitted)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "o", header: "Open EOD", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.open_eod)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d total: <span className="font-mono tabular-nums">{formatNumber(totalSubmitted)}</span> submitted · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalResolved)}</span> resolved
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No disputes in last 30 days." />
    </div>
  );
}
