import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer payout history — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; paid_30d_rupees: number; paid_90d_rupees: number; paid_lifetime: number; payouts_lifetime: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EngineerPayoutHistoryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_payout_history");
  if (error) throw new Error(`founder_engineer_payout_history: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "30", header: "30d paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.paid_30d_rupees))}</span> },
    { key: "90", header: "90d paid", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.paid_90d_rupees))}</span> },
    { key: "l", header: "Lifetime", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.paid_lifetime))}</span> },
    { key: "c", header: "Payouts", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.payouts_lifetime)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer payout history</h1>
        <span className="text-xs text-[var(--color-muted)]">top 100 engineers by lifetime paid</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No payouts." />
    </div>
  );
}
