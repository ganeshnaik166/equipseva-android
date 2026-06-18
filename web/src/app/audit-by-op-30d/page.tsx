import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Audit by op 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  op_name: string;
  total: number;
  success_cnt: number;
  failed_cnt: number;
  distinct_actors: number;
  last_called_at: string | null;
};

export default async function AuditByOp30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_op_30d");
  if (error) throw new Error(`founder_audit_by_op_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "o", header: "Op", render: (r) => <span className="text-xs font-mono">{r.op_name}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "s", header: "Success", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.success_cnt)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_cnt)}</span> },
    { key: "a", header: "Actors", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_actors)}</span> },
    { key: "l", header: "Last call", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_called_at ? formatRelativeTime(r.last_called_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by op (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 founder ops by call count · failed-heavy ops = candidates for retry/RPC fix
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.op_name} emptyMessage="No ops in last 30 days." />
    </div>
  );
}
