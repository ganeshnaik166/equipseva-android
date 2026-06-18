import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Hospital leaderboard 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hospital_name: string;
  jobs_posted: number;
  jobs_completed: number;
  total_spend_inr: number;
  amc_count: number;
  last_active_at: string | null;
};

export default async function HospitalLeaderboard30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_leaderboard_30d");
  if (error) throw new Error(`founder_hospital_leaderboard_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-medium">{r.hospital_name}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.jobs_completed)}</span> },
    { key: "s", header: "Spend", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_spend_inr))}</span> },
    { key: "a", header: "AMCs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_count)}</span> },
    { key: "l", header: "Last active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_active_at ? formatRelativeTime(r.last_active_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital leaderboard (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 hospitals by 30d jobs posted · demand-side cockpit · pairs with /engineer-leaderboard-30d
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_name} emptyMessage="No hospital activity in last 30d." />
    </div>
  );
}
