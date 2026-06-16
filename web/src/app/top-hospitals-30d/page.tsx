import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Top hospitals (30d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hospital_user_id: string;
  display_name: string;
  jobs_posted: number;
  jobs_completed: number;
  gross_rupees: number;
  has_active_amc: boolean;
};

export default async function TopHospitalsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_hospitals_30d");
  if (error) throw new Error(`founder_top_hospitals_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalPosted = rows.reduce((s, r) => s + (r.jobs_posted ?? 0), 0);
  const totalCompleted = rows.reduce((s, r) => s + (r.jobs_completed ?? 0), 0);
  const amcCount = rows.filter((r) => r.has_active_amc).length;
  const cols: Column<Row>[] = [
    {
      key: "h", header: "Hospital",
      render: (r) => (
        <Link href={`/hospitals/${r.hospital_user_id}`} className="text-[var(--color-accent)] hover:underline">
          {r.display_name || shortId(r.hospital_user_id)}
        </Link>
      ),
    },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.gross_rupees)}</span> },
    {
      key: "amc", header: "AMC",
      render: (r) => r.has_active_amc
        ? <span className="rounded bg-green-50 px-1.5 py-0.5 text-xs text-[var(--color-ok)]">yes</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>,
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top hospitals (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">top {rows.length} by 30d posts</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Posted (top 25)" value={formatNumber(totalPosted)} />
          <StatCard label="Completed (top 25)" value={formatNumber(totalCompleted)} />
          <StatCard label="AMC-attached" value={`${amcCount}/${rows.length}`} tone={amcCount > 0 ? "ok" : "warn"} />
          <StatCard label="Completion rate" value={totalPosted > 0 ? `${Math.round((totalCompleted / totalPosted) * 100)}%` : "—"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No hospital activity in 30d." />
    </div>
  );
}
