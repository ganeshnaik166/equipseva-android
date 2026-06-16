import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Job fee distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; total_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function JobFeeDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_job_fee_distribution");
  if (error) throw new Error(`founder_job_fee_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalCount = rows.reduce((s, r) => s + r.cnt, 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{totalCount === 0 ? "—" : `${((r.cnt / totalCount) * 100).toFixed(1)}%`}</span>
    },
    { key: "g", header: "Bucket gross", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.total_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Job fee distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">last-90d completed jobs · grouped by contracted amount</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No completed jobs." />
    </div>
  );
}
