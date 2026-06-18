import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; hospital_cnt: number; jobs_90d: number; gross_rupees: number; active_amc_cnt: number };

export default async function JobsByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_state");
  if (error) throw new Error(`founder_jobs_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospital_cnt)}</span> },
    { key: "j", header: "Jobs 90d", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.jobs_90d)}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.gross_rupees)}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_amc_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by state (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 IndiaLocations states · hospitals + jobs + AMC count</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No state data." />
    </div>
  );
}
