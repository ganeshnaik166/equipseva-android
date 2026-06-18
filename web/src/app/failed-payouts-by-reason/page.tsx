import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Failed payouts by reason — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  failure_reason: string;
  cnt: number;
  total_inr: number;
  distinct_engs: number;
  last_failed_at: string | null;
};

export default async function FailedPayoutsByReasonPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_failed_payouts_by_reason_90d");
  if (error) throw new Error(`founder_failed_payouts_by_reason_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "r", header: "Failure reason", render: (r) => <span className="text-xs">{r.failure_reason}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cnt)}</span> },
    { key: "t", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "e", header: "Distinct engs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_engs)}</span> },
    { key: "l", header: "Last", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_failed_at ? formatRelativeTime(r.last_failed_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Failed payouts by reason (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 failure_reason patterns · high distinct_engs = systemic (gateway / RBI rule); single eng = data fix
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.failure_reason} emptyMessage="No failed payouts in last 90d." />
    </div>
  );
}
