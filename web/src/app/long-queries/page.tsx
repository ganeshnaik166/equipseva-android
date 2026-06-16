import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Long-running queries — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  pid: number;
  application_name: string;
  state: string;
  wait_event_type: string | null;
  wait_event: string | null;
  query_start: string;
  age_seconds: number;
  query: string;
};

function ageTone(s: number) {
  if (s >= 60) return "text-[var(--color-danger)]";
  if (s >= 30) return "text-[var(--color-warn)]";
  return "text-[var(--color-muted)]";
}

function stateTone(state: string) {
  switch (state) {
    case "active":
      return "bg-blue-50 text-blue-700";
    case "idle in transaction":
      return "bg-red-50 text-[var(--color-danger)]";
    case "idle in transaction (aborted)":
      return "bg-red-100 text-[var(--color-danger)]";
    default:
      return "bg-gray-100";
  }
}

export default async function LongQueriesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_long_running_queries");
  if (error) throw new Error(`founder_long_running_queries: ${error.message}`);

  const rows = (data ?? []) as Row[];
  const stuck = rows.filter((r) => r.age_seconds >= 60).length;
  const idleInTxn = rows.filter((r) => r.state?.startsWith("idle in transaction")).length;
  const waiting = rows.filter((r) => r.wait_event_type && r.wait_event_type !== "Activity").length;

  const cols: Column<Row>[] = [
    {
      key: "pid",
      header: "PID",
      render: (r) => <span className="text-xs tabular-nums">{r.pid}</span>,
    },
    {
      key: "app",
      header: "App",
      render: (r) => <span className="text-xs">{r.application_name}</span>,
    },
    {
      key: "started",
      header: "Started",
      render: (r) => (
        <span className="text-xs" title={r.query_start}>
          {formatRelativeTime(r.query_start)}
        </span>
      ),
    },
    {
      key: "age",
      header: "Age",
      render: (r) => (
        <span className={`text-xs tabular-nums font-semibold ${ageTone(r.age_seconds)}`}>
          {r.age_seconds}s
        </span>
      ),
    },
    {
      key: "state",
      header: "State",
      render: (r) => (
        <span className={`rounded px-1.5 py-0.5 text-xs ${stateTone(r.state)}`}>
          {r.state}
        </span>
      ),
    },
    {
      key: "wait",
      header: "Wait",
      render: (r) =>
        r.wait_event_type ? (
          <span className="text-xs">
            {r.wait_event_type} / {r.wait_event ?? "—"}
          </span>
        ) : (
          <span className="text-xs text-[var(--color-muted)]">—</span>
        ),
    },
    {
      key: "query",
      header: "Query",
      render: (r) => (
        <pre className="max-w-2xl overflow-x-auto whitespace-pre-wrap break-words rounded bg-gray-50 px-2 py-1 text-[10px] leading-snug text-[var(--color-fg)]">
          {r.query}
        </pre>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Long-running queries</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} queries running &gt;5s · sorted by age (oldest first)
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Active &gt;5s"
            value={formatNumber(rows.length)}
            tone={rows.length > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Stuck &gt;60s"
            value={formatNumber(stuck)}
            tone={stuck > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="Idle in transaction"
            value={formatNumber(idleInTxn)}
            tone={idleInTxn > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="Waiting on lock/IO"
            value={formatNumber(waiting)}
            tone={waiting > 0 ? "warn" : "ok"}
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => String(r.pid)}
        emptyMessage="No queries running over 5 seconds. (This is a snapshot — refresh for newer state.)"
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r604 ops view.</strong> Founder-only SECDEF wrapper over
        pg_stat_activity. Filters: query_start IS NOT NULL · state &lt;&gt; idle
        · age &gt; 5s · self-excluded. Query text truncated to 500 chars to keep
        responses small — SSH for the full plan. &quot;idle in transaction&quot;
        is the most dangerous state: a session holding locks while doing
        nothing. Cancel via <code>pg_cancel_backend(pid)</code> or
        <code>pg_terminate_backend(pid)</code> from psql.
      </section>
    </div>
  );
}
