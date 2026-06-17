import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Onboarding time-to-first-action — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { role: string; cohort_size: number; median_minutes: number; p90_minutes: number; within_24h: number; within_7d: number };

export default async function OnboardingTimeToFirstActionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_onboarding_time_to_first_action");
  if (error) throw new Error(`founder_onboarding_time_to_first_action: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "r", header: "Role", render: (r) => <span className="text-xs font-semibold">{r.role}</span> },
    { key: "c", header: "Cohort 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cohort_size)}</span> },
    { key: "m", header: "Median (min)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.median_minutes)}</span> },
    { key: "p", header: "p90 (min)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.p90_minutes)}</span> },
    { key: "h", header: "Within 24h", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.within_24h)}</span> },
    { key: "w", header: "Within 7d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.within_7d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Onboarding time-to-first-action</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineer first bid · hospital first job · 90d cohort</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.role} emptyMessage="No first actions." />
    </div>
  );
}
