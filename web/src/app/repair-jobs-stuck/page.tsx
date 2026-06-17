import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs stuck — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; cnt: number; oldest_days: number };

export default async function RepairJobsStuckPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_stuck");
  if (error) throw new Error(`founder_repair_jobs_stuck: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status", render: (r) => <span className="text-xs font-semibold">{r.status}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "o", header: "Oldest (days)",
      render: (r) => {
        const tone = r.oldest_days > 60 ? "text-[var(--color-danger)]"
          : r.oldest_days > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.oldest_days}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs stuck (&gt;14d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Non-terminal jobs older than 14 days · per status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No stuck jobs." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Stuck in 'requested' = unmatched (see <a href="/unmatched-jobs" className="underline">/unmatched-jobs</a>).
        Stuck in 'assigned' = engineer ghosting.
      </section>
    </div>
  );
}
