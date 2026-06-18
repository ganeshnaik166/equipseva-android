import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Disputes by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  submitted: number;
  resolved: number;
  open_eow: number;
};

export default async function DisputesByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_disputes_by_week_13wk");
  if (error) throw new Error(`founder_disputes_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalSubmitted = rows.reduce((a, r) => a + (r.submitted ?? 0), 0);
  const totalResolved = rows.reduce((a, r) => a + (r.resolved ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.submitted)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "o", header: "Open EOW", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.open_eow)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk total: <span className="font-mono tabular-nums">{formatNumber(totalSubmitted)}</span> submitted · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalResolved)}</span> resolved
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No disputes in last 13 weeks." />
    </div>
  );
}
