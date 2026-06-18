import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "City coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  city: string;
  engineers_total: number;
  engineers_verified: number;
  hospitals_total: number;
  jobs_90d: number;
  amcs_active: number;
};

export default async function CityCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_city_coverage");
  if (error) throw new Error(`founder_city_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs font-medium">{r.city}</span> },
    { key: "et", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers_total)}</span> },
    { key: "ev", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineers_verified)}</span> },
    { key: "ht", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals_total)}</span> },
    { key: "j", header: "Jobs 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_90d)}</span> },
    { key: "a", header: "AMCs active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.amcs_active)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">City coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 cities · supply (engineers) + demand (hospitals) + activity (jobs/AMCs) · geographic expansion signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No city data." />
    </div>
  );
}
