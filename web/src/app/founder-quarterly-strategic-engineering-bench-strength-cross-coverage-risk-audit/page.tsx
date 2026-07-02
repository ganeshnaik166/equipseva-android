import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type BenchSummary = {
  total_engineers: number;
  spof_count: number;
  critical_gaps: number;
  strong_bench: number;
  high_attrition_risk: number;
  avg_utilization: number;
  avg_cross_coverage: number;
};

type BenchByRegion = {
  region: string;
  engineer_count: number;
  spof_count: number;
  avg_utilization: number;
  avg_cross_coverage: number;
};

type CriticalEngineer = {
  engineer_name: string;
  primary_skill: string;
  region: string;
  tier: string;
  attrition_risk: string;
  active_amc_load: number;
  bench_status: string;
  notes: string | null;
};

type FindingsSummary = {
  total_findings: number;
  p0_count: number;
  p1_count: number;
  open_count: number;
  resolved_count: number;
  total_revenue_at_risk: number;
  total_amcs_affected: number;
};

type UrgentFinding = {
  finding_title: string;
  region: string;
  skill_gap: string;
  severity: string;
  status: string;
  affected_amc_count: number;
  affected_revenue_rupees: number;
  target_close_date: string | null;
  owner: string;
  recommended_action: string;
};

type FindingsByRegion = {
  region: string;
  finding_count: number;
  p0_count: number;
  open_count: number;
  revenue_at_risk: number;
};

type TopSkillGap = {
  skill_gap: string;
  finding_count: number;
  total_amc_affected: number;
  total_revenue_at_risk: number;
  worst_severity: string;
};

