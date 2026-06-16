import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Top engineers (30d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; jobs_completed: number; gross_rupees: number; avg_job_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function TopEngineers30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_engineers_30d");
  if (error) throw new Error(`founder_top_engineers_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "j", header: "Jobs (30d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.gross_rupees))}</span> },
    { key: "a", header: "Avg / job", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{inr(Number(r.avg_job_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top engineers (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 by gross rupees · last 30 days</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No completed jobs." />
    </div>
  );
}
