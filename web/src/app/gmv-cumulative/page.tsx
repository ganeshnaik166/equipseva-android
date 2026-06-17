import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "GMV cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; monthly_gmv: number; cumulative_gmv: number; monthly_jobs: number; cumulative_jobs: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function GmvCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_gmv_cumulative");
  if (error) throw new Error(`founder_gmv_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "g", header: "GMV (month)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_gmv))}</span> },
    { key: "cg", header: "Cum GMV", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.cumulative_gmv))}</span> },
    { key: "j", header: "Jobs (month)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.monthly_jobs)}</span> },
    { key: "cj", header: "Cum jobs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cumulative_jobs)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">GMV cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative gross + jobs completed</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No completed jobs." />
    </div>
  );
}
