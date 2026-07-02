import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_hires: number;
  in_window: number;
  graduated: number;
  at_risk: number;
  avg_retention_pct: number;
  exceeds_rate_pct: number;
};

type Hire = {
  id: string;
  hire_name: string;
  role_title: string;
  function_area: string;
  level_band: string;
  start_date: string;
  hiring_manager: string;
  base_ctc_lakhs: number;
  strategic_priority: string;
  status: string;
};

type Milestone = {
  milestone_id: string;
  hire_name: string;
  role_title: string;
  checkpoint_window: string;
  milestone_title: string;
  milestone_category: string;
  target_outcome: string;
  actual_outcome: string | null;
  rating: string;
  manager_verdict: string;
  retention_probability_pct: number;
  evaluated_at: string;
};

type WindowRow = {
  checkpoint_window: string;
  total_milestones: number;
  exceeds_count: number;
  meets_count: number;
  below_or_missed: number;
  avg_retention_pct: number;
};

type FunctionRow = {
  function_area: string;
  hires_count: number;
  total_ctc_lakhs: number;
  graduated_count: number;
  at_risk_count: number;
};

type AtRiskRow = {
  hire_name: string;
  role_title: string;
  hiring_manager: string;
  status: string;
  worst_rating: string | null;
  min_retention_pct: number | null;
  latest_verdict: string | null;
};

type VerdictRow = {
  manager_verdict: string;
  verdict_count: number;
  avg_retention_pct: number;
  share_pct: number;
};

