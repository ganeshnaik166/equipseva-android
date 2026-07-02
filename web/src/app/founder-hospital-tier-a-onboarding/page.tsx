import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n == null) return '-';
  return Number(n).toFixed(1) + '%';
}

function fmtNum(n: number | null | undefined, digits = 1): string {
  if (n == null) return '-';
  return Number(n).toFixed(digits);
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('en-IN');
}

export default async function FounderHospitalTierAOnboardingPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let hospitals: any[] = [];
  let pendingReview: any[] = [];
  let blockedSteps: any[] = [];
  let stepBreakdown: any[] = [];
  let recentLaunches: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_tier_a_overview');
    overview = r.data && r.data[0] ? r.data[0] : null;
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_tier_a_hospitals');
    hospitals = r.data ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_tier_a_pending_review');
    pendingReview = r.data ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_tier_a_blocked_steps');
    blockedSteps = r.data ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_tier_a_step_breakdown');
    stepBreakdown = r.data ?? [];
  } catch {}

  try {
    const r = await sb.rpc('rpc_founder_tier_a_recent_launches');
    recentLaunches = r.data ?? [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Total Hospitals', value: overview?.total_hospitals ?? 0 },
    { label: 'In Progress', value: overview?.in_progress ?? 0 },
    { label: 'Launched', value: overview?.launched ?? 0 },
    { label: 'On Hold', value: overview?.on_hold ?? 0 },
    { label: 'Pending', value: overview?.pending ?? 0 },
    { label: 'Dropped', value: overview?.dropped ?? 0 },
    { label: 'Total Steps', value: overview?.total_steps ?? 0 },
    { label: 'Steps Done', value: overview?.steps_done ?? 0 },
    { label: 'Steps Blocked', value: overview?.steps_blocked ?? 0 },
    { label: 'Pending Founder Review', value: overview?.steps_pending_review ?? 0 },
    { label: 'Contracted Value', value: fmtRupees(overview?.total_contract_value_rupees) },
    { label: 'Avg Days To Launch', value: fmtNum(overview?.avg_days_to_launch) },
    { label: 'Hospitals In Pipeline', value: hospitals.length },
    { label: 'Recent Launches (25)', value: recentLaunches.length },
    { label: 'Blocked Steps Listed', value: blockedSteps.length },
    { label: 'Pending Review Listed', value: pendingReview.length },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'tier_a_rank', header: 'Rank', render: (r: any) => r.tier_a_rank ?? '-' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '-' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '-' },
    { key: 'playbook_status', header: 'Status', render: (r: any) => r.playbook_status ?? '-' },
    { key: 'progress', header: 'Progress', render: (r: any) => (r.steps_done ?? 0) + '/' + (r.steps_total ?? 0) },
    { key: 'pct_complete', header: 'Pct', render: (r: any) => fmtPct(r.pct_complete) },
    { key: 'target_launch_date', header: 'Target', render: (r: any) => fmtDate(r.target_launch_date) },
    { key: 'contract_value_rupees', header: 'Contract', render: (r: any) => fmtRupees(r.contract_value_rupees) },
    { key: 'days_in_progress', header: 'Days', render: (r: any) => fmtNum(r.days_in_progress) },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'step_no', header: 'Step', render: (r: any) => r.step_no ?? '-' },
    { key: 'step_name', header: 'Name', render: (r: any) => r.step_name ?? '-' },
    { key: 'step_owner', header: 'Owner', render: (r: any) => r.step_owner ?? '-' },
    { key: 'completed_at', header: 'Done At', render: (r: any) => fmtDate(r.completed_at) },
    { key: 'days_waiting', header: 'Days Waiting', render: (r: any) => fmtNum(r.days_waiting) },
  ];

  const blockedCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'step_no', header: 'Step', render: (r: any) => r.step_no ?? '-' },
    { key: 'step_name', header: 'Name', render: (r: any) => r.step_name ?? '-' },
    { key: 'step_owner', header: 'Owner', render: (r: any) => r.step_owner ?? '-' },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'days_blocked', header: 'Days Blocked', render: (r: any) => fmtNum(r.days_blocked) },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'step_no', header: 'Step', render: (r: any) => r.step_no ?? '-' },
    { key: 'step_name', header: 'Name', render: (r: any) => r.step_name ?? '-' },
    { key: 'total', header: 'Total', render: (r: any) => r.total ?? 0 },
    { key: 'done', header: 'Done', render: (r: any) => r.done ?? 0 },
    { key: 'in_progress', header: 'In Progress', render: (r: any) => r.in_progress ?? 0 },
    { key: 'blocked', header: 'Blocked', render: (r: any) => r.blocked ?? 0 },
    { key: 'todo', header: 'Todo', render: (r: any) => r.todo ?? 0 },
    { key: 'pct_done', header: 'Pct Done', render: (r: any) => fmtPct(r.pct_done) },
  ];

  const launchCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'tier_a_rank', header: 'Rank', render: (r: any) => r.tier_a_rank ?? '-' },
    { key: 'actual_launch_at', header: 'Launched', render: (r: any) => fmtDate(r.actual_launch_at) },
    { key: 'contract_value_rupees', header: 'Contract', render: (r: any) => fmtRupees(r.contract_value_rupees) },
    { key: 'days_to_launch', header: 'Days', render: (r: any) => fmtNum(r.days_to_launch) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Hospital Tier-A Onboarding Playbook</h1>
        <p className="text-sm text-gray-600">
          Top-50 hospitals get white-glove onboarding: CEO visit, dedicated engineer, CTO call. 10-step checklist with founder review at each step.
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="border rounded p-3 bg-white">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier-A Hospitals (by rank)</h2>
        <DataTable rowKey={(r: any) => r.id} columns={hospitalCols} rows={hospitals} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Steps Pending Founder Review</h2>
        <DataTable rowKey={(r: any) => r.step_id} columns={pendingCols} rows={pendingReview} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Blocked Steps</h2>
        <DataTable rowKey={(r: any) => r.step_id} columns={blockedCols} rows={blockedSteps} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Step Breakdown (10-step checklist)</h2>
        <DataTable rowKey={(r: any) => String(r.step_no)} columns={breakdownCols} rows={stepBreakdown} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Launches</h2>
        <DataTable rowKey={(r: any) => r.id} columns={launchCols} rows={recentLaunches} />
      </section>
    </div>
  );
}
