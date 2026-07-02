import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

export default async function FounderEngineerFirstJobOnboardingPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let stuck: any[] = [];
  let completions: any[] = [];
  let cohorts: any[] = [];
  let reviews: any[] = [];
  let tiers: any[] = [];
  let untracked: any[] = [];

  try {
    const r = await sb.rpc('founder_efjo_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_efjo_stuck_engineers');
    stuck = r.data || [];
  } catch { stuck = []; }

  try {
    const r = await sb.rpc('founder_efjo_recent_completions');
    completions = r.data || [];
  } catch { completions = []; }

  try {
    const r = await sb.rpc('founder_efjo_cohort_breakdown');
    cohorts = r.data || [];
  } catch { cohorts = []; }

  try {
    const r = await sb.rpc('founder_efjo_recent_reviews');
    reviews = r.data || [];
  } catch { reviews = []; }

  try {
    const r = await sb.rpc('founder_efjo_tier_distribution');
    tiers = r.data || [];
  } catch { tiers = []; }

  try {
    const r = await sb.rpc('founder_efjo_untracked_engineers');
    untracked = r.data || [];
  } catch { untracked = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total Tracked', value: kpis.total_tracked ?? 0 },
    { label: 'In Progress', value: kpis.in_progress_count ?? 0 },
    { label: 'Completed On-Time', value: kpis.completed_on_time ?? 0 },
    { label: 'Completed Late', value: kpis.completed_late ?? 0 },
    { label: 'Stuck', value: kpis.stuck_count ?? 0 },
    { label: 'Churned', value: kpis.churned_count ?? 0 },
    { label: 'Founder-Extended', value: kpis.founder_extended_count ?? 0 },
    { label: 'On-Time Rate %', value: `${kpis.on_time_rate_pct ?? 0}%` },
    { label: 'Avg Days to First Job', value: kpis.avg_days_to_first_job ?? 0 },
    { label: 'Median Days', value: kpis.median_days_to_first_job ?? 0 },
    { label: 'Fastest (days)', value: kpis.fastest_days ?? 0 },
    { label: 'Slowest (days)', value: kpis.slowest_days ?? 0 },
    { label: 'Due Within 3 Days', value: kpis.due_within_3_days ?? 0 },
    { label: 'Overdue', value: kpis.overdue_count ?? 0 },
    { label: 'Extensions Granted', value: kpis.extensions_granted ?? 0 },
    { label: 'Total Extension Days', value: kpis.total_extension_days ?? 0 },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'engineer_phone', header: 'Phone', render: (r: any) => r.engineer_phone ?? "—" },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? "—" },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'days_elapsed', header: 'Days Elapsed', render: (r: any) => r.days_elapsed ?? "—" },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue ?? "—" },
    { key: 'extension_days', header: 'Ext Days', render: (r: any) => r.extension_days ?? 0 },
    { key: 'deadline_at', header: 'Deadline', render: (r: any) => r.deadline_at ? new Date(r.deadline_at).toLocaleDateString() : "—" },
  ];

  const completionCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? "—" },
    { key: 'days_to_first_job', header: 'Days to 1st Job', render: (r: any) => r.days_to_first_job ?? "—" },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? "—" },
    { key: 'first_paid_at', header: 'First Paid', render: (r: any) => r.first_paid_at ? new Date(r.first_paid_at).toLocaleDateString() : "—" },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'cohort_week', header: 'Week', render: (r: any) => r.cohort_week ? new Date(r.cohort_week).toLocaleDateString() : "—" },
    { key: 'cohort_size', header: 'Size', render: (r: any) => r.cohort_size ?? 0 },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count ?? 0 },
    { key: 'on_time_count', header: 'On-Time', render: (r: any) => r.on_time_count ?? 0 },
    { key: 'stuck_count', header: 'Stuck', render: (r: any) => r.stuck_count ?? 0 },
    { key: 'on_time_rate_pct', header: 'On-Time %', render: (r: any) => `${r.on_time_rate_pct ?? 0}%` },
    { key: 'avg_days', header: 'Avg Days', render: (r: any) => r.avg_days ?? "—" },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email ?? "—" },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? "—" },
    { key: 'extension_days', header: 'Ext Days', render: (r: any) => r.extension_days ?? 0 },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? "—" },
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : "—" },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? "—" },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count ?? 0 },
    { key: 'on_time_count', header: 'On-Time', render: (r: any) => r.on_time_count ?? 0 },
    { key: 'stuck_count', header: 'Stuck', render: (r: any) => r.stuck_count ?? 0 },
    { key: 'on_time_rate_pct', header: 'On-Time %', render: (r: any) => `${r.on_time_rate_pct ?? 0}%` },
    { key: 'avg_days', header: 'Avg Days', render: (r: any) => r.avg_days ?? "—" },
  ];

  return (
    <div style={{ padding: '24px', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer First-Job Onboarding</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>r1562 — every new engineer must complete first paid job within 14 days. Track time-to-first-job and review stuck onboardings.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {kpiCards.map((k, i) => (
          <div key={i} style={{ padding: 16, border: '1px solid #e0e0e0', borderRadius: 8, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#666', marginBottom: 6 }}>{k.label}</div>
            <div style={{ fontSize: 22, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Stuck or Due-Soon Engineers</h2>
        <DataTable columns={stuckCols} rows={stuck} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent First-Job Completions</h2>
        <DataTable columns={completionCols} rows={completions} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Cohort Breakdown (last 12 weeks)</h2>
        <DataTable columns={cohortCols} rows={cohorts} rowKey={(r: any) => r.cohort_week} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Tier Distribution</h2>
        <DataTable columns={tierCols} rows={tiers} rowKey={(r: any) => r.tier} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Founder Reviews</h2>
        <DataTable columns={reviewCols} rows={reviews} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Untracked Engineers (need backfill)</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>Engineers without an onboarding row — backfill creates 14-day window from their signup date.</p>
        <DataTable
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
            { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? "—" },
            { key: 'days_since_signup', header: 'Days Since Signup', render: (r: any) => r.days_since_signup ?? "—" },
            { key: 'engineer_created_at', header: 'Joined', render: (r: any) => r.engineer_created_at ? new Date(r.engineer_created_at).toLocaleDateString() : "—" },
          ]}
          rows={untracked}
          rowKey={(r: any) => r.engineer_id}
        />
      </section>
    </div>
  );
}
