import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal attempts recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  attempt_id: string;
  amc_contract_id: string;
  hospital_name: string;
  attempt_number: number;
  status: string;
  amount_rupees: number;
  error_message: string | null;
  attempted_at: string;
  resolved_at: string | null;
};

export default async function AmcRenewalAttemptsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_attempts_recent");
  if (error) throw new Error(`founder_amc_renewal_attempts_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Attempted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.attempted_at).toLocaleString()}</span> },
    { key: "h", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "n", header: "Try #", render: (r) => <span className="text-xs tabular-nums">{r.attempt_number}</span> },
    { key: "a", header: "Amount (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amount_rupees)}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "succeeded" ? "text-[var(--color-ok)]"
          : r.status === "failed" ? "text-[var(--color-danger)]"
          : r.status === "abandoned" ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "e", header: "Error", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.error_message?.slice(0, 60) ?? "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal attempts recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 attempts · drill into failures via error column</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.attempt_id} emptyMessage="No renewal attempts." />
    </div>
  );
}
