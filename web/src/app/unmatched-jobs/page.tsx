import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Unmatched jobs — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { job_id: string; job_number: string; hospital_user_id: string; hospital_name: string; created_at: string; days_open: number; status: string };

export default async function UnmatchedJobsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_unmatched_jobs_7d");
  if (error) throw new Error(`founder_unmatched_jobs_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "j", header: "Job #", render: (r) => <span className="text-xs font-mono">{r.job_number}</span> },
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs">{r.hospital_name}</span> },
    { key: "c", header: "Posted", render: (r) => <span className="text-xs">{new Date(r.created_at).toLocaleDateString("en-IN")}</span> },
    { key: "d", header: "Days open",
      render: (r) => {
        const tone = r.days_open > 30 ? "text-[var(--color-danger)]"
          : r.days_open > 14 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.days_open)}d</span>;
      }
    },
    { key: "s", header: "Status", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.status}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Unmatched jobs</h1>
        <span className="text-xs text-[var(--color-muted)]">posted &gt;7d ago · zero bids · still open</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Unmatched count" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Aged >30d" value={formatNumber(rows.filter((r) => r.days_open > 30).length)} tone="danger" />
          <StatCard label="Oldest" value={`${formatNumber(Math.max(0, ...rows.map((r) => r.days_open)))}d`} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.job_id} emptyMessage="No unmatched jobs." />
    </div>
  );
}