type AttritionEntry = {
  engineer_name: string;
  primary_skill: string;
  region: string;
  tier: string;
  attrition_risk: string;
  backup_engineers_count: number;
  active_amc_load: number;
  cross_coverage_score: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    benchSummaryRes,
    benchByRegionRes,
    criticalEngineersRes,
    findingsSummaryRes,
    urgentFindingsRes,
    findingsByRegionRes,
    topSkillGapsRes,
    attritionRosterRes,
  ] = await Promise.all([
    supabase.rpc('fn_r3009_bench_summary'),
    supabase.rpc('fn_r3009_bench_by_region'),
    supabase.rpc('fn_r3009_critical_engineers'),
    supabase.rpc('fn_r3009_findings_summary'),
    supabase.rpc('fn_r3009_urgent_findings'),
    supabase.rpc('fn_r3009_findings_by_region'),
    supabase.rpc('fn_r3009_top_skill_gaps'),
    supabase.rpc('fn_r3009_attrition_roster'),
  ]);

  const benchSummary = (benchSummaryRes.data as BenchSummary[] | null)?.[0] ?? null;
  const benchByRegion = (benchByRegionRes.data as BenchByRegion[] | null) ?? [];
  const criticalEngineers = (criticalEngineersRes.data as CriticalEngineer[] | null) ?? [];
  const findingsSummary = (findingsSummaryRes.data as FindingsSummary[] | null)?.[0] ?? null;
  const urgentFindings = (urgentFindingsRes.data as UrgentFinding[] | null) ?? [];
  const findingsByRegion = (findingsByRegionRes.data as FindingsByRegion[] | null) ?? [];
  const topSkillGaps = (topSkillGapsRes.data as TopSkillGap[] | null) ?? [];
  const attritionRoster = (attritionRosterRes.data as AttritionEntry[] | null) ?? [];

  const benchByRegionCols: Column<BenchByRegion>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Engineers', accessor: (r) => r.engineer_count },
    { header: 'SPOFs', accessor: (r) => r.spof_count },
    { header: 'Avg Util %', accessor: (r) => r.avg_utilization },
    { header: 'Avg Cross-Cov', accessor: (r) => r.avg_cross_coverage },
  ];

  const criticalEngineersCols: Column<CriticalEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Skill', accessor: (r) => r.primary_skill },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Attrition', accessor: (r) => r.attrition_risk },
    { header: 'AMC Load', accessor: (r) => r.active_amc_load },
    { header: 'Bench', accessor: (r) => r.bench_status },
    { header: 'Notes', accessor: (r) => r.notes ?? '' },
  ];

  const urgentFindingsCols: Column<UrgentFinding>[] = [
    { header: 'Finding', accessor: (r) => r.finding_title },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Skill Gap', accessor: (r) => r.skill_gap },
    { header: 'Sev', accessor: (r) => r.severity },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'AMCs', accessor: (r) => r.affected_amc_count },
    { header: 'Revenue (Rs)', accessor: (r) => r.affected_revenue_rupees.toLocaleString('en-IN') },
    { header: 'Target Close', accessor: (r) => r.target_close_date ?? '' },
    { header: 'Owner', accessor: (r) => r.owner },
    { header: 'Action', accessor: (r) => r.recommended_action },
  ];

  const findingsByRegionCols: Column<FindingsByRegion>[] = [
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'P0', accessor: (r) => r.p0_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Revenue at Risk (Rs)', accessor: (r) => r.revenue_at_risk.toLocaleString('en-IN') },
  ];

  const topSkillGapsCols: Column<TopSkillGap>[] = [
    { header: 'Skill Gap', accessor: (r) => r.skill_gap },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'AMCs Affected', accessor: (r) => r.total_amc_affected },
    { header: 'Revenue at Risk (Rs)', accessor: (r) => r.total_revenue_at_risk.toLocaleString('en-IN') },
    { header: 'Worst Sev', accessor: (r) => r.worst_severity },
  ];

  const attritionCols: Column<AttritionEntry>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Skill', accessor: (r) => r.primary_skill },
    { header: 'Region', accessor: (r) => r.region },
    { header: 'Tier', accessor: (r) => r.tier },
    { header: 'Risk', accessor: (r) => r.attrition_risk },
    { header: 'Backups', accessor: (r) => r.backup_engineers_count },
    { header: 'AMC Load', accessor: (r) => r.active_amc_load },
    { header: 'Cross-Cov', accessor: (r) => r.cross_coverage_score },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineering Bench-Strength & Cross-Coverage Risk Audit</h1>
        <p className="text-sm text-gray-600">Round 3009 · Founder Console</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Bench Summary</h2>
        {benchSummary ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Engineers</div>
              <div className="text-xl font-bold">{benchSummary.total_engineers}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">SPOFs</div>
              <div className="text-xl font-bold text-red-600">{benchSummary.spof_count}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Critical Gaps</div>
              <div className="text-xl font-bold text-red-600">{benchSummary.critical_gaps}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Strong Bench</div>
              <div className="text-xl font-bold text-green-600">{benchSummary.strong_bench}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">High Attrition Risk</div>
              <div className="text-xl font-bold">{benchSummary.high_attrition_risk}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Avg Utilization</div>
              <div className="text-xl font-bold">{benchSummary.avg_utilization}%</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Avg Cross-Coverage</div>
              <div className="text-xl font-bold">{benchSummary.avg_cross_coverage}</div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-500">No data</p>
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Bench Strength by Region</h2>
        <DataTable
          rows={benchByRegion}
          columns={benchByRegionCols}
          emptyMessage="No regional bench data"
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Critical Engineers (SPOFs & Critical Gaps)</h2>
        <DataTable
          rows={criticalEngineers}
          columns={criticalEngineersCols}
          emptyMessage="No critical engineers flagged"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Findings Summary</h2>
        {findingsSummary ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Total Findings</div>
              <div className="text-xl font-bold">{findingsSummary.total_findings}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">P0</div>
              <div className="text-xl font-bold text-red-600">{findingsSummary.p0_count}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">P1</div>
              <div className="text-xl font-bold text-orange-600">{findingsSummary.p1_count}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Open</div>
              <div className="text-xl font-bold">{findingsSummary.open_count}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">Resolved</div>
              <div className="text-xl font-bold text-green-600">{findingsSummary.resolved_count}</div>
            </div>
            <div className="border rounded p-3">
              <div className="text-xs text-gray-500">AMCs Affected</div>
              <div className="text-xl font-bold">{findingsSummary.total_amcs_affected}</div>
            </div>
            <div className="border rounded p-3 col-span-2">
              <div className="text-xs text-gray-500">Total Revenue at Risk</div>
              <div className="text-xl font-bold">Rs {findingsSummary.total_revenue_at_risk.toLocaleString('en-IN')}</div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-gray-500">No data</p>
        )}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Urgent Findings (P0/P1 Open)</h2>
        <DataTable
          rows={urgentFindings}
          columns={urgentFindingsCols}
          emptyMessage="No urgent findings"
          rowKey={(r, i) => String(r.finding_title ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Findings by Region</h2>
        <DataTable
          rows={findingsByRegion}
          columns={findingsByRegionCols}
          emptyMessage="No regional findings"
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Top Skill Gaps by Revenue at Risk</h2>
        <DataTable
          rows={topSkillGaps}
          columns={topSkillGapsCols}
          emptyMessage="No skill gaps"
          rowKey={(r, i) => String(r.skill_gap ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Attrition Risk Roster</h2>
        <DataTable
          rows={attritionRoster}
          columns={attritionCols}
          emptyMessage="No attrition risks"
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>
    </main>
  );
}
