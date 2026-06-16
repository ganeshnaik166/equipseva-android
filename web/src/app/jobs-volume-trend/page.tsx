import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs volume trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; jobs_posted: number; jobs_completed: number; gross_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function JobsVolumeTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_volume_trend");
  if (error) throw new Error(`founder_jobs_volume_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const posted14d = rows.reduce((s, r) => s + r.jobs_posted, 0);
  const done14d = rows.reduce((s, r) => s + r.jobs_completed, 0);
  const gross14d = rows.reduce((s, r) => s + Number(r.gross_rupees), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.jobs_completed)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.gross_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs volume trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="14d posted" value={formatNumber(posted14d)} />
          <StatCard label="14d completed" value={formatNumber(done14d)} subtext={posted14d === 0 ? "—" : `${((done14d / posted14d) * 100).toFixed(1)}% of posted`} tone="ok" />
          <StatCard label="14d gross" value={inr(gross14d)} />
          <StatCard label="Daily avg posted" value={(posted14d / 14).toFixed(1)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No jobs." />
    </div>
  );
}
