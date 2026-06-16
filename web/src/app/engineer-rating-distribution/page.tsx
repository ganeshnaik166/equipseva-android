import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer rating distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { rating_bucket: string; cnt: number };

export default async function EngineerRatingDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_rating_distribution");
  if (error) throw new Error(`founder_engineer_rating_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const noRating = rows.find((r) => r.rating_bucket.startsWith("(no"))?.cnt ?? 0;
  const lowRating = rows.filter((r) => r.rating_bucket.startsWith("1") || r.rating_bucket.startsWith("2")).reduce((s, r) => s + r.cnt, 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket",
      render: (r) => {
        const tone = r.rating_bucket.startsWith("5") ? "text-[var(--color-ok)]"
          : r.rating_bucket.startsWith("1") || r.rating_bucket.startsWith("2") ? "text-[var(--color-danger)]"
          : r.rating_bucket.startsWith("(no") ? "text-[var(--color-muted)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.rating_bucket}</span>;
      }
    },
    { key: "c", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer rating distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">last 180d completed jobs</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="180d completed" value={formatNumber(total)} />
          <StatCard label="No rating" value={formatNumber(noRating)} subtext={total === 0 ? "—" : `${((noRating / total) * 100).toFixed(1)}% silent`} tone="warn" />
          <StatCard label="1-2 stars" value={formatNumber(lowRating)} subtext={total === 0 ? "—" : `${((lowRating / total) * 100).toFixed(1)}%`} tone={lowRating > 0 ? "danger" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.rating_bucket} emptyMessage="No completed jobs." />
    </div>
  );
}
