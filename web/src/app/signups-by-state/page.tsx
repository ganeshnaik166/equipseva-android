import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups by state — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { state: string; total_90d: number; engineers_90d: number; hospitals_90d: number };

export default async function SignupsByStatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_by_state");
  if (error) throw new Error(`founder_signups_by_state: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "State", render: (r) => <span className="text-xs">{r.state}</span> },
    { key: "t", header: "Signups (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_90d)}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers_90d)}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups by state (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 40 states by 90d new accounts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.state} emptyMessage="No signups." />
    </div>
  );
}
