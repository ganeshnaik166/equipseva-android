import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by engineer 90d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_name: string;
  paged_cnt: number;
  accepted_cnt: number;
  resolved_cnt: number;
};

export default async function CodeRedByEngineer90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_engineer_90d");
  if (error) throw new Error(`founder_code_red_by_engineer_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-medium">{r.engineer_name}</span> },
    { key: "p", header: "Paged", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paged_cnt)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.accepted_cnt)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)] font-semibold">{formatNumber(r.resolved_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by engineer (90d top 50)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top responders to life-safety pages · paged → accepted → resolved funnel per engineer
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_name} emptyMessage="No Code Red activity in last 90d." />
    </div>
  );
}
