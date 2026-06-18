import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC vs ad-hoc jobs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; amc_jobs: number; adhoc_jobs: number; amc_share_pct: number };

export default async function AmcVsAdhocJobsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_vs_adhoc_monthly");
  if (error) throw new Error(`founder_amc_vs_adhoc_monthly: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "a", header: "AMC jobs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.amc_jobs)}</span> },
    { key: "d", header: "Ad-hoc jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.adhoc_jobs)}</span> },
    { key: "s", header: "AMC share %",
      render: (r) => {
        const tone = r.amc_share_pct >= 40 ? "text-[var(--color-ok)]"
          : r.amc_share_pct >= 20 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.amc_share_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC vs ad-hoc jobs (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Higher AMC share = more contracted volume vs one-off</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No jobs." />
    </div>
  );
}
