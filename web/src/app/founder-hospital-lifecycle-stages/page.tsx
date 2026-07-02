import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

export const dynamic = 'force-dynamic';

export default async function FounderHospitalLifecycleStagesPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let cohort: any[] = [];
  let current: any[] = [];
  let pending: any[] = [];
  let atRisk: any[] = [];
  let funnel: any[] = [];

  try {
    const r = await sb.rpc('founder_lifecycle_stage_cohort_v2');
    cohort = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_lifecycle_hospital_current_stage_v2');
    current = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_lifecycle_pending_reviews_v2');
    pending = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_lifecycle_at_risk_watch_v2');
    atRisk = (r.data as any[]) ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_lifecycle_funnel_v2');
    funnel = (r.data as any[]) ?? [];
  } catch {}
  try {
    await sb.rpc('log_founder_lifecycle_view_dashboard_v2');
  } catch {}

  const stageCount = (s: string) => Number(cohort.find((c: any) => c.stage === s)?.hospital_count ?? 0);
  const stageAvg = (s: string) => Number(cohort.find((c: any) => c.stage === s)?.avg_dwell_days ?? 0);
  const totalHospitals = cohort.reduce((a: number, c: any) => a + Number(c.hospital_count ?? 0), 0);

  const kpis: Kpi[] = [
    { label: 'Total Hospitals Tracked', value: totalHospitals },
    { label: 'Onboarded', value: stageCount('onboarded') },
    { label: 'AMC Active', value: stageCount('amc_active') },
    { label: 'Expansion', value: stageCount('expansion') },
    { label: 'Mature', value: stageCount('mature') },
    { label: 'At Risk', value: stageCount('at_risk') },
    { label: 'Churned', value: stageCount('churned') },
    { label: 'Renewed', value: stageCount('renewed') },
    { label: 'Avg Onboarded Dwell (d)', value: stageAvg('onboarded') },
    { label: 'Avg AMC Active Dwell (d)', value: stageAvg('amc_active') },
    { label: 'Avg Expansion Dwell (d)', value: stageAvg('expansion') },
    { label: 'Avg Mature Dwell (d)', value: stageAvg('mature') },
    { label: 'Pending Founder Reviews', value: pending.length },
    { label: 'At-Risk Watchlist', value: atRisk.length },
    { label: 'Transitions Last 90d', value: funnel.reduce((a: number, f: any) => a + Number(f.entered_90d ?? 0), 0) },
    { label: 'Churn Last 90d', value: Number(funnel.find((f: any) => f.stage === 'churned')?.entered_90d ?? 0) },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => r.hospital_count ?? '—' },
    { key: 'avg_dwell_days', header: 'Avg Dwell (d)', render: (r: any) => r.avg_dwell_days ?? '—' },
    { key: 'median_dwell_days', header: 'Median Dwell (d)', render: (r: any) => r.median_dwell_days ?? '—' },
    { key: 'oldest_in_stage_days', header: 'Oldest (d)', render: (r: any) => r.oldest_in_stage_days ?? '—' },
  ];

  const currentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'days_in_stage', header: 'Days In Stage', render: (r: any) => r.days_in_stage ?? '—' },
    { key: 'reviewed_by_founder_at', header: 'Last Reviewed', render: (r: any) => r.reviewed_by_founder_at ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'from_stage', header: 'From', render: (r: any) => r.from_stage ?? '—' },
    { key: 'to_stage', header: 'To', render: (r: any) => r.to_stage ?? '—' },
    { key: 'transitioned_at', header: 'When', render: (r: any) => r.transitioned_at ?? '—' },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '—' },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'days_in_stage', header: 'Days In Stage', render: (r: any) => r.days_in_stage ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'entered_90d', header: 'Entered 90d', render: (r: any) => r.entered_90d ?? '—' },
    { key: 'exited_90d', header: 'Exited 90d', render: (r: any) => r.exited_90d ?? '—' },
    { key: 'net_change', header: 'Net Change', render: (r: any) => r.net_change ?? '—' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Lifecycle Stages</h1>
        <p style={{ color: '#666' }}>Onboarded → AMC Active → Expansion → Mature → At-Risk → Churned/Renewed</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        {kpis.map((k: Kpi) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stage Cohort Summary</h2>
        <DataTable columns={cohortCols} rows={cohort} rowKey={(r: any) => r.stage} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Current Stage Per Hospital</h2>
        <DataTable columns={currentCols} rows={current} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending Founder Reviews</h2>
        <DataTable columns={pendingCols} rows={pending} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>At-Risk Watchlist</h2>
        <DataTable columns={atRiskCols} rows={atRisk} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>90-Day Stage Funnel</h2>
        <DataTable columns={funnelCols} rows={funnel} rowKey={(r: any) => r.stage} />
      </section>
    </div>
  );
}
