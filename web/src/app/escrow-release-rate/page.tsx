import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow release rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; completed_jobs: number; with_release: number; release_pct: number };

export default async function EscrowReleaseRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_release_rate");
  if (error) throw new Error(`founder_escrow_release_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "c", header: "Completed jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed_jobs)}</span> },
    { key: "r", header: "With release", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.with_release)}</span> },
    { key: "p", header: "Release %",
      render: (r) => {
        const tone = r.release_pct < 70 ? "text-[var(--color-danger)]"
          : r.release_pct < 90 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.release_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow release rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of completed jobs whose escrow has been released · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No completed jobs." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Below 90% = completed jobs sitting in escrow limbo. Drill into <a href="/escrow-aging" className="underline">/escrow-aging</a> for the stuck ones.
      </section>
    </div>
  );
}
