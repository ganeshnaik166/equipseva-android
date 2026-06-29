import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_drills: number;
  passed_drills: number;
  failed_drills: number;
  avg_score: number;
  critical_tier: number;
  high_tier: number;
  total_affected: number;
};

type Quarter = {
  quarter: string;
  drills: number;
  passed: number;
  avg_score: number;
  avg_rto_gap: number;
  total_affected: number;
};

type Scenario = {
  scenario_code: string;
  drills: number;
  pass_rate_pct: number;
  avg_score: number;
  avg_mttd: number;
  avg_mttr: number;
};

type Chain = {
  chain_name: string;
  drills: number;
  passed: number;
  avg_score: number;
  total_affected: number;
  rank_pos: number;
};

type FindingCat = {
  finding_category: string;
  total: number;
  critical_count: number;
  high_count: number;
  open_count: number;
  total_cost_rupees: number;
};

type OpenCrit = {
  chain_name: string;
  scenario_code: string;
  finding_category: string;
  finding_text: string;
  remediation_owner: string;
  remediation_due: string;
  remediation_status: string;
  cost_estimate_rupees: number;
};

type RtoGap = {
  chain_name: string;
  drill_quarter: string;
  scenario_code: string;
  rto_target_minutes: number;
  rto_achieved_minutes: number;
  gap_minutes: number;
  drill_score: number;
};

type Burndown = {
  remediation_status: string;
  count_findings: number;
  total_cost_rupees: number;
  critical_count: number;
  evidence_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, quarterRes, scenarioRes, chainRes, catRes, openRes, rtoRes, burnRes] = await Promise.all([
    supabase.rpc('founder_r2975_session_overview'),
    supabase.rpc('founder_r2975_quarter_breakdown'),
    supabase.rpc('founder_r2975_scenario_performance'),
    supabase.rpc('founder_r2975_chain_leaderboard'),
    supabase.rpc('founder_r2975_findings_by_category'),
    supabase.rpc('founder_r2975_open_critical_findings'),
    supabase.rpc('founder_r2975_rto_gap_outliers'),
    supabase.rpc('founder_r2975_remediation_burndown'),
  ]);

  const overview: Overview[] = (overviewRes.data as Overview[]) ?? [];
  const quarters: Quarter[] = (quarterRes.data as Quarter[]) ?? [];
  const scenarios: Scenario[] = (scenarioRes.data as Scenario[]) ?? [];
  const chains: Chain[] = (chainRes.data as Chain[]) ?? [];
  const cats: FindingCat[] = (catRes.data as FindingCat[]) ?? [];
  const openCrits: OpenCrit[] = (openRes.data as OpenCrit[]) ?? [];
  const rtoGaps: RtoGap[] = (rtoRes.data as RtoGap[]) ?? [];
  const burn: Burndown[] = (burnRes.data as Burndown[]) ?? [];

  const overviewCols: Column<Overview>[] = [
    { header: 'Total Drills', accessor: (r) => r.total_drills },
    { header: 'Passed', accessor: (r) => r.passed_drills },
    { header: 'Failed', accessor: (r) => r.failed_drills },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Tier-1 Critical', accessor: (r) => r.critical_tier },
    { header: 'Tier-2 High', accessor: (r) => r.high_tier },
    { header: 'Affected Equipment', accessor: (r) => r.total_affected },
  ];

  const quarterCols: Column<Quarter>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Drills', accessor: (r) => r.drills },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Avg RTO Gap (min)', accessor: (r) => r.avg_rto_gap },
    { header: 'Affected', accessor: (r) => r.total_affected },
  ];

  const scenarioCols: Column<Scenario>[] = [
    { header: 'Scenario', accessor: (r) => r.scenario_code },
    { header: 'Drills', accessor: (r) => r.drills },
    { header: 'Pass Rate %', accessor: (r) => r.pass_rate_pct },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Avg MTTD (min)', accessor: (r) => r.avg_mttd },
    { header: 'Avg MTTR (min)', accessor: (r) => r.avg_mttr },
  ];

  const chainCols: Column<Chain>[] = [
    { header: 'Rank', accessor: (r) => r.rank_pos },
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Drills', accessor: (r) => r.drills },
    { header: 'Passed', accessor: (r) => r.passed },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'Affected', accessor: (r) => r.total_affected },
  ];

  const catCols: Column<FindingCat>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'High', accessor: (r) => r.high_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
  ];

  const openCols: Column<OpenCrit>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Scenario', accessor: (r) => r.scenario_code },
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Finding', accessor: (r) => r.finding_text },
    { header: 'Owner', accessor: (r) => r.remediation_owner },
    { header: 'Due', accessor: (r) => r.remediation_due },
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_estimate_rupees },
  ];

  const rtoCols: Column<RtoGap>[] = [
    { header: 'Chain', accessor: (r) => r.chain_name },
    { header: 'Quarter', accessor: (r) => r.drill_quarter },
    { header: 'Scenario', accessor: (r) => r.scenario_code },
    { header: 'RTO Target', accessor: (r) => r.rto_target_minutes },
    { header: 'RTO Achieved', accessor: (r) => r.rto_achieved_minutes },
    { header: 'Gap (min)', accessor: (r) => r.gap_minutes },
    { header: 'Score', accessor: (r) => r.drill_score },
  ];

  const burnCols: Column<Burndown>[] = [
    { header: 'Status', accessor: (r) => r.remediation_status },
    { header: 'Findings', accessor: (r) => r.count_findings },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost_rupees },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Evidence %', accessor: (r) => r.evidence_pct },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Equipment Cyber-Incident Tabletop Drill Outcomes</h1>
        <p className="text-sm text-gray-600">Round r2975 — founder console — tracks tabletop drill posture across hospital chains, scenarios & quarters.</p>
      </header>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Session Overview</h2>
        <DataTable
          rows={overview}
          columns={overviewCols}
          emptyMessage="No drill sessions recorded."
          rowKey={(r, i) => String((r as Overview & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Quarter Breakdown</h2>
        <DataTable
          rows={quarters}
          columns={quarterCols}
          emptyMessage="No quarterly data."
          rowKey={(r, i) => String((r as Quarter & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Scenario Performance</h2>
        <DataTable
          rows={scenarios}
          columns={scenarioCols}
          emptyMessage="No scenario data."
          rowKey={(r, i) => String((r as Scenario & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Chain Leaderboard</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chains."
          rowKey={(r, i) => String((r as Chain & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Findings By Category</h2>
        <DataTable
          rows={cats}
          columns={catCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String((r as FindingCat & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Open Critical & High Findings</h2>
        <DataTable
          rows={openCrits}
          columns={openCols}
          emptyMessage="No open critical findings — chains clean."
          rowKey={(r, i) => String((r as OpenCrit & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">RTO Gap Outliers (achieved &gt; target)</h2>
        <DataTable
          rows={rtoGaps}
          columns={rtoCols}
          emptyMessage="All drills met RTO targets."
          rowKey={(r, i) => String((r as RtoGap & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-2 text-lg font-semibold">Remediation Burndown</h2>
        <DataTable
          rows={burn}
          columns={burnCols}
          emptyMessage="No remediation data."
          rowKey={(r, i) => String((r as Burndown & { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
