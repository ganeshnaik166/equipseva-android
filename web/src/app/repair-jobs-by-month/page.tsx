import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; posted: number; completed: number; cancelled: number; gross_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function RepairJobsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_by_month");
  if (error) throw new Error(`founder_repair_jobs_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.gross_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs by month</h1>
        <span className="text-xs text-[var(--color-muted)]">last 12 months · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No jobs." />
    </div>
  );
}
