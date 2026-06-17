import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pending by hospital — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hospital_user_id: string; display_name: string; city: string; pending_orders: number; pending_rupees: number; oldest_days: number };

export default async function AmcPendingByHospitalPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pending_by_hospital");
  if (error) throw new Error(`founder_amc_pending_by_hospital: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "c", header: "City", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.city}</span> },
    { key: "o", header: "Pending orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.pending_orders)}</span> },
    { key: "r", header: "Pending (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.pending_rupees)}</span> },
    { key: "d", header: "Oldest (days)",
      render: (r) => {
        const tone = r.oldest_days > 7 ? "text-[var(--color-danger)]"
          : r.oldest_days > 1 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.oldest_days}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pending payments by hospital</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 hospitals by pending AMC payment orders</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.hospital_user_id} emptyMessage="No pending AMC orders." />
    </div>
  );
}
