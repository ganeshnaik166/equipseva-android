import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; new_users: number; cumulative: number };

export default async function SignupsCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_cumulative");
  if (error) throw new Error(`founder_signups_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "n", header: "New users", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.new_users)}</span> },
    { key: "c", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cumulative)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month user base growth</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No signups." />
    </div>
  );
}
