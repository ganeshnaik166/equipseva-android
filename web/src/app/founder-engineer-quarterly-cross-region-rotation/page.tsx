import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_rotations: number;
  active_rotations: number;
  completed_rotations: number;
  planned_rotations: number;
  total_travel_cost_rupees: number;
  avg_csat: number | null;
  avg_duration_weeks: number | null;
  exceeded_count: number;
};

type Rotation = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  quarter: string;
  from_region: string;
  to_region: string;
  duration_weeks: number;
  skill_goal: string;
  status: string;
  outcome: string | null;
  jobs_completed: number;
  csat_avg: number | null;
  start_on: string;
  end_on: string;
  travel_cost_rupees: number;
};

type RegionFlow = {
  from_region: string;
  to_region: string;
  rotation_count: number;
  total_weeks: number;
  avg_csat: number | null;
  total_cost_rupees: number;
};

type Outcome = {
  outcome_bucket: string;
  rotation_count: number;
  avg_jobs_completed: number | null;
  avg_csat: number | null;
};

type Checkpoint = {
  engineer_code: string;
  engineer_name: string;
  skill_area: string;
  proficiency_before: number;
  proficiency_after: number;
  delta: number;
  mentor_code: string;
  signed_off: boolean;
};

type Performer = {
  engineer_code: string;
  engineer_name: string;
  to_region: string;
  skill_goal: string;
  csat_avg: number | null;
  jobs_completed: number;
  outcome: string | null;
};

type QuarterCost = {
  quarter: string;
  rotation_count: number;
  total_cost_rupees: number;
  avg_cost_rupees: number;
  avg_duration_weeks: number;
};

type Action = {
  engineer_code: string;
  engineer_name: string;
  to_region: string;
  status: string;
  start_on: string;
  end_on: string;
  flag: string;
};

function rupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, rotRes, flowRes, outRes, chkRes, perfRes, qcRes, actRes] = await Promise.all([
    supabase.rpc('founder_r2694_rotation_kpis'),
    supabase.rpc('founder_r2694_list_rotations'),
    supabase.rpc('founder_r2694_region_flow'),
    supabase.rpc('founder_r2694_outcome_breakdown'),
    supabase.rpc('founder_r2694_skill_checkpoints'),
    supabase.rpc('founder_r2694_top_performers'),
    supabase.rpc('founder_r2694_travel_cost_by_quarter'),
    supabase.rpc('founder_r2694_action_items'),
  ]);

  const kpi: Kpi | null = (kpiRes.data && kpiRes.data[0]) || null;
  const rotations: Rotation[] = rotRes.data || [];
  const flows: RegionFlow[] = flowRes.data || [];
  const outcomes: Outcome[] = outRes.data || [];
  const checkpoints: Checkpoint[] = chkRes.data || [];
  const performers: Performer[] = perfRes.data || [];
  const quarterCosts: QuarterCost[] = qcRes.data || [];
  const actions: Action[] = actRes.data || [];

  return (
    <div className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wider text-zinc-500">Round 2694 · Engineer Operations</p>
        <h1 className="text-3xl font-semibold">Engineer Quarterly Cross-Region Rotation</h1>
        <p className="text-zinc-600 max-w-3xl">
          Quarterly rotations move senior field engineers across regions to pick up new modalities,
          unblock hospital escalations, and seed home-region expertise on return. Track every engineer
          × from-region × to-region × duration × skill goal × outcome.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-2xl border border-zinc-200 p-5">
          <div className="text-xs uppercase text-zinc-500">Total rotations</div>
          <div className="text-3xl font-semibold mt-2">{kpi?.total_rotations ?? 0}</div>
          <div className="text-xs text-zinc-500 mt-1">Across all quarters</div>
        </div>
        <div className="rounded-2xl border border-zinc-200 p-5">
          <div className="text-xs uppercase text-zinc-500">Active</div>
          <div className="text-3xl font-semibold mt-2">{kpi?.active_rotations ?? 0}</div>
          <div className="text-xs text-zinc-500 mt-1">{kpi?.planned_rotations ?? 0} planned next</div>
        </div>
        <div className="rounded-2xl border border-zinc-200 p-5">
          <div className="text-xs uppercase text-zinc-500">Avg CSAT</div>
          <div className="text-3xl font-semibold mt-2">{kpi?.avg_csat ?? '-'}</div>
          <div className="text-xs text-zinc-500 mt-1">Bar: 4.20 & above</div>
        </div>
        <div className="rounded-2xl border border-zinc-200 p-5">
          <div className="text-xs uppercase text-zinc-500">Travel spend</div>
          <div className="text-3xl font-semibold mt-2">{rupees(kpi?.total_travel_cost_rupees)}</div>
          <div className="text-xs text-zinc-500 mt-1">Avg {kpi?.avg_duration_weeks ?? '-'} wks</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">All rotations</h2>
        <p className="text-sm text-zinc-600">
          Engineer × quarter × from → to region with skill goal and outcome.
        </p>
        <DataTable
          rows={rotations}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: Rotation) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Rotation) => r.engineer_name },
            { key: 'quarter', header: 'Quarter', render: (r: Rotation) => r.quarter },
            { key: 'route', header: 'Route', render: (r: Rotation) => r.from_region + ' → ' + r.to_region },
            { key: 'duration_weeks', header: 'Weeks', render: (r: Rotation) => String(r.duration_weeks) },
            { key: 'skill_goal', header: 'Skill goal', render: (r: Rotation) => r.skill_goal },
            { key: 'status', header: 'Status', render: (r: Rotation) => r.status },
            { key: 'outcome', header: 'Outcome', render: (r: Rotation) => r.outcome ?? '-' },
            { key: 'jobs_completed', header: 'Jobs', render: (r: Rotation) => String(r.jobs_completed) },
            { key: 'csat_avg', header: 'CSAT', render: (r: Rotation) => r.csat_avg == null ? '-' : String(r.csat_avg) },
            { key: 'travel_cost_rupees', header: 'Cost', render: (r: Rotation) => rupees(r.travel_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Rotation, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Region flow matrix</h2>
        <p className="text-sm text-zinc-600">
          Counts roll up by from-region → to-region pair.
        </p>
        <DataTable
          rows={flows}
          columns={[
            { key: 'from_region', header: 'From', render: (r: RegionFlow) => r.from_region },
            { key: 'to_region', header: 'To', render: (r: RegionFlow) => r.to_region },
            { key: 'rotation_count', header: 'Rotations', render: (r: RegionFlow) => String(r.rotation_count) },
            { key: 'total_weeks', header: 'Total weeks', render: (r: RegionFlow) => String(r.total_weeks) },
            { key: 'avg_csat', header: 'Avg CSAT', render: (r: RegionFlow) => r.avg_csat == null ? '-' : String(r.avg_csat) },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: RegionFlow) => rupees(r.total_cost_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionFlow, i: number) => r.from_region + '-' + r.to_region + '-' + i}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Outcome breakdown</h2>
          <DataTable
            rows={outcomes}
            columns={[
              { key: 'outcome_bucket', header: 'Outcome', render: (r: Outcome) => r.outcome_bucket },
              { key: 'rotation_count', header: 'Count', render: (r: Outcome) => String(r.rotation_count) },
              { key: 'avg_jobs_completed', header: 'Avg jobs', render: (r: Outcome) => r.avg_jobs_completed == null ? '-' : String(r.avg_jobs_completed) },
              { key: 'avg_csat', header: 'Avg CSAT', render: (r: Outcome) => r.avg_csat == null ? '-' : String(r.avg_csat) },
            ]}
            emptyMessage="No data"
            rowKey={(r: Outcome, i: number) => r.outcome_bucket + '-' + i}
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-xl font-semibold">Travel cost by quarter</h2>
          <DataTable
            rows={quarterCosts}
            columns={[
              { key: 'quarter', header: 'Quarter', render: (r: QuarterCost) => r.quarter },
              { key: 'rotation_count', header: 'Rotations', render: (r: QuarterCost) => String(r.rotation_count) },
              { key: 'total_cost_rupees', header: 'Total', render: (r: QuarterCost) => rupees(r.total_cost_rupees) },
              { key: 'avg_cost_rupees', header: 'Avg', render: (r: QuarterCost) => rupees(r.avg_cost_rupees) },
              { key: 'avg_duration_weeks', header: 'Avg wks', render: (r: QuarterCost) => String(r.avg_duration_weeks) },
            ]}
            emptyMessage="No data"
            rowKey={(r: QuarterCost, i: number) => r.quarter + '-' + i}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Skill checkpoints</h2>
        <p className="text-sm text-zinc-600">
          Proficiency delta captured per checkpoint. Sign-off gated by mentor.
        </p>
        <DataTable
          rows={checkpoints}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: Checkpoint) => r.engineer_code + ' ' + r.engineer_name },
            { key: 'skill_area', header: 'Skill area', render: (r: Checkpoint) => r.skill_area },
            { key: 'proficiency_before', header: 'Before', render: (r: Checkpoint) => String(r.proficiency_before) },
            { key: 'proficiency_after', header: 'After', render: (r: Checkpoint) => String(r.proficiency_after) },
            { key: 'delta', header: 'Delta', render: (r: Checkpoint) => '+' + r.delta },
            { key: 'mentor_code', header: 'Mentor', render: (r: Checkpoint) => r.mentor_code },
            { key: 'signed_off', header: 'Signed off', render: (r: Checkpoint) => r.signed_off ? 'yes' : 'no' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Checkpoint, i: number) => r.engineer_code + '-' + r.skill_area + '-' + i}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top performers</h2>
        <p className="text-sm text-zinc-600">Ranked by CSAT & jobs completed in their host region.</p>
        <DataTable
          rows={performers}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: Performer) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Performer) => r.engineer_name },
            { key: 'to_region', header: 'Host region', render: (r: Performer) => r.to_region },
            { key: 'skill_goal', header: 'Skill goal', render: (r: Performer) => r.skill_goal },
            { key: 'csat_avg', header: 'CSAT', render: (r: Performer) => r.csat_avg == null ? '-' : String(r.csat_avg) },
            { key: 'jobs_completed', header: 'Jobs', render: (r: Performer) => String(r.jobs_completed) },
            { key: 'outcome', header: 'Outcome', render: (r: Performer) => r.outcome ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Performer, i: number) => r.engineer_code + '-' + i}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Action items</h2>
        <p className="text-sm text-zinc-600">
          Kickoffs due within 14 days, wrap-ups within 14 days, or active rotations with CSAT below 4.20.
        </p>
        <DataTable
          rows={actions}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: Action) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Action) => r.engineer_name },
            { key: 'to_region', header: 'Host region', render: (r: Action) => r.to_region },
            { key: 'status', header: 'Status', render: (r: Action) => r.status },
            { key: 'start_on', header: 'Start', render: (r: Action) => r.start_on },
            { key: 'end_on', header: 'End', render: (r: Action) => r.end_on },
            { key: 'flag', header: 'Flag', render: (r: Action) => r.flag },
          ]}
          emptyMessage="No data"
          rowKey={(r: Action, i: number) => r.engineer_code + '-' + i}
        />
      </section>
    </div>
  );
}