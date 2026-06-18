import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Engineer leaderboard 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_name: string;
  city: string;
  completed_jobs: number;
  total_earnings_inr: number;
  avg_rating: number;
  tier: string;
};

export default async function EngineerLeaderboard30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_leaderboard_30d");
  if (error) throw new Error(`founder_engineer_leaderboard_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs font-medium">{r.engineer_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "j", header: "Jobs done", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed_jobs)}</span> },
    { key: "e", header: "Earnings", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_earnings_inr))}</span> },
    { key: "r", header: "Avg rating", render: (r) => <span className="text-xs tabular-nums">{Number(r.avg_rating).toFixed(2)}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-mono uppercase">{r.tier}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer leaderboard (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 engineers by completed-job count (tiebreak: earnings) · supply-side cockpit
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.engineer_name}-${r.city}`} emptyMessage="No completed jobs in last 30d." />
    </div>
  );
}
