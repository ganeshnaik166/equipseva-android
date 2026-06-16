import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital AMC coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; hospital_count: number; total_jobs_30d: number; gross_30d_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function HospitalAmcCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_amc_coverage");
  if (error) throw new Error(`founder_hospital_amc_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalH = rows.reduce((s, r) => s + r.hospital_count, 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospital_count)}</span> },
    { key: "s", header: "Share",
      render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{totalH === 0 ? "—" : `${((r.hospital_count / totalH) * 100).toFixed(1)}%`}</span>
    },
    { key: "j", header: "30d jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_jobs_30d)}</span> },
    { key: "g", header: "30d gross", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.gross_30d_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital AMC coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">hospitals with active AMC vs without · 30d activity per bucket</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No data." />
    </div>
  );
}
