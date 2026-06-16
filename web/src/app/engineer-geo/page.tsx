import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer geo — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; verified_cnt: number; pending_cnt: number; rejected_cnt: number; total_cnt: number };

export default async function EngineerGeoPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_geo");
  if (error) throw new Error(`founder_engineer_geo: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "v", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.verified_cnt)}</span> },
    { key: "p", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending_cnt)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected_cnt)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer geo</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 cities by engineer count</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No engineers." />
    </div>
  );
}
