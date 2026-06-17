import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Dispute resolution rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; submitted: number; resolved: number; pending: number; resolution_pct: number };

export default async function DisputeResolutionRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_resolution_rate");
  if (error) throw new Error(`founder_dispute_resolution_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.submitted)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "p", header: "Pending", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.pending)}</span> },
    { key: "x", header: "Resolution %",
      render: (r) => {
        const tone = r.resolution_pct < 60 ? "text-[var(--color-danger)]"
          : r.resolution_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.resolution_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute resolution rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of disputes mediator has decided · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No disputes." />
    </div>
  );
}
