import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised success rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; completed: number; successful: number; failed: number; success_pct: number };

export default async function SupervisedSuccessRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_success_rate");
  if (error) throw new Error(`founder_supervised_success_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed)}</span> },
    { key: "s", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "p", header: "Success %",
      render: (r) => {
        const tone = r.success_pct < 70 ? "text-[var(--color-danger)]"
          : r.success_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.success_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised success rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% supervised trainee jobs marked successful · 30/90/365d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No completed supervised jobs." />
    </div>
  );
}
