import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Lead scoring — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; bids_30d: number; accepted_30d: number; completed_30d: number; accept_rate_pct: number };

export default async function LeadScoringPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_lead_scoring");
  if (error) throw new Error(`founder_lead_scoring: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "b", header: "Bids 30d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids_30d)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.accepted_30d)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)] font-semibold">{formatNumber(r.completed_30d)}</span> },
    { key: "r", header: "Accept %", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.accept_rate_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Lead scoring</h1>
        <span className="text-xs text-[var(--color-muted)]">engineers with ≥10 bids in 30d but 0 completions</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No stuck engineers." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        High bid-volume engineers with zero closed jobs in 30d. Likely flagged: pricing too high, profile gaps, or losing to fitter peers. Re-engagement / coaching candidates.
      </section>
    </div>
  );
}
