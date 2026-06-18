import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Audit by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; actions: number; distinct_ops: number; distinct_actors: number };

export default async function AuditByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_week");
  if (error) throw new Error(`founder_audit_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week start", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "a", header: "Actions", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.actions)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
    { key: "u", header: "Distinct actors", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_actors)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">Founder workload trend — manual ops volume per week</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No actions." />
    </div>
  );
}
