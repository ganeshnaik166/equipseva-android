import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC cancellations recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { amc_contract_id: string; hospital_name: string; tier: string; status: string; monthly_fee: number; end_date: string; updated_at: string };

export default async function AmcCancellationsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_cancellations_recent");
  if (error) throw new Error(`founder_amc_cancellations_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalLostMrr = rows.reduce((n, r) => n + (r.monthly_fee ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.updated_at).toLocaleString()}</span> },
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "i", header: "Tier", render: (r) => <span className="text-xs">{r.tier}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "cancelled" ? "text-[var(--color-danger)]"
          : r.status === "renewal_failed" ? "text-[var(--color-warn)]"
          : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "m", header: "MRR lost (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.monthly_fee)}</span> },
    { key: "e", header: "End date", render: (r) => <span className="text-xs tabular-nums">{r.end_date}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC cancellations recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Total MRR lost ₹{formatNumber(totalLostMrr)} · cancelled/expired/renewal_failed</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.amc_contract_id} emptyMessage="No cancellations." />
    </div>
  );
}
