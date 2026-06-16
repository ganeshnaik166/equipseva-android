import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Top engineers (7d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_user_id: string;
  display_name: string;
  jobs_completed: number;
  gross_rupees: number;
  avg_job_rupees: number;
};

export default async function TopEngineersPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_engineers_7d");
  if (error) throw new Error(`founder_top_engineers_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalGross = rows.reduce((s, r) => s + (r.gross_rupees ?? 0), 0);
  const totalJobs = rows.reduce((s, r) => s + (r.jobs_completed ?? 0), 0);
  const peak = rows[0];
  const cols: Column<Row>[] = [
    {
      key: "eng", header: "Engineer",
      render: (r) => (
        <Link href={`/engineers/${r.engineer_user_id}`} className="text-[var(--color-accent)] hover:underline">
          {r.display_name || shortId(r.engineer_user_id)}
        </Link>
      ),
    },
    { key: "jobs", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed)}</span> },
    { key: "gross", header: "Gross", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatRupees(r.gross_rupees)}</span> },
    { key: "avg", header: "Avg/job", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.avg_job_rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top engineers (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">top {rows.length} by 7-day gross</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Top 25 gross" value={formatRupees(totalGross)} />
          <StatCard label="Jobs (top 25)" value={formatNumber(totalJobs)} />
          <StatCard label="#1 engineer" value={peak?.display_name ?? "—"} subtext={peak ? formatRupees(peak.gross_rupees) : undefined} />
          <StatCard label="Avg/job (top 25)" value={formatRupees(totalJobs > 0 ? totalGross / totalJobs : 0)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No completed jobs in last 7d." />
    </div>
  );
}
