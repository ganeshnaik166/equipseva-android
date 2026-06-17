import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Verified engineer growth — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; new_verified: number; cumulative: number };

export default async function VerifiedEngineerGrowthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_verified_engineer_growth");
  if (error) throw new Error(`founder_verified_engineer_growth: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "n", header: "New verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.new_verified)}</span> },
    { key: "c", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cumulative)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Verified engineer growth</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month verified engineer cumulative base</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No engineers." />
    </div>
  );
}