type SourceRow = {
  source_channel: string;
  hires_count: number;
  graduated_count: number;
  at_risk_count: number;
  avg_retention_pct: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, hiresRes, milestonesRes, windowRes, functionRes, atRiskRes, verdictRes, sourceRes] = await Promise.all([
    supabase.rpc('founder_r2885_onboarding_kpis'),
    supabase.rpc('founder_r2885_hires_list'),
    supabase.rpc('founder_r2885_milestones_list'),
    supabase.rpc('founder_r2885_by_window'),
    supabase.rpc('founder_r2885_by_function'),
    supabase.rpc('founder_r2885_at_risk'),
    supabase.rpc('founder_r2885_verdict_mix'),
    supabase.rpc('founder_r2885_source_roi'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_hires: 0,
    in_window: 0,
    graduated: 0,
    at_risk: 0,
    avg_retention_pct: 0,
    exceeds_rate_pct: 0,
  }) as Kpi;
  const hires: Hire[] = (hiresRes.data ?? []) as Hire[];
  const milestones: Milestone[] = (milestonesRes.data ?? []) as Milestone[];
  const windows: WindowRow[] = (windowRes.data ?? []) as WindowRow[];
  const functions: FunctionRow[] = (functionRes.data ?? []) as FunctionRow[];
  const atRisk: AtRiskRow[] = (atRiskRes.data ?? []) as AtRiskRow[];
  const verdicts: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];
  const sources: SourceRow[] = (sourceRes.data ?? []) as SourceRow[];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">Quarterly Strategic Team Onboarding 30/60/90</h1>
        <p className="text-sm text-gray-600">
          Track strategic new hires across 30-day, 60-day and 90-day checkpoints. Each milestone carries a manager verdict and a retention probability so the founder can intervene before attrition hits.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <KpiCard label="Total Hires" value={String(kpi.total_hires)} />
        <KpiCard label="In Window" value={String(kpi.in_window)} />
        <KpiCard label="Graduated" value={String(kpi.graduated)} />
        <KpiCard label="At Risk" value={String(kpi.at_risk)} />
        <KpiCard label="Avg Retention" value={`${kpi.avg_retention_pct}%`} />
        <KpiCard label="Exceeds Rate" value={`${kpi.exceeds_rate_pct}%`} />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Checkpoint Window Mix</h2>
        <p className="text-sm text-gray-600">Distribution of milestone ratings across the 30 / 60 / 90 day windows.</p>
        <DataTable
          rows={windows}
          columns={[
            { key: 'checkpoint_window', header: 'Window', render: (r: WindowRow) => r.checkpoint_window },
            { key: 'total_milestones', header: 'Total', render: (r: WindowRow) => String(r.total_milestones) },
            { key: 'exceeds_count', header: 'Exceeds', render: (r: WindowRow) => String(r.exceeds_count) },
            { key: 'meets_count', header: 'Meets', render: (r: WindowRow) => String(r.meets_count) },
            { key: 'below_or_missed', header: 'Below / Missed', render: (r: WindowRow) => String(r.below_or_missed) },
            { key: 'avg_retention_pct', header: 'Avg Retention %', render: (r: WindowRow) => `${r.avg_retention_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: WindowRow, i: number) => String(r.checkpoint_window ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Strategic New Hires</h2>
        <p className="text-sm text-gray-600">All P0 and P1 hires in or past their first quarter.</p>
        <DataTable
          rows={hires}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: Hire) => r.hire_name },
            { key: 'role_title', header: 'Role', render: (r: Hire) => r.role_title },
            { key: 'function_area', header: 'Function', render: (r: Hire) => r.function_area },
            { key: 'level_band', header: 'Level', render: (r: Hire) => r.level_band },
            { key: 'start_date', header: 'Start', render: (r: Hire) => r.start_date },
            { key: 'hiring_manager', header: 'Manager', render: (r: Hire) => r.hiring_manager },
            { key: 'base_ctc_lakhs', header: 'CTC (L)', render: (r: Hire) => String(r.base_ctc_lakhs) },
            { key: 'strategic_priority', header: 'Priority', render: (r: Hire) => r.strategic_priority },
            { key: 'status', header: 'Status', render: (r: Hire) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Hire, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Milestone Ledger</h2>
        <p className="text-sm text-gray-600">Every 30 / 60 / 90 day checkpoint with target, actual, rating, verdict and retention probability.</p>
        <DataTable
          rows={milestones}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: Milestone) => r.hire_name },
            { key: 'checkpoint_window', header: 'Window', render: (r: Milestone) => r.checkpoint_window },
            { key: 'milestone_title', header: 'Milestone', render: (r: Milestone) => r.milestone_title },
            { key: 'milestone_category', header: 'Category', render: (r: Milestone) => r.milestone_category },
            { key: 'target_outcome', header: 'Target', render: (r: Milestone) => r.target_outcome },
            { key: 'actual_outcome', header: 'Actual', render: (r: Milestone) => r.actual_outcome ?? '—' },
            { key: 'rating', header: 'Rating', render: (r: Milestone) => r.rating },
            { key: 'manager_verdict', header: 'Verdict', render: (r: Milestone) => r.manager_verdict },
            { key: 'retention_probability_pct', header: 'Retention %', render: (r: Milestone) => `${r.retention_probability_pct}%` },
            { key: 'evaluated_at', header: 'Evaluated', render: (r: Milestone) => r.evaluated_at },
          ]}
          emptyMessage="No data"
          rowKey={(r: Milestone, i: number) => String(r.milestone_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">By Function</h2>
        <p className="text-sm text-gray-600">Where strategic spend lands and how those bets are performing.</p>
        <DataTable
          rows={functions}
          columns={[
            { key: 'function_area', header: 'Function', render: (r: FunctionRow) => r.function_area },
            { key: 'hires_count', header: 'Hires', render: (r: FunctionRow) => String(r.hires_count) },
            { key: 'total_ctc_lakhs', header: 'Total CTC (L)', render: (r: FunctionRow) => String(r.total_ctc_lakhs) },
            { key: 'graduated_count', header: 'Graduated', render: (r: FunctionRow) => String(r.graduated_count) },
            { key: 'at_risk_count', header: 'At Risk', render: (r: FunctionRow) => String(r.at_risk_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: FunctionRow, i: number) => String(r.function_area ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">At-Risk Roster</h2>
        <p className="text-sm text-gray-600">Hires with retention probability under 60% or status at_risk / attrited — founder must intervene.</p>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'hire_name', header: 'Hire', render: (r: AtRiskRow) => r.hire_name },
            { key: 'role_title', header: 'Role', render: (r: AtRiskRow) => r.role_title },
            { key: 'hiring_manager', header: 'Manager', render: (r: AtRiskRow) => r.hiring_manager },
            { key: 'status', header: 'Status', render: (r: AtRiskRow) => r.status },
            { key: 'worst_rating', header: 'Worst Rating', render: (r: AtRiskRow) => r.worst_rating ?? '—' },
            { key: 'min_retention_pct', header: 'Min Retention %', render: (r: AtRiskRow) => r.min_retention_pct == null ? '—' : `${r.min_retention_pct}%` },
            { key: 'latest_verdict', header: 'Latest Verdict', render: (r: AtRiskRow) => r.latest_verdict ?? '—' },
          ]}
          emptyMessage="No data"
          rowKey={(r: AtRiskRow, i: number) => String(r.hire_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Verdict Mix</h2>
        <p className="text-sm text-gray-600">Continue, accelerate, coach, pip or exit — the verdict distribution tells the founder whether bar is being held.</p>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'manager_verdict', header: 'Verdict', render: (r: VerdictRow) => r.manager_verdict },
            { key: 'verdict_count', header: 'Count', render: (r: VerdictRow) => String(r.verdict_count) },
            { key: 'avg_retention_pct', header: 'Avg Retention %', render: (r: VerdictRow) => `${r.avg_retention_pct}%` },
            { key: 'share_pct', header: 'Share %', render: (r: VerdictRow) => `${r.share_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.manager_verdict ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Source Channel ROI</h2>
        <p className="text-sm text-gray-600">Which channels produce graduates vs at-risk hires.</p>
        <DataTable
          rows={sources}
          columns={[
            { key: 'source_channel', header: 'Channel', render: (r: SourceRow) => r.source_channel },
            { key: 'hires_count', header: 'Hires', render: (r: SourceRow) => String(r.hires_count) },
            { key: 'graduated_count', header: 'Graduated', render: (r: SourceRow) => String(r.graduated_count) },
            { key: 'at_risk_count', header: 'At Risk', render: (r: SourceRow) => String(r.at_risk_count) },
            { key: 'avg_retention_pct', header: 'Avg Retention %', render: (r: SourceRow) => `${r.avg_retention_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: SourceRow, i: number) => String(r.source_channel ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="border rounded-lg p-4 bg-white shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}
