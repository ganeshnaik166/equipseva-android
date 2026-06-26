import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_candidates: number;
  sunset_this_quarter: number;
  total_steps: number;
  steps_done: number;
  revenue_at_risk: number;
  users_to_migrate: number;
};

type CandidateRow = {
  id: string;
  feature_name: string;
  surface: string;
  active_users_30d: number;
  monthly_revenue_inr: number;
  upstream_dependencies: number;
  downstream_consumers: number;
  maintenance_hours_q: number;
  verdict: string;
  risk_score: number;
};

type VerdictRow = {
  verdict: string;
  candidate_count: number;
  total_users: number;
  total_revenue: number;
  total_hours: number;
};

type SurfaceRow = {
  surface: string;
  candidate_count: number;
  total_hours: number;
  sunset_count: number;
};

type PendingStep = {
  step_id: string;
  feature_name: string;
  step_order: number;
  step_kind: string;
  description: string;
  target_date: string;
  owner_role: string;
  status: string;
  days_to_target: number;
};

type ProgressRow = {
  feature_name: string;
  verdict: string;
  total_steps: number;
  done_steps: number;
  percent_done: number;
};

type BlockerRow = {
  feature_name: string;
  step_kind: string;
  owner_role: string;
  blocker_notes: string | null;
  target_date: string;
};

