import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital geo — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; hospital_cnt: number; jobs_30d: number; active_amc_cnt: number };

export default async function HospitalGeoPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_geo");
  if (error) throw new Error(`founder_hospital_geo: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.hospital_cnt)}</span> },
    { key: "j", header: "Jobs 30d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_30d)}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_amc_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital geo</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 cities by hospital count</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No data." />
    </div>
  );
}
