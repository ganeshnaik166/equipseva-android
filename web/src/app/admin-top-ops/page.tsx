import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Admin top ops — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { op_name: string; count_30d: number; count_total: number; last_used_at: string };

export default async function AdminTopOpsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_admin_top_ops");
  if (error) throw new Error(`founder_admin_top_ops: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Op", render: (r) => <span className="text-xs font-mono">{r.op_name}</span> },
    { key: "30", header: "30d uses", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.count_30d)}</span> },
    { key: "t", header: "Lifetime", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.count_total)}</span> },
    { key: "l", header: "Last used", render: (r) => <span className="text-xs">{new Date(r.last_used_at).toLocaleDateString("en-IN")}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Admin top ops</h1>
        <span className="text-xs text-[var(--color-muted)]">most-used founder ops · 30d + lifetime</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.op_name} emptyMessage="No actions." />
    </div>
  );
}
