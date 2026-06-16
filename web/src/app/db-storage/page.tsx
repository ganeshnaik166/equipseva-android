import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DB storage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  table_name: string;
  est_row_count: number | null;
  total_bytes: number | null;
  total_pretty: string;
  table_bytes: number | null;
  table_pretty: string;
  index_bytes: number | null;
  index_pretty: string;
  // r601 — WoW delta (null when no 7d-old snapshot exists yet)
  prior_bytes?: number | null;
  delta_bytes?: number | null;
  delta_pct?: number | null;
};

export default async function DbStoragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  // r601: prefer the delta RPC which includes WoW columns. Fall back
  // to founder_db_storage if the delta RPC isn't applied yet on this
  // database (defensive against migration ordering).
  const deltaRes = await supabase.rpc("founder_db_storage_with_delta");
  const useDelta = !deltaRes.error;
  const { data, error } = useDelta
    ? deltaRes
    : await supabase.rpc("founder_db_storage");
  if (error) throw new Error(`founder_db_storage: ${error.message}`);

  const rows = (data ?? []) as Row[];

  const totalBytes = rows.reduce((s, r) => s + (r.total_bytes ?? 0), 0);
  const totalIndex = rows.reduce((s, r) => s + (r.index_bytes ?? 0), 0);
  const totalRows = rows.reduce((s, r) => s + (r.est_row_count ?? 0), 0);
  const heaviest = rows[0];

  function prettyBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    const kb = bytes / 1024;
    if (kb < 1024) return `${kb.toFixed(1)} kB`;
    const mb = kb / 1024;
    if (mb < 1024) return `${mb.toFixed(1)} MB`;
    return `${(mb / 1024).toFixed(2)} GB`;
  }

  const cols: Column<Row>[] = [
    {
      key: "table",
      header: "Table",
      render: (r) => <code className="text-xs">{r.table_name}</code>,
    },
    {
      key: "rows",
      header: "Est. rows",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.est_row_count)}</span>
      ),
    },
    {
      key: "total",
      header: "Total size",
      render: (r) => (
        <span className="text-xs tabular-nums font-semibold">{r.total_pretty}</span>
      ),
    },
    {
      key: "table_only",
      header: "Heap",
      render: (r) => <span className="text-xs tabular-nums">{r.table_pretty}</span>,
    },
    {
      key: "index",
      header: "Indexes",
      render: (r) => <span className="text-xs tabular-nums">{r.index_pretty}</span>,
    },
    {
      key: "wow",
      header: "WoW",
      render: (r) => {
        if (r.delta_pct == null) {
          return <span className="text-xs text-[var(--color-muted)]">—</span>;
        }
        const sign = r.delta_pct > 0 ? "+" : "";
        const tone =
          r.delta_pct > 10
            ? "text-[var(--color-danger)]"
            : r.delta_pct > 2
              ? "text-[var(--color-warn)]"
              : r.delta_pct < 0
                ? "text-[var(--color-ok)]"
                : "text-[var(--color-muted)]";
        return (
          <span className={`text-xs tabular-nums ${tone}`}>
            {sign}
            {r.delta_pct}%
          </span>
        );
      },
    },
    {
      key: "ratio",
      header: "Idx %",
      render: (r) => {
        const idx = r.index_bytes ?? 0;
        const tot = r.total_bytes ?? 0;
        if (tot === 0) return <span className="text-xs text-[var(--color-muted)]">—</span>;
        const pct = (idx / tot) * 100;
        const tone =
          pct > 60
            ? "text-[var(--color-danger)]"
            : pct > 40
              ? "text-[var(--color-warn)]"
              : "text-[var(--color-muted)]";
        return (
          <span className={`text-xs tabular-nums ${tone}`}>{pct.toFixed(0)}%</span>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">DB storage</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {rows.length} tables · top {Math.min(rows.length, 100)}
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Public schema total" value={prettyBytes(totalBytes)} />
          <StatCard label="Index footprint" value={prettyBytes(totalIndex)} />
          <StatCard label="Total rows (est)" value={formatNumber(totalRows)} />
          <StatCard
            label="Heaviest table"
            value={heaviest?.total_pretty ?? "—"}
            subtext={heaviest?.table_name}
          />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.table_name}
        emptyMessage="No public tables — fresh database."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r600 + r601 ops view.</strong> Sizes come from{" "}
        <code>pg_total_relation_size</code> (heap + indexes + toast),{" "}
        <code>pg_relation_size</code> (heap only), and the derived index
        footprint. Row counts are <em>estimates</em> from{" "}
        <code>pg_class.reltuples</code> — accurate after the last ANALYZE, may
        lag for write-heavy tables. Idx % &gt; 60% suggests the table has more
        index than data — usually fine for hot read paths but worth checking
        for over-indexing if write throughput drops. WoW % compares current
        total to the most recent snapshot &gt;= 7 days old; r601&apos;s daily sweep
        populates the ledger so this column starts showing values after a
        week of snapshots. — for now the column will be &quot;—&quot; until the
        snapshot edge-fn or pg_cron run begins backfilling history.
      </section>
    </div>
  );
}
