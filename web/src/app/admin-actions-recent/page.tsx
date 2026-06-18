import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Admin actions recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  created_at: string;
  actor_email: string;
  op_name: string;
  target_table: string;
  target_row_id: string | null;
  outcome: string;
  reason: string;
};

export default async function AdminActionsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_admin_actions_recent");
  if (error) throw new Error(`founder_admin_actions_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatRelativeTime(r.created_at)}</span> },
    { key: "a", header: "Actor", render: (r) => <span className="text-xs font-mono">{r.actor_email}</span> },
    { key: "o", header: "Op", render: (r) => <span className="text-xs font-mono">{r.op_name}</span> },
    { key: "t", header: "Table", render: (r) => <span className="text-xs font-mono text-[var(--color-muted)]">{r.target_table}</span> },
    { key: "out", header: "Outcome", render: (r) => <span className={`text-xs font-medium ${r.outcome === "success" ? "text-[var(--color-ok)]" : r.outcome === "failed" ? "text-[var(--color-danger)]" : ""}`}>{r.outcome}</span> },
    { key: "r", header: "Reason", render: (r) => <span className="text-xs">{r.reason}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Admin actions recent</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 100 most recent founder/admin actions · live governance feed
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.created_at}-${r.op_name}`} emptyMessage="No founder actions logged yet." />
    </div>
  );
}
