import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Audit ops by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  total_ops: number;
  success_cnt: number;
  failed_cnt: number;
  distinct_actors: number;
  distinct_ops: number;
};

export default async function AuditOpsByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_ops_by_day_30d");
  if (error) throw new Error(`founder_audit_ops_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((a, r) => a + (r.total_ops ?? 0), 0);
  const totalFail = rows.reduce((a, r) => a + (r.failed_cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_ops)}</span> },
    { key: "s", header: "Success", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.success_cnt)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_cnt)}</span> },
    { key: "a", header: "Actors", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_actors)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit ops by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total 30d ops: <span className="font-mono tabular-nums">{formatNumber(total)}</span> · failed: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(totalFail)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No founder ops in last 30 days." />
    </div>
  );
}
