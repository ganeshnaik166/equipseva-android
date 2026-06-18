import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Audit by actor 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  actor_email: string;
  total_actions: number;
  distinct_ops: number;
  distinct_tables: number;
  success_cnt: number;
  failed_cnt: number;
  last_action_at: string | null;
};

export default async function AuditByActor30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_actor_30d");
  if (error) throw new Error(`founder_audit_by_actor_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "e", header: "Actor", render: (r) => <span className="text-xs font-mono">{r.actor_email}</span> },
    { key: "t", header: "Actions", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_actions)}</span> },
    { key: "o", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
    { key: "tbl", header: "Distinct tables", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_tables)}</span> },
    { key: "s", header: "Success", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.success_cnt)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_cnt)}</span> },
    { key: "l", header: "Last action", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_action_at ? formatRelativeTime(r.last_action_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by actor (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 20 actors by founder_action_log volume · pair with /audit-by-week (r980) for time series
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.actor_email} emptyMessage="No founder actions in last 30 days." />
    </div>
  );
}
