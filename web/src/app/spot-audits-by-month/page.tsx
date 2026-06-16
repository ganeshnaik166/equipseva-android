import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audits by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; invitations: number; responses: number; response_pct: number; avg_rating: number };

export default async function SpotAuditsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audits_by_month");
  if (error) throw new Error(`founder_spot_audits_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "i", header: "Invitations", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.invitations)}</span> },
    { key: "r", header: "Responses", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responses)}</span> },
    { key: "p", header: "Response %", render: (r) => <span className="text-xs tabular-nums">{r.response_pct}%</span> },
    { key: "a", header: "Avg rating",
      render: (r) => {
        const a = Number(r.avg_rating);
        const tone = a > 0 && a < 3 ? "text-[var(--color-danger)]" : a > 0 && a < 4 ? "text-[var(--color-warn)]" : a > 0 ? "text-[var(--color-ok)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{a.toFixed(2)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audits by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month invitations / responses / avg rating</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No spot audits." />
    </div>
  );
}
