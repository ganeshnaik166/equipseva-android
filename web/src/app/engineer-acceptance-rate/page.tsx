import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer acceptance rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; bids_placed: number; bids_accepted: number; acceptance_pct: number };

export default async function EngineerAcceptanceRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_acceptance_rate");
  if (error) throw new Error(`founder_engineer_acceptance_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "p", header: "Bids placed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids_placed)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bids_accepted)}</span> },
    { key: "r", header: "Acceptance %",
      render: (r) => {
        const tone = r.acceptance_pct < 10 ? "text-[var(--color-danger)]"
          : r.acceptance_pct < 30 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.acceptance_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer acceptance rate</h1>
        <span className="text-xs text-[var(--color-muted)]">last 30d · engineers with ≥5 bids · ordered DESC</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No bid activity." />
    </div>
  );
}
