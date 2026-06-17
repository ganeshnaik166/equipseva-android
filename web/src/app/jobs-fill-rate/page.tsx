import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs fill rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; posted: number; bid_within_7d: number; fill_pct: number };

export default async function JobsFillRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_fill_rate");
  if (error) throw new Error(`founder_jobs_fill_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "b", header: "Bid within 7d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bid_within_7d)}</span> },
    { key: "f", header: "Fill %",
      render: (r) => {
        const tone = r.fill_pct < 50 ? "text-[var(--color-danger)]"
          : r.fill_pct < 80 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.fill_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs fill rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of posted jobs that got ≥1 bid within 7 days · marketplace liquidity</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No jobs." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Excludes jobs posted less than 7d ago (haven&apos;t had their full bid window yet). Companion to <a href="/unmatched-jobs" className="underline">/unmatched-jobs</a> list. Below 80% = supply gap.
      </section>
    </div>
  );
}
