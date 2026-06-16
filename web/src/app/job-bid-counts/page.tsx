import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Job bid counts — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number };

export default async function JobBidCountsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_job_bid_counts");
  if (error) throw new Error(`founder_job_bid_counts: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const zeroBids = rows.find((r) => r.bucket === "0 bids")?.cnt ?? 0;
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket",
      render: (r) => {
        const tone = r.bucket === "0 bids" ? "text-[var(--color-danger)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.bucket}</span>;
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
        <h1 className="text-xl font-semibold">Job bid counts</h1>
        <span className="text-xs text-[var(--color-muted)]">30d jobs · bids received distribution</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Posted (30d)" value={formatNumber(total)} />
          <StatCard label="No bids" value={formatNumber(zeroBids)} subtext={total === 0 ? "—" : `${((zeroBids / total) * 100).toFixed(1)}% lonely`} tone={zeroBids / Math.max(total, 1) > 0.2 ? "danger" : "warn"} />
          <StatCard label="Got bids" value={formatNumber(total - zeroBids)} subtext={total === 0 ? "—" : `${(((total - zeroBids) / total) * 100).toFixed(1)}%`} tone="ok" />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No jobs." />
    </div>
  );
}
