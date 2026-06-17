import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Top hospitals (90d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hospital_user_id: string; display_name: string; jobs_posted: number; jobs_completed: number; gross_rupees: number; has_active_amc: boolean };

export default async function TopHospitals90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_hospitals_90d");
  if (error) throw new Error(`founder_top_hospitals_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed)}</span> },
    { key: "g", header: "Gross (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.gross_rupees)}</span> },
    { key: "a", header: "AMC",
      render: (r) => r.has_active_amc
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top hospitals (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 hospitals by 90d posts · AMC flag</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No active hospitals." />
    </div>
  );
}
