import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DB storage snapshots summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  snapshots_total: number;
  distinct_tables_tracked: number;
  latest_snapshot_at: string | null;
  earliest_snapshot_at: string | null;
  snapshot_age_hours: number;
  live_total_bytes: number;
  live_total_pretty: string;
  live_table_count: number;
  largest_table_name: string | null;
  largest_table_bytes: number;
  largest_table_pretty: string;
  prior_total_bytes_7d: number;
  delta_bytes_7d: number;
  delta_pct_7d: number | null;
  fastest_grower_name: string | null;
  fastest_grower_delta_pct: number | null;
  bloat_candidate_name: string | null;
  bloat_bytes_per_row: number | null;
  snapshots_24h: number;
  snapshots_7d: number;
};

export default async function DbStorageSnapshotsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_db_storage_snapshots_summary");
  if (error) throw new Error(`founder_db_storage_snapshots_summary: ${error.message}`);
  const row = ((data ?? [])[0] ?? {
    snapshots_total: 0,
    distinct_tables_tracked: 0,
    latest_snapshot_at: null,
    earliest_snapshot_at: null,
    snapshot_age_hours: 0,
    live_total_bytes: 0,
    live_total_pretty: "0 bytes",
    live_table_count: 0,
    largest_table_name: null,
    largest_table_bytes: 0,
    largest_table_pretty: "0 bytes",
    prior_total_bytes_7d: 0,
    delta_bytes_7d: 0,
    delta_pct_7d: null,
    fastest_grower_name: null,
    fastest_grower_delta_pct: null,
    bloat_candidate_name: null,
    bloat_bytes_per_row: null,
    snapshots_24h: 0,
    snapshots_7d: 0,
  }) as Row;

  const snapsTotal = Number(row.snapshots_total ?? 0);
  const distinctTables = Number(row.distinct_tables_tracked ?? 0);
  const ageHours = Number(row.snapshot_age_hours ?? 0);
  const liveTotalBytes = Number(row.live_total_bytes ?? 0);
  const liveTotalPretty = row.live_total_pretty ?? "0 bytes";
  const liveTableCount = Number(row.live_table_count ?? 0);
  const largestName = row.largest_table_name ?? "—";
  const largestPretty = row.largest_table_pretty ?? "—";
  const largestShare = liveTotalBytes > 0
    ? (Number(row.largest_table_bytes ?? 0) / liveTotalBytes) * 100
    : 0;
  const deltaBytes = Number(row.delta_bytes_7d ?? 0);
  const deltaPct = row.delta_pct_7d == null ? null : Number(row.delta_pct_7d);
  const fastName = row.fastest_grower_name ?? "—";
  const fastPct = row.fastest_grower_delta_pct == null ? null : Number(row.fastest_grower_delta_pct);
  const bloatName = row.bloat_candidate_name ?? "—";
  const bloatRatio = row.bloat_bytes_per_row == null ? null : Number(row.bloat_bytes_per_row);
  const snaps24h = Number(row.snapshots_24h ?? 0);
  const snaps7d = Number(row.snapshots_7d ?? 0);

  const ageTone = ageHours <= 0
    ? undefined
    : ageHours > 48
      ? "var(--color-danger)"
      : ageHours > 30
        ? "var(--color-warn)"
        : "var(--color-ok)";

  const deltaTone = deltaPct == null
    ? undefined
    : deltaPct >= 20
      ? "var(--color-danger)"
      : deltaPct >= 8
        ? "var(--color-warn)"
        : "var(--color-ok)";

  const fastTone = fastPct == null
    ? undefined
    : fastPct >= 50
      ? "var(--color-danger)"
      : fastPct >= 20
        ? "var(--color-warn)"
        : undefined;

  const formatBytes = (n: number): string => {
    const abs = Math.abs(n);
    if (abs < 1024) return `${n} B`;
    if (abs < 1024 * 1024) return `${(n / 1024).toFixed(1)} kB`;
    if (abs < 1024 * 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(1)} MB`;
    return `${(n / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  };

  const tiles: Array<{ label: string; value: string; sub?: string; tone?: string }> = [
    {
      label: "Live DB size",
      value: liveTotalPretty,
      sub: `${formatNumber(liveTableCount)} public tables`,
    },
    {
      label: "WoW delta",
      value: deltaPct == null ? "—" : `${deltaPct >= 0 ? "+" : ""}${deltaPct.toFixed(2)}%`,
      sub: deltaPct == null ? "no 7-d baseline yet" : `${deltaBytes >= 0 ? "+" : ""}${formatBytes(deltaBytes)}`,
      tone: deltaTone,
    },
    {
      label: "Largest table",
      value: largestPretty,
      sub: `${largestName} · ${largestShare.toFixed(1)}% of DB`,
    },
    {
      label: "Fastest grower (WoW)",
      value: fastPct == null ? "—" : `+${fastPct.toFixed(2)}%`,
      sub: fastName,
      tone: fastTone,
    },
    {
      label: "Bloat candidate",
      value: bloatRatio == null ? "—" : `${formatBytes(Math.round(bloatRatio))}/row`,
      sub: bloatName,
    },
    {
      label: "Snapshot freshness",
      value: ageHours <= 0 ? "—" : ageHours < 48 ? `${ageHours.toFixed(1)} h` : `${(ageHours / 24).toFixed(1)} d`,
      sub: "since last sweep",
      tone: ageTone,
    },
    {
      label: "Snapshots logged",
      value: formatNumber(snapsTotal),
      sub: "90-day retention window",
    },
    {
      label: "Tables tracked",
      value: formatNumber(distinctTables),
      sub: "distinct in ledger",
    },
    {
      label: "Snapshots · 24 h",
      value: formatNumber(snaps24h),
      sub: "expect ~1 sweep/day",
    },
    {
      label: "Snapshots · 7 d",
      value: formatNumber(snaps7d),
      sub: "rolling",
    },
    {
      label: "Prior total (7 d ago)",
      value: row.prior_total_bytes_7d > 0 ? formatBytes(Number(row.prior_total_bytes_7d)) : "—",
      sub: "sum of per-table latest snapshot",
    },
    {
      label: "Avg bytes / table (live)",
      value: liveTableCount > 0 ? formatBytes(Math.round(liveTotalBytes / liveTableCount)) : "—",
      sub: "DB / table count",
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">DB storage snapshots summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Postgres footprint pulse · sweep 03:13 UTC daily · retention 90 d · live=`}
          <span className="font-mono">{liveTotalPretty}</span>
        </span>
      </header>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {tiles.map((t) => (
          <div
            key={t.label}
            className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
          >
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">
              {t.label}
            </div>
            <div
              className="mt-1 text-lg font-semibold tabular-nums"
              style={t.tone ? { color: t.tone } : undefined}
            >
              {t.value}
            </div>
            {t.sub ? (
              <div className="text-[11px] text-[var(--color-muted)] mt-0.5">{t.sub}</div>
            ) : null}
          </div>
        ))}
      </div>

      <p className="text-[11px] text-[var(--color-muted)]">
        {`Live DB size = sum of pg_total_relation_size over public relkind='r'. WoW delta compares live total to sum of per-table latest snapshot taken on/before now-7d. `}
        {`Fastest grower filters to tables that were already ${"≥"} 1 MB to keep % meaningful. Bloat candidate = highest bytes/row among tables with ${"≥"} 100 rows + ${"≥"} 1 MB — often JSONB or large TOAST. `}
        {`Source: public.db_storage_snapshots (r601 ledger, retention 90 d) + live pg_class.`}
      </p>
    </div>
  );
}
