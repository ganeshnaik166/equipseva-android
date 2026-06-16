import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised outcomes — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; cnt: number; share_pct: number };

export default async function SupervisedOutcomesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_outcomes");
  if (error) throw new Error(`founder_supervised_outcomes: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "completed_successful" ? "text-[var(--color-ok)]"
          : r.status === "completed_failed" ? "text-[var(--color-danger)]"
          : r.status === "declined" || r.status === "revoked" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.share_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised outcomes</h1>
        <span className="text-xs text-[var(--color-muted)]">all-time supervised_job_assignments by status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No supervised assignments." />
    </div>
  );
}
