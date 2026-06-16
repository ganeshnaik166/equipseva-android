import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Escrow aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  bucket: string;
  status: string;
  job_count: number;
  total_rupees: number;
  oldest_age_days: number;
};

export default async function EscrowAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_age_buckets");
  if (error) throw new Error(`founder_escrow_age_buckets: ${error.message}`);

  const rows = (data ?? []) as Row[];
  const totalHeld = rows.reduce((s, r) => s + (r.total_rupees ?? 0), 0);
  const totalJobs = rows.reduce((s, r) => s + (r.job_count ?? 0), 0);
  const over30d = rows
    .filter((r) => r.bucket === "30-90d" || r.bucket === ">90d")
    .reduce((s, r) => s + (r.total_rupees ?? 0), 0);
  const overDispute = rows
    .filter((r) => r.status === "in_dispute")
    .reduce((s, r) => s + (r.total_rupees ?? 0), 0);

  const cols: Column<Row>[] = [
    {
      key: "bucket",
      header: "Age",
      render: (r) => {
        const tone =
          r.bucket === ">90d"
            ? "bg-red-100 text-[var(--color-danger)]"
            : r.bucket === "30-90d"
              ? "bg-orange-100"
              : r.bucket === "7-30d"
                ? "bg-yellow-50"
                : "bg-gray-50";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs font-semibold ${tone}`}>
            {r.bucket}
          </span>
        );
      },
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const tone =
          r.status === "in_dispute"
            ? "bg-red-50 text-[var(--color-danger)]"
            : r.status === "held"
              ? "bg-blue-50"
              : "bg-yellow-50 text-[var(--color-warn)]";
        return (
          <span className={`rounded px-1.5 py-0.5 text-xs ${tone}`}>
            {r.status}
          </span>
        );
      },
    },
    {
      key: "count",
      header: "Jobs",
      render: (r) => (
        <span className="text-xs tabular-nums">{formatNumber(r.job_count)}</span>
      ),
    },
    {
      key: "total",
      header: "Cash held",
      render: (r) => (
        <span className="text-xs tabular-nums font-semibold">
          {formatRupees(r.total_rupees)}
        </span>
      ),
    },
    {
      key: "oldest",
      header: "Oldest",
      render: (r) => (
        <span className="text-xs tabular-nums">{r.oldest_age_days}d</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow aging</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {formatNumber(totalJobs)} jobs · pending + held + in_dispute only
        </span>
      </header>

      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Total held" value={formatRupees(totalHeld)} />
          <StatCard
            label="Stuck >30d"
            value={formatRupees(over30d)}
            tone={over30d > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="In-dispute total"
            value={formatRupees(overDispute)}
            tone={overDispute > 0 ? "danger" : "ok"}
          />
          <StatCard label="Active escrows" value={formatNumber(totalJobs)} />
        </div>
      </section>

      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => `${r.bucket}:${r.status}`}
        emptyMessage="No active escrows — all funds released or refunded."
      />

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r607 ops view.</strong> Buckets compare{" "}
        <code>repair_job_escrow.created_at</code> to now: 0-7d (normal),
        7-30d (slow), 30-90d (stuck — investigate), &gt;90d (critical —
        usually a forgotten dispute or abandoned hospital). Only{" "}
        <code>pending / held / in_dispute</code> rows counted; released /
        refunded / cancelled excluded. Each row is bucket × status so you
        can see &quot;&gt;90d in_dispute&quot; separately from &quot;&gt;90d held&quot;.
      </section>
    </div>
  );
}
