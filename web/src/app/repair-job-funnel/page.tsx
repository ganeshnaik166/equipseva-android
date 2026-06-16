import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair job funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { stage: string; cnt: number; pct_posted: number };

export default async function RepairJobFunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_job_funnel");
  if (error) throw new Error(`founder_repair_job_funnel: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => <span className="text-xs font-semibold">{r.stage}</span> },
    { key: "c", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "vs posted",
      render: (r) => {
        const isDrop = r.stage.startsWith("X");
        const tone = isDrop
          ? r.pct_posted > 20 ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"
          : r.pct_posted < 30 ? "text-[var(--color-danger)]"
          : r.pct_posted < 60 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{r.pct_posted}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair job funnel</h1>
        <span className="text-xs text-[var(--color-muted)]">30d cohort · cross-stage conversion</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.stage} emptyMessage="No jobs in window." />
    </div>
  );
}