function inr(n: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, candidatesRes, verdictsRes, surfacesRes, pendingRes, progressRes, blockersRes] = await Promise.all([
    supabase.rpc('founder_r2809_overview'),
    supabase.rpc('founder_r2809_candidates'),
    supabase.rpc('founder_r2809_verdict_breakdown'),
    supabase.rpc('founder_r2809_surface_breakdown'),
    supabase.rpc('founder_r2809_pending_steps'),
    supabase.rpc('founder_r2809_completion_progress'),
    supabase.rpc('founder_r2809_blockers'),
  ]);

  const overview: OverviewRow = (overviewRes.data?.[0] ?? {
    total_candidates: 0,
    sunset_this_quarter: 0,
    total_steps: 0,
    steps_done: 0,
    revenue_at_risk: 0,
    users_to_migrate: 0,
  }) as OverviewRow;

  const candidates: CandidateRow[] = (candidatesRes.data ?? []) as CandidateRow[];
  const verdicts: VerdictRow[] = (verdictsRes.data ?? []) as VerdictRow[];
  const surfaces: SurfaceRow[] = (surfacesRes.data ?? []) as SurfaceRow[];
  const pending: PendingStep[] = (pendingRes.data ?? []) as PendingStep[];
  const progress: ProgressRow[] = (progressRes.data ?? []) as ProgressRow[];
  const blockers: BlockerRow[] = (blockersRes.data ?? []) as BlockerRow[];

  const kpis = [
    { label: 'Candidates', value: overview.total_candidates },
    { label: 'Sunset this quarter', value: overview.sunset_this_quarter },
    { label: 'Steps done', value: `${overview.steps_done} / ${overview.total_steps}` },
    { label: 'Revenue at risk', value: inr(overview.revenue_at_risk) },
    { label: 'Users to migrate', value: overview.users_to_migrate },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Product Deprecation Checklist</h1>
        <p className="text-sm text-gray-600">
          Review every shipped feature each quarter. Score on users, revenue, dependencies. Decide: keep, deprecate, or sunset.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-gray-200 p-4 bg-white">
            <div className="text-xs uppercase text-gray-500">{k.label}</div>
            <div className="text-xl font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Candidates (risk-ranked)</h2>
        <DataTable
          rows={candidates}
          columns={[
            { key: 'feature_name', header: 'Feature', render: (r: CandidateRow) => r.feature_name },
            { key: 'surface', header: 'Surface', render: (r: CandidateRow) => r.surface },
            { key: 'active_users_30d', header: 'Users 30d', render: (r: CandidateRow) => r.active_users_30d },
            { key: 'monthly_revenue_inr', header: 'Rev / mo', render: (r: CandidateRow) => inr(r.monthly_revenue_inr) },
            { key: 'upstream_dependencies', header: 'Upstream', render: (r: CandidateRow) => r.upstream_dependencies },
            { key: 'downstream_consumers', header: 'Downstream', render: (r: CandidateRow) => r.downstream_consumers },
            { key: 'maintenance_hours_q', header: 'Hrs / Q', render: (r: CandidateRow) => r.maintenance_hours_q },
            { key: 'verdict', header: 'Verdict', render: (r: CandidateRow) => r.verdict },
            { key: 'risk_score', header: 'Risk', render: (r: CandidateRow) => r.risk_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: CandidateRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Verdict breakdown</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'candidate_count', header: 'Count', render: (r: VerdictRow) => r.candidate_count },
            { key: 'total_users', header: 'Users', render: (r: VerdictRow) => r.total_users },
            { key: 'total_revenue', header: 'Revenue', render: (r: VerdictRow) => inr(r.total_revenue) },
            { key: 'total_hours', header: 'Hours / Q', render: (r: VerdictRow) => r.total_hours },
          ]}
          emptyMessage="No data"
          rowKey={(r: VerdictRow, i: number) => String(r.verdict ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Surface breakdown</h2>
        <DataTable
          rows={surfaces}
          columns={[
            { key: 'surface', header: 'Surface', render: (r: SurfaceRow) => r.surface },
            { key: 'candidate_count', header: 'Candidates', render: (r: SurfaceRow) => r.candidate_count },
            { key: 'total_hours', header: 'Hours / Q', render: (r: SurfaceRow) => r.total_hours },
            { key: 'sunset_count', header: 'Sunset / depr', render: (r: SurfaceRow) => r.sunset_count },
          ]}
          emptyMessage="No data"
          rowKey={(r: SurfaceRow, i: number) => String(r.surface ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Pending checklist steps</h2>
        <DataTable
          rows={pending}
          columns={[
            { key: 'feature_name', header: 'Feature', render: (r: PendingStep) => r.feature_name },
            { key: 'step_order', header: 'Step', render: (r: PendingStep) => r.step_order },
            { key: 'step_kind', header: 'Kind', render: (r: PendingStep) => r.step_kind },
            { key: 'description', header: 'Description', render: (r: PendingStep) => r.description },
            { key: 'target_date', header: 'Target', render: (r: PendingStep) => r.target_date },
            { key: 'owner_role', header: 'Owner', render: (r: PendingStep) => r.owner_role },
            { key: 'status', header: 'Status', render: (r: PendingStep) => r.status },
            { key: 'days_to_target', header: 'Days', render: (r: PendingStep) => r.days_to_target },
          ]}
          emptyMessage="No data"
          rowKey={(r: PendingStep, i: number) => String(r.step_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Completion progress</h2>
        <DataTable
          rows={progress}
          columns={[
            { key: 'feature_name', header: 'Feature', render: (r: ProgressRow) => r.feature_name },
            { key: 'verdict', header: 'Verdict', render: (r: ProgressRow) => r.verdict },
            { key: 'total_steps', header: 'Total', render: (r: ProgressRow) => r.total_steps },
            { key: 'done_steps', header: 'Done', render: (r: ProgressRow) => r.done_steps },
            { key: 'percent_done', header: 'Percent', render: (r: ProgressRow) => `${r.percent_done}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: ProgressRow, i: number) => String(r.feature_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Blockers</h2>
        <DataTable
          rows={blockers}
          columns={[
            { key: 'feature_name', header: 'Feature', render: (r: BlockerRow) => r.feature_name },
            { key: 'step_kind', header: 'Kind', render: (r: BlockerRow) => r.step_kind },
            { key: 'owner_role', header: 'Owner', render: (r: BlockerRow) => r.owner_role },
            { key: 'blocker_notes', header: 'Notes', render: (r: BlockerRow) => r.blocker_notes ?? '' },
            { key: 'target_date', header: 'Target', render: (r: BlockerRow) => r.target_date },
          ]}
          emptyMessage="No data"
          rowKey={(r: BlockerRow, i: number) => `${r.feature_name}-${i}`}
        />
      </section>
    </main>
  );
}
