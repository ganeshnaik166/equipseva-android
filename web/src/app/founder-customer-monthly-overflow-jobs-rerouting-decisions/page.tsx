import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_jobs: number;
  approved_jobs: number;
  auto_routed_jobs: number;
  escalated_jobs: number;
  avg_cost_delta: number;
  total_cost_delta: number;
  pct_on_time: number;
};

type JobRow = {
  id: string;
  customer_name: string;
  job_ref: string;
  job_type: string;
  primary_engineer_name: string;
  primary_load_pct: number;
  overflow_reason: string;
  reroute_engineer_name: string | null;
  reroute_decision: string;
  outcome: string;
  cost_delta_rupees: number;
  refine_action: string;
  decided_on: string;
};

type ReasonRow = {
  overflow_reason: string;
  job_count: number;
  avg_cost_delta: number;
  on_time_pct: number;
};

type EngineerLoadRow = {
  primary_engineer_name: string;
  job_count: number;
  avg_load_pct: number;
  total_cost_delta: number;
};

type RefinementRow = {
  id: string;
  refinement_label: string;
  rule_category: string;
  before_overflow_pct: number;
  after_overflow_pct: number;
  delta_pct: number;
  jobs_impacted: number;
  cost_saved_rupees: number;
  status: string;
  owner: string;
  effective_from: string;
};

type OutcomeRow = {
  outcome: string;
  job_count: number;
  total_cost_delta: number;
  pct_share: number;
};

type RefineActionRow = {
  refine_action: string;
  job_count: number;
  total_cost_delta: number;
  avg_load_pct: number;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 2 });
}

