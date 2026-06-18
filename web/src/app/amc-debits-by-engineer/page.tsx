import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC debits by engineer — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; visit_count_90d: number; total_debit_rupees: number };

export default async function AmcDebitsByEngineerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_debits_by_engineer");
  if (error) throw new Error(`founder_amc_debits_by_engineer: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "v", header: "AMC visits (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.visit_count_90d)}</span> },
    { key: "d", header: "Total debit (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_debit_rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC debits by engineer (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 engineers consuming AMC pool credits via visits</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No AMC visits." />
    </div>
  );
}
