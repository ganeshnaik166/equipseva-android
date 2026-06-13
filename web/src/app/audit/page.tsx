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

export default async function AuditPage({
  searchParams,
}: {
  searchParams?: Promise<{ op?: string; target?: string; days?: string }>;
}) {
  await requireFounder();
  const params = (await searchParams) ?? {};
  const opFilter = params.op?.trim() ?? "";
  const targetFilter = params.target?.trim() ?? "";
  const days = Math.max(1, Math.min(180, Number.parseInt(params.days ?? "30", 10) || 30));

  const supabase = await getSupabaseServerClient();
  // Direct table read — RLS gates SELECT to founders only (r482).
  let query = supabase
    .from("founder_action_log")
    .select(
      "id, actor_user_id, op_name, target_table, target_row_id, before_value, after_value, outcome, reason, created_at",
    )
    .order("created_at", { ascending: false })
    .gte("created_at", new Date(Date.now() - days * 86400 * 1000).toISOString())
    .limit(200);

  if (opFilter.length > 0) {
    query = query.ilike("op_name", `%${opFilter}%`);
  }
  if (targetFilter.length > 0) {
    query = query.eq("target_table", targetFilter);
  }

  const { data, error } = await query;
  if (error) throw new Error(`founder_action_log select: ${error.message}`);
  const rows = (data ?? []) as AuditRow[];

  // Build a quick list of distinct target tables for the chip filter.
  const distinctTargets = Array.from(
    new Set(rows.map((r) => r.target_table).filter((t): t is string => Boolean(t))),
  ).sort();

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
          Founder action audit{" "}
          <span className="text-[var(--color-muted)]">
            ({rows.length} match{rows.length === 1 ? "" : "es"}, last {days}d)
          </span>
        </h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Append-only audit ledger from r482. Every founder/admin SECDEF write logs here. RLS gates
          SELECT to founders only.
        </p>
      </header>

      <form className="flex flex-wrap items-end gap-3 rounded border border-[var(--color-border)] bg-white p-3 text-sm">
        <label className="block">
          <span className="text-xs text-[var(--color-muted)]">Op contains</span>
          <input
            type="text"
            name="op"
            defaultValue={opFilter}
            placeholder="e.g. approve_refund"
            className="mt-1 w-56 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block">
          <span className="text-xs text-[var(--color-muted)]">Target table</span>
          <input
            type="text"
            name="target"
            defaultValue={targetFilter}
            placeholder="e.g. refund_authorization_requests"
            className="mt-1 w-72 rounded border border-[var(--color-border)] px-2 py-1 text-sm"
          />
        </label>
        <label className="block">
          <span className="text-xs text-[var(--color-muted)]">Last N days</span>
          <input
            type="number"
            name="days"
            defaultValue={days}
            min={1}
            max={180}
            className="mt-1 w-24 rounded border border-[var(--color-border)] px-2 py-1 text-sm tabular-nums"
          />
        </label>
        <button
          type="submit"
          className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm font-medium text-white"
        >
          Filter
        </button>
        {(opFilter || targetFilter) && (
          <a
            href="/audit"
            className="rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
          >
            Clear
          </a>
        )}
      </form>

      {distinctTargets.length > 0 && (
        <div className="flex flex-wrap gap-1.5 text-xs">
          <span className="text-[var(--color-muted)]">target tables in result:</span>
          {distinctTargets.map((t) => (
            <a
              key={t}
              href={`/audit?target=${encodeURIComponent(t)}${opFilter ? `&op=${encodeURIComponent(opFilter)}` : ""}`}
              className={`rounded border px-1.5 py-0.5 ${
                t === targetFilter
                  ? "border-[var(--color-fg)] bg-[var(--color-fg)] text-white"
                  : "border-[var(--color-border)] hover:bg-gray-50"
              }`}
            >
              {t}
            </a>
          ))}
        </div>
      )}

      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No actions logged in window." />
    </div>
  );
}
