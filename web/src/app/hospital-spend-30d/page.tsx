import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital spend (30d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hospital_user_id: string; display_name: string; spend_30d_rupees: number; jobs_completed: number; avg_job_rupees: number; has_active_amc: boolean };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function HospitalSpend30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_spend_30d");
  if (error) throw new Error(`founder_hospital_spend_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "s", header: "30d spend", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.spend_30d_rupees))}</span> },
    { key: "j", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed)}</span> },
    { key: "a", header: "Avg / job", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{inr(Number(r.avg_job_rupees))}</span> },
    { key: "amc", header: "AMC?",
      render: (r) => <span className={`text-xs ${r.has_active_amc ? "text-[var(--color-ok)]" : "text-[var(--color-muted)]"}`}>{r.has_active_amc ? "Active" : "—"}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital spend (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 hospitals by 30d completed-job gross</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No completed jobs." />
    </div>
  );
}
