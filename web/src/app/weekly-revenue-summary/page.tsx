import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Weekly revenue summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; jobs_gross: number; amc_paid: number; parts_revenue: number; total: number };

export default async function WeeklyRevenueSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_weekly_revenue_summary");
  if (error) throw new Error(`founder_weekly_revenue_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total13wk = rows.reduce((n, r) => n + (r.total ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week start", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "j", header: "Jobs gross (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_gross)}</span> },
    { key: "a", header: "AMC paid (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_paid)}</span> },
    { key: "p", header: "Parts (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.parts_revenue)}</span> },
    { key: "t", header: "Total (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Weekly revenue summary (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">13-week total ₹{formatNumber(total13wk)} · jobs + AMC + parts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No revenue." />
    </div>
  );
}
