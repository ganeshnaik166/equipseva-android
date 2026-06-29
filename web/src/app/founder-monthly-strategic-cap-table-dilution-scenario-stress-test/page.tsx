import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { scenario_code: string; scenario_label: string; round_stage: string; pre_money_inr_cr: number; raise_amount_inr_cr: number; post_money_inr_cr: number; founder_dilution_pct: number; scenario_status: string; stress_score: number };
type ByStage = { round_stage: string; scenarios_count: number; avg_dilution_pct: number; max_dilution_pct: number; total_raise_cr: number; avg_stress: number };
type Hotspot = { scenario_code: string; scenario_label: string; stress_score: number; founder_dilution_pct: number; liquidation_pref_x: number; anti_dilution: string; pref_type: string };
type Dist = { stakeholder_type: string; holders: number; avg_post_pct: number; total_shares_lakh: number; board_seats: number };
type Traj = { scenario_code: string; round_stage: string; founder_pre_pct: number; founder_post_pct: number; delta_pct: number; voting_post_pct: number; protective: boolean };
type Protect = { anti_dilution: string; pref_type: string; scenarios: number; avg_stress: number; total_raise_cr: number };
type Pipeline = { scenario_status: string; scenarios: number; total_post_money_cr: number; total_raise_cr: number; avg_dilution: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, byStage, hotspots, dist, traj, protect, pipeline] = await Promise.all([
    supabase.rpc('founder_r2937_scenario_overview'),
    supabase.rpc('founder_r2937_dilution_by_stage'),
    supabase.rpc('founder_r2937_stress_hotspots'),
    supabase.rpc('founder_r2937_stakeholder_distribution'),
    supabase.rpc('founder_r2937_founder_trajectory'),
    supabase.rpc('founder_r2937_protection_terms_exposure'),
    supabase.rpc('founder_r2937_status_pipeline'),
  ]);

  const overviewRows: Overview[] = (overview.data as Overview[]) ?? [];
  const byStageRows: ByStage[] = (byStage.data as ByStage[]) ?? [];
  const hotspotRows: Hotspot[] = (hotspots.data as Hotspot[]) ?? [];
  const distRows: Dist[] = (dist.data as Dist[]) ?? [];
  const trajRows: Traj[] = (traj.data as Traj[]) ?? [];
  const protectRows: Protect[] = (protect.data as Protect[]) ?? [];
  const pipelineRows: Pipeline[] = (pipeline.data as Pipeline[]) ?? [];

  const overviewCols: Column<Overview>[] = [
    { key: 'scenario_code', header: 'Code', render: (r) => r.scenario_code },
    { key: 'scenario_label', header: 'Label', render: (r) => r.scenario_label },
    { key: 'round_stage', header: 'Stage', render: (r) => r.round_stage },
    { key: 'pre_money_inr_cr', header: 'Pre (Cr)', render: (r) => `Rs ${r.pre_money_inr_cr}` },
    { key: 'raise_amount_inr_cr', header: 'Raise (Cr)', render: (r) => `Rs ${r.raise_amount_inr_cr}` },
    { key: 'post_money_inr_cr', header: 'Post (Cr)', render: (r) => `Rs ${r.post_money_inr_cr}` },
    { key: 'founder_dilution_pct', header: 'Dilution %', render: (r) => `${r.founder_dilution_pct}%` },
    { key: 'scenario_status', header: 'Status', render: (r) => r.scenario_status },
    { key: 'stress_score', header: 'Stress', render: (r) => String(r.stress_score) },
  ];

  const byStageCols: Column<ByStage>[] = [
    { key: 'round_stage', header: 'Stage', render: (r) => r.round_stage },
    { key: 'scenarios_count', header: 'Count', render: (r) => String(r.scenarios_count) },
    { key: 'avg_dilution_pct', header: 'Avg Dilution %', render: (r) => `${r.avg_dilution_pct}%` },
    { key: 'max_dilution_pct', header: 'Max Dilution %', render: (r) => `${r.max_dilution_pct}%` },
    { key: 'total_raise_cr', header: 'Total Raise (Cr)', render: (r) => `Rs ${r.total_raise_cr}` },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => String(r.avg_stress) },
  ];

  const hotspotCols: Column<Hotspot>[] = [
    { key: 'scenario_code', header: 'Code', render: (r) => r.scenario_code },
    { key: 'scenario_label', header: 'Label', render: (r) => r.scenario_label },
    { key: 'stress_score', header: 'Stress', render: (r) => String(r.stress_score) },
    { key: 'founder_dilution_pct', header: 'Dilution %', render: (r) => `${r.founder_dilution_pct}%` },
    { key: 'liquidation_pref_x', header: 'Liq Pref', render: (r) => `${r.liquidation_pref_x}x` },
    { key: 'anti_dilution', header: 'Anti-Dilution', render: (r) => r.anti_dilution },
    { key: 'pref_type', header: 'Pref Type', render: (r) => r.pref_type },
  ];

  const distCols: Column<Dist>[] = [
    { key: 'stakeholder_type', header: 'Type', render: (r) => r.stakeholder_type },
    { key: 'holders', header: 'Holders', render: (r) => String(r.holders) },
    { key: 'avg_post_pct', header: 'Avg Post %', render: (r) => `${r.avg_post_pct}%` },
    { key: 'total_shares_lakh', header: 'Shares (L)', render: (r) => String(r.total_shares_lakh) },
    { key: 'board_seats', header: 'Board Seats', render: (r) => String(r.board_seats) },
  ];

  const trajCols: Column<Traj>[] = [
    { key: 'scenario_code', header: 'Code', render: (r) => r.scenario_code },
    { key: 'round_stage', header: 'Stage', render: (r) => r.round_stage },
    { key: 'founder_pre_pct', header: 'Pre %', render: (r) => `${r.founder_pre_pct}%` },
    { key: 'founder_post_pct', header: 'Post %', render: (r) => `${r.founder_post_pct}%` },
    { key: 'delta_pct', header: 'Delta %', render: (r) => `${r.delta_pct}%` },
    { key: 'voting_post_pct', header: 'Voting %', render: (r) => `${r.voting_post_pct}%` },
    { key: 'protective', header: 'Protective', render: (r) => (r.protective ? 'Yes' : 'No') },
  ];

  const protectCols: Column<Protect>[] = [
    { key: 'anti_dilution', header: 'Anti-Dilution', render: (r) => r.anti_dilution },
    { key: 'pref_type', header: 'Pref Type', render: (r) => r.pref_type },
    { key: 'scenarios', header: 'Scenarios', render: (r) => String(r.scenarios) },
    { key: 'avg_stress', header: 'Avg Stress', render: (r) => String(r.avg_stress) },
    { key: 'total_raise_cr', header: 'Total Raise (Cr)', render: (r) => `Rs ${r.total_raise_cr}` },
  ];

  const pipelineCols: Column<Pipeline>[] = [
    { key: 'scenario_status', header: 'Status', render: (r) => r.scenario_status },
    { key: 'scenarios', header: 'Scenarios', render: (r) => String(r.scenarios) },
    { key: 'total_post_money_cr', header: 'Post Money (Cr)', render: (r) => `Rs ${r.total_post_money_cr}` },
    { key: 'total_raise_cr', header: 'Total Raise (Cr)', render: (r) => `Rs ${r.total_raise_cr}` },
    { key: 'avg_dilution', header: 'Avg Dilution %', render: (r) => `${r.avg_dilution}%` },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Monthly Strategic Cap-Table Dilution Scenario Stress Test</h1>
        <p className="text-sm text-gray-600">Round r2937 — founder dilution & protection-terms stress modeling across {overviewRows.length} scenarios.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Scenario Overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No scenarios modeled" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.scenario_code}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dilution by Stage</h2>
        <DataTable rows={byStageRows} columns={byStageCols} emptyMessage="No stage data" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.round_stage}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stress Hotspots (score &gt;= 60)</h2>
        <DataTable rows={hotspotRows} columns={hotspotCols} emptyMessage="No high-stress scenarios" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.scenario_code}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stakeholder Distribution</h2>
        <DataTable rows={distRows} columns={distCols} emptyMessage="No stakeholders" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.stakeholder_type}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Position Trajectory</h2>
        <DataTable rows={trajRows} columns={trajCols} emptyMessage="No founder positions" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.scenario_code}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Protection Terms Exposure</h2>
        <DataTable rows={protectRows} columns={protectCols} emptyMessage="No protection mix data" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.anti_dilution}-${r.pref_type}-${i}`)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Pipeline</h2>
        <DataTable rows={pipelineRows} columns={pipelineCols} emptyMessage="No pipeline data" rowKey={(r, i) => String((r as { id?: string }).id ?? `${r.scenario_status}-${i}`)} />
      </section>
    </div>
  );
}
