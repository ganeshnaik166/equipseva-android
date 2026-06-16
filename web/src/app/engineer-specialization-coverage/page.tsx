import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer specialization coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { category: string; verified_cnt: number; total_cnt: number };

export default async function EngineerSpecializationCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_specialization_coverage");
  if (error) throw new Error(`founder_engineer_specialization_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "Category", render: (r) => <span className="text-xs">{r.category}</span> },
    { key: "v", header: "Verified",
      render: (r) => {
        const tone = r.verified_cnt < 3 ? "text-[var(--color-danger)]"
          : r.verified_cnt < 10 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.verified_cnt)}</span>;
      }
    },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.total_cnt)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer specialization coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">categories ranked by verified engineer count</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.category} emptyMessage="No data." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Red = &lt;3 verified engineers (single-point-of-failure). Yellow = 3-9. Green = 10+.
      </section>
    </div>
  );
}
