import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs vs AMC revenue — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; jobs_gross: number; amc_paid_rupees: number; total_rupees: number; amc_share_pct: number };

export default async function JobsVsAmcRevenuePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_vs_amc_revenue_monthly");
  if (error) throw new Error(`founder_jobs_vs_amc_revenue_monthly: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "j", header: "Jobs gross (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_gross)}</span> },
    { key: "a", header: "AMC paid (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_paid_rupees)}</span> },
    { key: "t", header: "Total (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_rupees)}</span> },
    { key: "s", header: "AMC share %",
      render: (r) => {
        const tone = r.amc_share_pct >= 50 ? "text-[var(--color-ok)]"
          : r.amc_share_pct >= 25 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.amc_share_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs vs AMC revenue (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Higher AMC share % = more recurring revenue vs transactional</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No revenue." />
    </div>
  );
}
