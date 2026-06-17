import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audits by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; invitations: number; responses: number; response_pct: number; avg_rating: number };

export default async function SpotAuditsByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audits_by_week");
  if (error) throw new Error(`founder_spot_audits_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "i", header: "Invitations", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.invitations)}</span> },
    { key: "r", header: "Responses", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responses)}</span> },
    { key: "p", header: "Response %", render: (r) => <span className="text-xs tabular-nums">{r.response_pct}%</span> },
    { key: "a", header: "Avg rating", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{Number(r.avg_rating).toFixed(2)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audits by week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 13 weeks</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No spot audits." />
    </div>
  );
}
