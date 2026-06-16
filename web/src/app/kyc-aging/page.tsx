import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "KYC aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  pending_count: number;
  rejected_count: number;
  oldest_age_days: number;
};

export default async function KycAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_kyc_aging");
  if (error) throw new Error(`founder_kyc_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalPending = rows.reduce((s, r) => s + (r.pending_count ?? 0), 0);
  const totalRejected = rows.reduce((s, r) => s + (r.rejected_count ?? 0), 0);
  const stuck = rows.filter((r) => r.bucket === ">30d" || r.bucket === "7-30d")
    .reduce((s, r) => s + (r.pending_count ?? 0), 0);
  const cols: Column<Row>[] = [
    {
      key: "b",
      header: "Age",
      render: (r) => {
        const tone =
          r.bucket === ">30d"
            ? "bg-red-100 text-[var(--color-danger)]"
            : r.bucket === "7-30d"
              ? "bg-orange-100"
              : r.bucket === "3-7d"
                ? "bg-yellow-50"
                : "bg-gray-50";
        return <span className={`rounded px-1.5 py-0.5 text-xs font-semibold ${tone}`}>{r.bucket}</span>;
      },
    },
    { key: "p", header: "Pending", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.pending_count)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.rejected_count)}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{r.oldest_age_days}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">KYC aging</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineer KYC funnel</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Total pending" value={formatNumber(totalPending)} tone={totalPending > 0 ? "warn" : "ok"} />
          <StatCard label="Stuck >7d" value={formatNumber(stuck)} tone={stuck > 0 ? "danger" : "ok"} />
          <StatCard label="Total rejected" value={formatNumber(totalRejected)} />
          <StatCard label="Oldest stuck" value={rows[0] ? `${rows[0].oldest_age_days}d` : "—"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No pending/rejected KYC." />
    </div>
  );
}
