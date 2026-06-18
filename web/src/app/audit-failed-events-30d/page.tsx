import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Audit failed events 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  created_at: string;
  actor_email: string;
  op_name: string;
  target_table: string;
  reason: string;
  age_h: number;
};

export default async function AuditFailedEvents30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_failed_events_30d");
  if (error) throw new Error(`founder_audit_failed_events_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatRelativeTime(r.created_at)}</span> },
    { key: "a", header: "Actor", render: (r) => <span className="text-xs font-mono">{r.actor_email}</span> },
    { key: "o", header: "Op", render: (r) => <span className="text-xs font-mono">{r.op_name}</span> },
    { key: "tbl", header: "Table", render: (r) => <span className="text-xs font-mono">{r.target_table}</span> },
    { key: "r", header: "Reason", render: (r) => <span className="text-xs">{r.reason}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit failed events (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 100 most recent failed founder/admin actions · security + reliability signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.created_at}-${r.op_name}`} emptyMessage="No failed actions in last 30 days." />
    </div>
  );
}
