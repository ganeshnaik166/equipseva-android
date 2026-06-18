import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Monthly revenue summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; jobs_gross: number; amc_paid: number; parts_revenue: number; total: number };

export default async function MonthlyRevenueSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_monthly_revenue_summary");
  if (error) throw new Error(`founder_monthly_revenue_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total12mo = rows.reduce((n, r) => n + (r.total ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "j", header: "Jobs (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_gross)}</span> },
    { key: "a", header: "AMC (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_paid)}</span> },
    { key: "p", header: "Parts (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.parts_revenue)}</span> },
    { key: "t", header: "Total (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Monthly revenue summary (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month total ₹{formatNumber(total12mo)} · jobs + AMC + parts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No revenue." />
    </div>
  );
}
