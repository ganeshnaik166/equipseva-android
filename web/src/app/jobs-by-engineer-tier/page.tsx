import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by engineer tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; jobs_90d: number; gross_90d: number; engineers: number; avg_per_engineer: number };

export default async function JobsByEngineerTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_engineer_tier");
  if (error) throw new Error(`founder_jobs_by_engineer_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "j", header: "Jobs 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_90d)}</span> },
    { key: "g", header: "Gross 90d (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.gross_90d)}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers)}</span> },
    { key: "a", header: "Avg/engineer (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.avg_per_engineer)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by engineer tier (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">90d completed jobs rolled up by engineer cert tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No completed jobs." />
    </div>
  );
}
