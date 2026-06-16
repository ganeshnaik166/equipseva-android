import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Index health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type UnusedRow = {
  schemaname: string;
  table_name: string;
  index_name: string;
  index_size: string;
  idx_scan: number;
};

type SeqRow = {
  schemaname: string;
  table_name: string;
  seq_scan: number;
  seq_tup_read: number;
  idx_scan: number;
  idx_tup_fetch: number;
  seq_pct: number;
  table_size: string;
};

export default async function IndexHealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [unusedRes, seqRes] = await Promise.all([
    supabase.rpc("founder_unused_indexes"),
    supabase.rpc("founder_seq_scan_heavy"),
  ]);
  if (unusedRes.error) throw new Error(`founder_unused_indexes: ${unusedRes.error.message}`);
  if (seqRes.error) throw new Error(`founder_seq_scan_heavy: ${seqRes.error.message}`);

  const unused = (unusedRes.data ?? []) as UnusedRow[];
  const seqHeavy = (seqRes.data ?? []) as SeqRow[];

  const unusedCols: Column<UnusedRow>[] = [
    { key: "tbl", header: "Table", render: (r) => <code className="text-xs">{r.table_name}</code> },
    { key: "idx", header: "Index", render: (r) => <code className="text-xs">{r.index_name}</code> },
    { key: "size", header: "Size", render: (r) => <span className="text-xs tabular-nums">{r.index_size}</span> },
    {
      key: "scans",
      header: "Scans",
      render: (r) => (
        <span className="rounded bg-yellow-50 px-1.5 py-0.5 text-xs tabular-nums text-[var(--color-warn)]">
          {formatNumber(r.idx_scan)}
        </span>
      ),
    },
  ];

  const seqCols: Column<SeqRow>[] = [
    { key: "tbl", header: "Table", render: (r) => <code className="text-xs">{r.table_name}</code> },
    {
      key: "seqpct",
      header: "Seq %",
      render: (r) => {
        const tone =
          r.seq_pct >= 90
            ? "bg-red-100 text-[var(--color-danger)]"
            : r.seq_pct >= 70
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-gray-100";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs tabular-nums font-semibold ${tone}`}>
            {r.seq_pct}%
          </span>
        );
      },
    },
    { key: "seqs", header: "Seq scans", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.seq_scan)}</span> },
    { key: "tup", header: "Seq tuples read", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.seq_tup_read)}</span> },
    { key: "idxs", header: "Idx scans", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.idx_scan)}</span> },
    { key: "size", header: "Size", render: (r) => <span className="text-xs tabular-nums">{r.table_size}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Index health</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {unused.length} unused indexes · {seqHeavy.length} seq-heavy tables
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard
            label="Unused indexes"
            value={formatNumber(unused.length)}
            tone={unused.length > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Seq-heavy tables"
            value={formatNumber(seqHeavy.length)}
            tone={seqHeavy.length > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="≥90% seq scans"
            value={formatNumber(seqHeavy.filter((s) => s.seq_pct >= 90).length)}
            tone={seqHeavy.some((s) => s.seq_pct >= 90) ? "danger" : "ok"}
          />
          <StatCard
            label="Worst seq table"
            value={seqHeavy[0]?.table_name ?? "—"}
            subtext={seqHeavy[0] ? `${seqHeavy[0].seq_pct}% seq` : undefined}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Unused indexes</h2>
        <p className="mb-2 text-xs text-[var(--color-muted)]">
          PRIMARY + UNIQUE excluded (they enforce constraints). idx_scan resets
          on cluster restart — treat as soft signal for old indexes only.
        </p>
        <DataTable
          columns={unusedCols}
          rows={unused}
          rowKey={(r) => `${r.schemaname}.${r.index_name}`}
          emptyMessage="Every non-constraint index has been scanned at least once."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">Seq-scan-heavy tables</h2>
        <p className="mb-2 text-xs text-[var(--color-muted)]">
          Tables with &gt;100 total scans where sequential dominates index scans —
          candidates for a new index on the predicate column.
        </p>
        <DataTable
          columns={seqCols}
          rows={seqHeavy}
          rowKey={(r) => `${r.schemaname}.${r.table_name}`}
          emptyMessage="No seq-scan-heavy tables — every active table is using its indexes."
        />
      </section>
    </div>
  );
}
