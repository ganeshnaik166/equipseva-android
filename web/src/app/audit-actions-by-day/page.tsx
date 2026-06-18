import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Audit actions by day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; actions: number; distinct_ops: number };

export default async function AuditActionsByDayPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_actions_by_day");
  if (error) throw new Error(`founder_audit_actions_by_day: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Day (IST)", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "a", header: "Actions", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.actions)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit actions by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Founder action log volume + variety per day</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No actions." />
    </div>
  );
}
