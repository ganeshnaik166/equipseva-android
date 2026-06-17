import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital onboarding funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { stage: string; cnt: number; pct_signup: number };

export default async function HospitalOnboardingFunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_onboarding_funnel");
  if (error) throw new Error(`founder_hospital_onboarding_funnel: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => <span className="text-xs font-semibold">{r.stage}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "% of signups",
      render: (r) => <span className="text-xs tabular-nums font-semibold">{r.pct_signup}%</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital onboarding funnel</h1>
        <span className="text-xs text-[var(--color-muted)]">90d cohort · signup → first job → AMC</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.stage} emptyMessage="No hospital signups." />
    </div>
  );
}
