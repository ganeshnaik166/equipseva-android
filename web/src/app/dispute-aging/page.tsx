import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Dispute aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  submitted_count: number;
  accepted_count: number;
  rejected_count: number;
  oldest_age_days: number;
};

export default async function DisputeAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_aging");
  if (error) throw new Error(`founder_dispute_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const sub = rows.reduce((s, r) => s + (r.submitted_count ?? 0), 0);
  const acc = rows.reduce((s, r) => s + (r.accepted_count ?? 0), 0);
  const rej = rows.reduce((s, r) => s + (r.rejected_count ?? 0), 0);
  const stuck = rows
    .filter((r) => r.bucket === ">30d" || r.bucket === "7-30d")
    .reduce((s, r) => s + (r.submitted_count ?? 0), 0);
  const cols: Column<Row>[] = [
    {
      key: "b", header: "Age",
      render: (r) => {
        const tone = r.bucket === ">30d" ? "bg-red-100 text-[var(--color-danger)]"
          : r.bucket === "7-30d" ? "bg-orange-100"
          : r.bucket === "3-7d" ? "bg-yellow-50" : "bg-gray-50";
        return <span className={`rounded px-1.5 py-0.5 text-xs font-semibold ${tone}`}>{r.bucket}</span>;
      }
    },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.submitted_count)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted_count)}</span> },
    { key: "rj", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.rejected_count)}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{r.oldest_age_days}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute aging</h1>
        <span className="text-xs text-[var(--color-muted)]">Evidence packs by age</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Submitted (open)" value={formatNumber(sub)} tone={sub > 0 ? "warn" : "ok"} />
          <StatCard label="Stuck >7d submitted" value={formatNumber(stuck)} tone={stuck > 0 ? "danger" : "ok"} />
          <StatCard label="Accepted" value={formatNumber(acc)} tone="ok" />
          <StatCard label="Rejected" value={formatNumber(rej)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No open disputes." />
    </div>
  );
}
