import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs revenue by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; hospital_cnt: number; completed: number; gross_rupees: number };

export default async function JobsRevenueByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_revenue_by_city");
  if (error) throw new Error(`founder_jobs_revenue_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospital_cnt)}</span> },
    { key: "j", header: "Completed jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed)}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.gross_rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs revenue by city (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 cities by 90d completed-jobs gross</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No completed jobs." />
    </div>
  );
}
