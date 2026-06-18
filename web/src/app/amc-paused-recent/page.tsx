import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC paused recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { amc_contract_id: string; hospital_name: string; tier: string; monthly_fee: number; paused_at: string; days_paused: number };

export default async function AmcPausedRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_paused_recent");
  if (error) throw new Error(`founder_amc_paused_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalLostMrr = rows.reduce((n, r) => n + (r.monthly_fee ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "p", header: "Paused at", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.paused_at).toLocaleString()}</span> },
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs">{r.tier}</span> },
    { key: "m", header: "MRR lost (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)] font-semibold">{formatNumber(r.monthly_fee)}</span> },
    { key: "d", header: "Days paused",
      render: (r) => {
        const tone = r.days_paused > 30 ? "text-[var(--color-danger)]"
          : r.days_paused > 7 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.days_paused}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC paused recent</h1>
        <span className="text-xs text-[var(--color-muted)]">Total frozen MRR ₹{formatNumber(totalLostMrr)} · {rows.length} contracts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.amc_contract_id} emptyMessage="No paused contracts." />
    </div>
  );
}
