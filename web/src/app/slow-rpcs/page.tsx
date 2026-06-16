import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Slow RPCs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  query_fingerprint: string;
  calls: number;
  total_exec_time_ms: number;
  mean_exec_time_ms: number;
  rows_returned: number;
};

export default async function SlowRpcsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_slow_rpcs");
  if (error) throw new Error(`founder_slow_rpcs: ${error.message}`);

  const rows = (data ?? []) as Row[];
  const extEnabled = rows.length > 0;

  const totalCalls = rows.reduce((s, r) => s + (r.calls ?? 0), 0);
  const totalTime = rows.reduce((s, r) => s + (r.total_exec_time_ms ?? 0), 0);
  const slowestMean = rows.reduce((acc, r) => Math.max(acc, r.mean_exec_time_ms ?? 0), 0);

  const cols: Column<Row>[] = [
    {
      key: "q",
      header: "Query",
      render: (r) => (
        <code className="block max-w-2xl overflow-x-auto whitespace-pre-wrap break-words text-[10px] leading-snug">
          {r.query_fingerprint}
        </code>
      ),
    },
    {
      key: "calls",
      header: "Calls",
      render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.calls)}</span>,
    },
    {
      key: "mean",
      header: "Mean (ms)",
      render: (r) => {
        const tone =
          r.mean_exec_time_ms > 500
            ? "text-[var(--color-danger)]"
            : r.mean_exec_time_ms > 100
              ? "text-[var(--color-warn)]"
              : "text-[var(--color-muted)]";
        return (
          <span className={`text-xs tabular-nums font-semibold ${tone}`}>
            {r.mean_exec_time_ms}
          </span>
        );
      },
    },
    {
      key: "total",
      header: "Total (s)",
      render: (r) => (
        <span className="text-xs tabular-nums">
          {(r.total_exec_time_ms / 1000).toFixed(2)}
        </span>
      ),
    },
    {
      key: "rows",
      header: "Rows",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.rows_returned)}</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Slow RPCs</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {extEnabled ? `top ${rows.length} by total wall-clock` : "pg_stat_statements not enabled"}
        </span>
      </header>

      {extEnabled ? (
        <>
          <section>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <StatCard label="Queries (top 50)" value={formatNumber(rows.length)} />
              <StatCard label="Total calls" value={formatNumber(totalCalls)} />
              <StatCard
                label="Total wall-clock (s)"
                value={(totalTime / 1000).toFixed(1)}
              />
              <StatCard
                label="Slowest mean (ms)"
                value={`${slowestMean}`}
                tone={slowestMean > 500 ? "danger" : slowestMean > 100 ? "warn" : "ok"}
              />
            </div>
          </section>

          <DataTable
            columns={cols}
            rows={rows}
            rowKey={(r) => r.query_fingerprint.slice(0, 80)}
            emptyMessage="No RPC calls with >5 invocations recorded yet."
          />

          <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
            <strong>r610 ops view.</strong> Reads pg_stat_statements totals
            (wall-clock per query × calls). Tones: mean &gt; 500ms danger,
            &gt; 100ms warn. Self-excluded + LIMIT 50 by total_exec_time
            DESC + calls &gt; 5 filter. Query text truncated to 200 chars —
            psql for the full plan.
          </section>
        </>
      ) : (
        <section className="rounded border border-[var(--color-border)] bg-yellow-50 p-4">
          <h2 className="text-sm font-semibold text-[var(--color-warn)]">
            pg_stat_statements not enabled
          </h2>
          <p className="mt-2 text-sm text-[var(--color-muted)]">
            Enable from the Supabase dashboard (Database → Extensions →
            pg_stat_statements). Once on, this page surfaces the top 50 RPCs
            by total wall-clock time so the founder can spot performance
            hotspots before they cause outages.
          </p>
        </section>
      )}
    </div>
  );
}
