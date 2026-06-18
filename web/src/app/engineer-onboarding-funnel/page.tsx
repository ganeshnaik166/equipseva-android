import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer onboarding funnel — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { stage: string; stage_order: number; engineers: number; pct_of_signups: number };

export default async function EngineerOnboardingFunnelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_onboarding_funnel");
  if (error) throw new Error(`founder_engineer_onboarding_funnel: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => <span className="text-xs font-semibold">{r.stage}</span> },
    { key: "c", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers)}</span> },
    { key: "p", header: "vs signups",
      render: (r) => {
        const v = Number(r.pct_of_signups);
        const tone = v < 25 ? "text-[var(--color-danger)]"
          : v < 50 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{v}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer onboarding funnel</h1>
        <span className="text-xs text-[var(--color-muted)]">6-stage funnel · signup → 1st payout · r1005 expanded</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.stage_order)} emptyMessage="No cohort data." />
    </div>
  );
}
