import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_projects: number;
  total_award_rupees: number;
  total_disbursed_rupees: number;
  total_projected_revenue_rupees: number;
  flagship_projects: number;
  active_projects: number;
};

type StageRow = { stage: string; project_count: number; total_award: number; total_projected_revenue: number };
type TopRow = { project_code: string; research_topic: string; institution_name: string; stage: string; award_amount_rupees: number; projected_revenue_rupees: number; strategic_value: string };
type AgencyRow = { grant_agency: string; project_count: number; total_award: number; total_disbursed: number };
type TierRow = { institution_tier: string; project_count: number; total_award: number; flagship_count: number };
type RiskRow = { project_code: string; milestone_name: string; milestone_quarter: string; due_date: string; status: string; completion_pct: number; tranche_rupees: number };
type QuarterRow = { milestone_quarter: string; milestone_count: number; total_tranche_rupees: number; completed_count: number };
type StratRow = { strategic_value: string; project_count: number; total_award: number; total_projected_revenue: number; revenue_multiple: number };

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, stageRes, topRes, agencyRes, tierRes, riskRes, quarterRes, stratRes] = await Promise.all([
    supabase.rpc('founder_r2777_pipeline_summary'),
    supabase.rpc('founder_r2777_projects_by_stage'),
    supabase.rpc('founder_r2777_top_projects'),
    supabase.rpc('founder_r2777_agency_breakdown'),
    supabase.rpc('founder_r2777_institution_tier_rollup'),
    supabase.rpc('founder_r2777_milestones_at_risk'),
    supabase.rpc('founder_r2777_quarterly_tranche_view'),
    supabase.rpc('founder_r2777_strategic_value_rollup'),
  ]);

  const summary: Summary = (summaryRes.data?.[0] ?? {
    total_projects: 0,
    total_award_rupees: 0,
    total_disbursed_rupees: 0,
    total_projected_revenue_rupees: 0,
    flagship_projects: 0,
    active_projects: 0,
  }) as Summary;

  const stages: StageRow[] = (stageRes.data ?? []) as StageRow[];
  const top: TopRow[] = (topRes.data ?? []) as TopRow[];
  const agencies: AgencyRow[] = (agencyRes.data ?? []) as AgencyRow[];
  const tiers: TierRow[] = (tierRes.data ?? []) as TierRow[];
  const risks: RiskRow[] = (riskRes.data ?? []) as RiskRow[];
  const quarters: QuarterRow[] = (quarterRes.data ?? []) as QuarterRow[];
  const strat: StratRow[] = (stratRes.data ?? []) as StratRow[];

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Quarterly Grant-Funded Research Pipeline</h1>
        <p className="text-sm text-gray-600">
          Track grant × topic × institution × stage × award × revenue & strategic value
          across the quarterly research portfolio.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <KPI label="Total Projects" value={String(summary.total_projects)} />
        <KPI label="Active & Pilot" value={String(summary.active_projects)} />
        <KPI label="Flagship" value={String(summary.flagship_projects)} />
        <KPI label="Total Award" value={rupees(summary.total_award_rupees)} />
        <KPI label="Disbursed" value={rupees(summary.total_disbursed_rupees)} />
        <KPI label="Projected Revenue" value={rupees(summary.total_projected_revenue_rupees)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Projects by Stage</h2>
        <DataTable
          rows={stages}
          columns={[
            { key: 'stage', header: 'Stage', render: (r: StageRow) => r.stage },
            { key: 'project_count', header: 'Projects', render: (r: StageRow) => String(r.project_count) },
            { key: 'total_award', header: 'Total Award', render: (r: StageRow) => rupees(r.total_award) },
            { key: 'total_projected_revenue', header: 'Projected Revenue', render: (r: StageRow) => rupees(r.total_projected_revenue) },
          ]}
          emptyMessage="No data"
          rowKey={(r: StageRow, i: number) => String(r.stage ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Projects by Projected Revenue</h2>
        <DataTable
          rows={top}
          columns={[
            { key: 'project_code', header: 'Code', render: (r: TopRow) => r.project_code },
            { key: 'research_topic', header: 'Topic', render: (r: TopRow) => r.research_topic },
            { key: 'institution_name', header: 'Institution', render: (r: TopRow) => r.institution_name },
            { key: 'stage', header: 'Stage', render: (r: TopRow) => r.stage },
            { key: 'award_amount_rupees', header: 'Award', render: (r: TopRow) => rupees(r.award_amount_rupees) },
            { key: 'projected_revenue_rupees', header: 'Projected Revenue', render: (r: TopRow) => rupees(r.projected_revenue_rupees) },
            { key: 'strategic_value', header: 'Strategic', render: (r: TopRow) => r.strategic_value },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopRow, i: number) => String(r.project_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Agency Breakdown</h2>
        <DataTable
          rows={agencies}
          columns={[
            { key: 'grant_agency', header: 'Agency', render: (r: AgencyRow) => r.grant_agency },
            { key: 'project_count', header: 'Projects', render: (r: AgencyRow) => String(r.project_count) },
            { key: 'total_award', header: 'Total Award', render: (r: AgencyRow) => rupees(r.total_award) },
            { key: 'total_disbursed', header: 'Disbursed', render: (r: AgencyRow) => rupees(r.total_disbursed) },
          ]}
          emptyMessage="No data"
          rowKey={(r: AgencyRow, i: number) => String(r.grant_agency ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Institution Tier Rollup</h2>
        <DataTable
          rows={tiers}
          columns={[
            { key: 'institution_tier', header: 'Tier', render: (r: TierRow) => r.institution_tier },
            { key: 'project_count', header: 'Projects', render: (r: TierRow) => String(r.project_count) },
            { key: 'total_award', header: 'Total Award', render: (r: TierRow) => rupees(r.total_award) },
            { key: 'flagship_count', header: 'Flagship', render: (r: TierRow) => String(r.flagship_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TierRow, i: number) => String(r.institution_tier ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Milestones at Risk</h2>
        <DataTable
          rows={risks}
          columns={[
            { key: 'project_code', header: 'Code', render: (r: RiskRow) => r.project_code },
            { key: 'milestone_name', header: 'Milestone', render: (r: RiskRow) => r.milestone_name },
            { key: 'milestone_quarter', header: 'Quarter', render: (r: RiskRow) => r.milestone_quarter },
            { key: 'due_date', header: 'Due', render: (r: RiskRow) => r.due_date },
            { key: 'status', header: 'Status', render: (r: RiskRow) => r.status },
            { key: 'completion_pct', header: 'Completion %', render: (r: RiskRow) => String(r.completion_pct) },
            { key: 'tranche_rupees', header: 'Tranche', render: (r: RiskRow) => rupees(r.tranche_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RiskRow, i: number) => String((r.project_code ?? '') + '|' + (r.milestone_name ?? i))}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Tranche View</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'milestone_quarter', header: 'Quarter', render: (r: QuarterRow) => r.milestone_quarter },
            { key: 'milestone_count', header: 'Milestones', render: (r: QuarterRow) => String(r.milestone_count) },
            { key: 'total_tranche_rupees', header: 'Tranche Total', render: (r: QuarterRow) => rupees(r.total_tranche_rupees) },
            { key: 'completed_count', header: 'Completed', render: (r: QuarterRow) => String(r.completed_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.milestone_quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Strategic Value Rollup</h2>
        <DataTable
          rows={strat}
          columns={[
            { key: 'strategic_value', header: 'Strategic Value', render: (r: StratRow) => r.strategic_value },
            { key: 'project_count', header: 'Projects', render: (r: StratRow) => String(r.project_count) },
            { key: 'total_award', header: 'Total Award', render: (r: StratRow) => rupees(r.total_award) },
            { key: 'total_projected_revenue', header: 'Projected Revenue', render: (r: StratRow) => rupees(r.total_projected_revenue) },
            { key: 'revenue_multiple', header: 'Revenue Multiple', render: (r: StratRow) => String(r.revenue_multiple) + 'x' },
          ]}
          emptyMessage="No data"
          rowKey={(r: StratRow, i: number) => String(r.strategic_value ?? i)}
        />
      </section>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3">
      <div className="text-xs uppercase tracking-wide text-gray-500" dangerouslySetInnerHTML={{ __html: label }} />
      <div className="text-lg font-semibold mt-1">{value}</div>
    </div>
  );
}