import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Audit by table 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  target_table: string;
  total: number;
  distinct_ops: number;
  distinct_actors: number;
  distinct_rows: number;
  last_touched_at: string | null;
};

export default async function AuditByTable30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_table_30d");
  if (error) throw new Error(`founder_audit_by_table_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Table", render: (r) => <span className="text-xs font-mono">{r.target_table}</span> },
    { key: "tot", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
    { key: "a", header: "Distinct actors", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_actors)}</span> },
    { key: "r", header: "Distinct rows", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_rows)}</span> },
    { key: "l", header: "Last touched", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_touched_at ? formatRelativeTime(r.last_touched_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by table (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 tables by mutation count · completes audit trio (actor/op/table)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.target_table} emptyMessage="No mutations in last 30 days." />
    </div>
  );
}
