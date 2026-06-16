import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer tenure — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number };

export default async function EngineerTenurePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_tenure");
  if (error) throw new Error(`founder_engineer_tenure: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + r.cnt, 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Tenure", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Verified engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer tenure</h1>
        <span className="text-xs text-[var(--color-muted)]">verified engineers by signup age</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {rows.map((r) => (
            <StatCard key={r.bucket} label={r.bucket} value={formatNumber(r.cnt)} subtext={total === 0 ? "—" : `${((r.cnt / total) * 100).toFixed(1)}%`} />
          ))}
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No engineers." />
    </div>
  );
}