function pct(n: number | null | undefined) {
  return `${Number(n ?? 0).toFixed(1)}%`;
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, jobsRes, reasonsRes, engLoadRes, refRes, outcomeRes, refineRes] = await Promise.all([
    supabase.rpc('founder_overflow_r2784_kpis'),
    supabase.rpc('founder_overflow_r2784_jobs'),
    supabase.rpc('founder_overflow_r2784_reasons'),
    supabase.rpc('founder_overflow_r2784_engineer_load'),
    supabase.rpc('founder_overflow_r2784_refinements'),
    supabase.rpc('founder_overflow_r2784_outcomes'),
    supabase.rpc('founder_overflow_r2784_refine_actions'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_jobs: 0,
    approved_jobs: 0,
    auto_routed_jobs: 0,
    escalated_jobs: 0,
    avg_cost_delta: 0,
    total_cost_delta: 0,
    pct_on_time: 0,
  };
  const jobs: JobRow[] = (jobsRes.data as JobRow[]) ?? [];
  const reasons: ReasonRow[] = (reasonsRes.data as ReasonRow[]) ?? [];
  const engLoad: EngineerLoadRow[] = (engLoadRes.data as EngineerLoadRow[]) ?? [];
  const refinements: RefinementRow[] = (refRes.data as RefinementRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const refineActions: RefineActionRow[] = (refineRes.data as RefineActionRow[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Overflow Jobs &amp; Rerouting Decisions</h1>
        <p className="text-sm text-gray-600">
          Monthly view of customer jobs that overflowed primary engineers, reroute decisions, outcomes, cost deltas
          and refinement actions taken. Load &gt;= 100% means primary engineer over capacity.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Jobs" value={String(kpi.total_jobs)} />
        <KpiCard label="On-Time %" value={pct(kpi.pct_on_time)} />
        <KpiCard label="Avg Cost Delta" value={rupees(kpi.avg_cost_delta)} />
        <KpiCard label="Total Cost Delta" value={rupees(kpi.total_cost_delta)} />
        <KpiCard label="Approved" value={String(kpi.approved_jobs)} />
        <KpiCard label="Auto-routed" value={String(kpi.auto_routed_jobs)} />
        <KpiCard label="Escalated" value={String(kpi.escalated_jobs)} />
        <KpiCard label="Refinements Active" value={String(refinements.filter((r) => r.status === 'active').length)} />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Overflow Jobs Ledger</h2>
        <DataTable
          rows={jobs}
          columns={[
            { key: 'job_ref', header: 'Job Ref', render: (r: JobRow) => r.job_ref },
            { key: 'customer_name', header: 'Customer', render: (r: JobRow) => r.customer_name },
            { key: 'job_type', header: 'Type', render: (r: JobRow) => r.job_type },
            {
              key: 'primary_engineer_name',
              header: 'Primary Eng',
              render: (r: JobRow) => `${r.primary_engineer_name} (${r.primary_load_pct}%)`,
            },
            { key: 'overflow_reason', header: 'Reason', render: (r: JobRow) => r.overflow_reason },
            { key: 'reroute_engineer_name', header: 'Reroute To', render: (r: JobRow) => r.reroute_engineer_name ?? '—' },
            { key: 'reroute_decision', header: 'Decision', render: (r: JobRow) => r.reroute_decision },
            { key: 'outcome', header: 'Outcome', render: (r: JobRow) => r.outcome },
            { key: 'cost_delta_rupees', header: 'Cost Δ', render: (r: JobRow) => rupees(r.cost_delta_rupees) },
            { key: 'refine_action', header: 'Refine', render: (r: JobRow) => r.refine_action },
            { key: 'decided_on', header: 'Decided', render: (r: JobRow) => r.decided_on },
          ]}
          emptyMessage="No data"
          rowKey={(r: JobRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-xl font-semibold mb-3">Overflow Reasons</h2>
          <DataTable
            rows={reasons}
            columns={[
              { key: 'overflow_reason', header: 'Reason', render: (r: ReasonRow) => r.overflow_reason },
              { key: 'job_count', header: 'Jobs', render: (r: ReasonRow) => String(r.job_count) },
              { key: 'avg_cost_delta', header: 'Avg Cost Δ', render: (r: ReasonRow) => rupees(r.avg_cost_delta) },
              { key: 'on_time_pct', header: 'On-Time %', render: (r: ReasonRow) => pct(r.on_time_pct) },
            ]}
            emptyMessage="No data"
            rowKey={(r: ReasonRow, i: number) => String(r.overflow_reason ?? i)}
          />
        </div>
        <div>
          <h2 className="text-xl font-semibold mb-3">Engineer Load</h2>
          <DataTable
            rows={engLoad}
            columns={[
              { key: 'primary_engineer_name', header: 'Engineer', render: (r: EngineerLoadRow) => r.primary_engineer_name },
              { key: 'job_count', header: 'Jobs', render: (r: EngineerLoadRow) => String(r.job_count) },
              { key: 'avg_load_pct', header: 'Avg Load %', render: (r: EngineerLoadRow) => pct(r.avg_load_pct) },
              { key: 'total_cost_delta', header: 'Total Cost Δ', render: (r: EngineerLoadRow) => rupees(r.total_cost_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: EngineerLoadRow, i: number) => String(r.primary_engineer_name ?? i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 className="text-xl font-semibold mb-3">Outcome Breakdown</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
              { key: 'job_count', header: 'Jobs', render: (r: OutcomeRow) => String(r.job_count) },
              { key: 'pct_share', header: 'Share %', render: (r: OutcomeRow) => pct(r.pct_share) },
              { key: 'total_cost_delta', header: 'Total Cost Δ', render: (r: OutcomeRow) => rupees(r.total_cost_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
          />
        </div>
        <div>
          <h2 className="text-xl font-semibold mb-3">Refine Actions Picked</h2>
          <DataTable
            rows={refineActions}
            columns={[
              { key: 'refine_action', header: 'Action', render: (r: RefineActionRow) => r.refine_action },
              { key: 'job_count', header: 'Jobs', render: (r: RefineActionRow) => String(r.job_count) },
              { key: 'avg_load_pct', header: 'Avg Load %', render: (r: RefineActionRow) => pct(r.avg_load_pct) },
              { key: 'total_cost_delta', header: 'Total Cost Δ', render: (r: RefineActionRow) => rupees(r.total_cost_delta) },
            ]}
            emptyMessage="No data"
            rowKey={(r: RefineActionRow, i: number) => String(r.refine_action ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Rule Refinements Tracker</h2>
        <p className="text-sm text-gray-600 mb-3">
          Each refinement compares before vs after overflow %. Positive delta means rule reduced overflow.
        </p>
        <DataTable
          rows={refinements}
          columns={[
            { key: 'refinement_label', header: 'Refinement', render: (r: RefinementRow) => r.refinement_label },
            { key: 'rule_category', header: 'Category', render: (r: RefinementRow) => r.rule_category },
            { key: 'before_overflow_pct', header: 'Before %', render: (r: RefinementRow) => pct(r.before_overflow_pct) },
            { key: 'after_overflow_pct', header: 'After %', render: (r: RefinementRow) => pct(r.after_overflow_pct) },
            { key: 'delta_pct', header: 'Delta %', render: (r: RefinementRow) => pct(r.delta_pct) },
            { key: 'jobs_impacted', header: 'Jobs', render: (r: RefinementRow) => String(r.jobs_impacted) },
            { key: 'cost_saved_rupees', header: 'Saved', render: (r: RefinementRow) => rupees(r.cost_saved_rupees) },
            { key: 'status', header: 'Status', render: (r: RefinementRow) => r.status },
            { key: 'owner', header: 'Owner', render: (r: RefinementRow) => r.owner },
            { key: 'effective_from', header: 'From', render: (r: RefinementRow) => r.effective_from },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefinementRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
