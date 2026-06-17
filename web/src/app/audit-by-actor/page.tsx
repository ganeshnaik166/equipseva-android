import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Audit by actor — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { actor_user_id: string; actor_email: string; display_name: string; ops_30d: number; distinct_ops: number; last_op_at: string };

export default async function AuditByActorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_actor");
  if (error) throw new Error(`founder_audit_by_actor: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Actor", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "e", header: "Email", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.actor_email}</span> },
    { key: "o", header: "Ops (30d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.ops_30d)}</span> },
    { key: "d", header: "Distinct ops", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_ops)}</span> },
    { key: "l", header: "Last op", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.last_op_at).toLocaleString()}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by actor (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 actors by founder_action_log volume</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.actor_user_id} emptyMessage="No audit events." />
    </div>
  );
}
