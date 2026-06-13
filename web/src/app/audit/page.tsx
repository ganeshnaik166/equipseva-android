import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Audit log — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type AuditRow = {
  id: string;
  actor_user_id: string | null;
  actor_email?: string | null;
  op_name: string;
  target_table: string | null;
  target_row_id: string | null;
  before_value: unknown;
  after_value: unknown;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

export default async function AuditPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  // Direct table read — RLS gates SELECT to founders only (r482).
  const { data, error } = await supabase
    .from("founder_action_log")
    .select(
      "id, actor_user_id, op_name, target_table, target_row_id, before_value, after_value, outcome, reason, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw new Error(`founder_action_log select: ${error.message}`);
  const rows = (data ?? []) as AuditRow[];

  const cols: Column<AuditRow>[] = [
    {
      key: "when",
      header: "When",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    {
      key: "actor",
      header: "Actor",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]" title={r.actor_user_id ?? ""}>
          {shortId(r.actor_user_id)}
        </span>
      ),
    },
    {
      key: "target",
      header: "Target",
      render: (r) => (
        <span className="text-xs">
          {r.target_table ?? "—"} <span className="text-[var(--color-muted)]">·</span>{" "}
          <code className="text-xs">{shortId(r.target_row_id)}</code>
        </span>
      ),
    },
    {
      key: "outcome",
      header: "Outcome",
      render: (r) => {
        const o = (r.outcome ?? "").toLowerCase();
        const cls =
          o === "ok" || o === "success"
            ? "bg-green-100 text-[var(--color-ok)]"
            : o === "denied"
              ? "bg-red-100 text-[var(--color-danger)]"
              : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.outcome ?? "—"}</span>;
      },
    },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
    {
      key: "diff",
      header: "Before → After",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <pre className="mt-1 max-w-md overflow-auto text-xs">
            {JSON.stringify({ before: r.before_value, after: r.after_value }, null, 2)}
          </pre>
        </details>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <header>
        <h1 className="text-xl font-semibold">
          Founder action audit <span className="text-[var(--color-muted)]">({rows.length} latest)</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Append-only audit ledger from r482. Every founder/admin SECDEF write logs here. RLS gates SELECT to
          founders only.
        </p>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No actions logged yet." />
    </div>
  );
}
