import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? v.toLocaleString('en-IN') : '0';
}
function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  return '₹' + (Number.isFinite(v) ? v.toLocaleString('en-IN') : '0');
}
function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let openPlans: any[] = [];
  let closedPlans: any[] = [];
  let stepBreakdown: any[] = [];
  let recentSteps: any[] = [];

  try {
    const r = await sb.rpc('founder_save_plan_kpis');
    kpis = r.data ?? {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_save_plan_list_open');
    openPlans = (r.data as any[]) ?? [];
  } catch { openPlans = []; }
  try {
    const r = await sb.rpc('founder_save_plan_list_closed', { p_limit: 50 });
    closedPlans = (r.data as any[]) ?? [];
  } catch { closedPlans = []; }
  try {
    const r = await sb.rpc('founder_save_plan_step_breakdown');
    stepBreakdown = (r.data as any[]) ?? [];
  } catch { stepBreakdown = []; }
  try {
    const r = await sb.rpc('founder_save_plan_recent_steps', { p_limit: 30 });
    recentSteps = (r.data as any[]) ?? [];
  } catch { recentSteps = []; }

  const cards: Kpi[] = [
    { label: 'Total plans', value: fmtInt(kpis.total_plans) },
    { label: 'Open', value: fmtInt(kpis.open_plans) },
    { label: 'In progress', value: fmtInt(kpis.in_progress_plans) },
    { label: 'Saved', value: fmtInt(kpis.saved_plans) },
    { label: 'Lost', value: fmtInt(kpis.lost_plans) },
    { label: 'Cancelled', value: fmtInt(kpis.cancelled_plans) },
    { label: 'Save rate %', value: fmtInt(kpis.save_rate_pct) },
    { label: 'Plans 30d', value: fmtInt(kpis.plans_last_30d) },
    { label: 'Saved 30d', value: fmtInt(kpis.saved_last_30d) },
    { label: 'Lost 30d', value: fmtInt(kpis.lost_last_30d) },
    { label: 'ARR at risk', value: fmtRupees(kpis.total_arr_at_risk_rupees) },
    { label: 'ARR saved', value: fmtRupees(kpis.total_arr_saved_rupees) },
    { label: 'ARR lost', value: fmtRupees(kpis.total_arr_lost_rupees) },
    { label: 'Avg close hrs', value: fmtInt(kpis.avg_close_hours) },
    { label: 'Steps total', value: fmtInt(kpis.steps_total) },
    { label: 'Steps pending', value: fmtInt(kpis.steps_pending) },
  ];

  const openCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'risk_score', header: 'Risk', render: (r: any) => fmtInt(r.risk_score) },
    { key: 'risk_reason', header: 'Reason', render: (r: any) => r.risk_reason ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'expected_arr_rupees', header: 'ARR', render: (r: any) => fmtRupees(r.expected_arr_rupees) },
    { key: 'progress', header: 'Steps', render: (r: any) => fmtInt(r.steps_done) + '/' + fmtInt(r.steps_total) },
  ];

  const closedCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'status', header: 'Outcome', render: (r: any) => r.status ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'expected_arr_rupees', header: 'Expected ARR', render: (r: any) => fmtRupees(r.expected_arr_rupees) },
    { key: 'saved_arr_rupees', header: 'Saved ARR', render: (r: any) => fmtRupees(r.saved_arr_rupees) },
    { key: 'close_hours', header: 'Close hrs', render: (r: any) => fmtInt(r.close_hours) },
  ];

  const stepCols: Column<any>[] = [
    { key: 'step_kind', header: 'Step', render: (r: any) => r.step_kind ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtInt(r.total) },
    { key: 'done', header: 'Done', render: (r: any) => fmtInt(r.done) },
    { key: 'pending', header: 'Pending', render: (r: any) => fmtInt(r.pending) },
    { key: 'failed', header: 'Failed', render: (r: any) => fmtInt(r.failed) },
    { key: 'success_rate_pct', header: 'Success %', render: (r: any) => fmtInt(r.success_rate_pct) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'step_kind', header: 'Step', render: (r: any) => r.step_kind ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_for) },
    { key: 'done_at', header: 'Done', render: (r: any) => fmtDate(r.done_at) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Hospital churn save-plan</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>Spin up save plans for at-risk hospitals. Track step success rate and ARR saved.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 10, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#777', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Open and in-progress plans</h2>
      <DataTable columns={openCols} rows={openPlans} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Step breakdown by kind</h2>
      <DataTable columns={stepCols} rows={stepBreakdown} rowKey={(r: any) => r.step_kind} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent step activity</h2>
      <DataTable columns={recentCols} rows={recentSteps} rowKey={(r: any) => r.step_id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Closed plans</h2>
      <DataTable columns={closedCols} rows={closedPlans} rowKey={(r: any) => r.id} />
    </main>
  );
}
