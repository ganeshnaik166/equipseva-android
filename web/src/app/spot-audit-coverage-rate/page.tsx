import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; completed_jobs: number; invited: number; responded: number; invite_pct: number; response_pct: number };

export default async function SpotAuditCoverageRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_coverage_rate");
  if (error) throw new Error(`founder_spot_audit_coverage_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "j", header: "Completed jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed_jobs)}</span> },
    { key: "i", header: "Invited", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.invited)}</span> },
    { key: "r", header: "Responded", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responded)}</span> },
    { key: "ip", header: "Invite %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.invite_pct}%</span> },
    { key: "rp", header: "Response %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.response_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audit coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">Invitations as % completed jobs + response rate</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No data." />
    </div>
  );
}
