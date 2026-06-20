import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderExecutiveHirePipelinePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let funnel: any[] = [];
  let active: any[] = [];
  let offers: any[] = [];
  let ramped: any[] = [];
  let calibration: any[] = [];
  let events: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_exec_kpis_v2');
    kpis = (r.data && r.data[0]) || null;
  } catch { kpis = null; }

  try {
    const r = await sb.rpc('rpc_founder_exec_pipeline_funnel_v2');
    funnel = (r.data as any[]) || [];
  } catch { funnel = []; }

  try {
    const r = await sb.rpc('rpc_founder_exec_active_pipeline_v2');
    active = (r.data as any[]) || [];
  } catch { active = []; }

  try {
    const r = await sb.rpc('rpc_founder_exec_offers_v2');
    offers = (r.data as any[]) || [];
  } catch { offers = []; }

  try {
    const r = await sb.rpc('rpc_founder_exec_ramped_v2');
    ramped = (r.data as any[]) || [];
  } catch { ramped = []; }

  try {
    const r = await sb.rpc('rpc_founder_exec_calibration_v2');
    calibration = (r.data as any[]) || [];
  } catch { calibration = []; }

  try {
    const r = await sb.rpc('rpc_founder_exec_recent_events_v2');
    events = (r.data as any[]) || [];
  } catch { events = []; }

  const k: Kpi[] = [
    { label: 'Total candidates', value: String(kpis?.total_candidates ?? 0) },
    { label: 'Active pipeline', value: String(kpis?.active_pipeline ?? 0) },
    { label: 'Source', value: String(kpis?.in_source ?? 0) },
    { label: 'Screen', value: String(kpis?.in_screen ?? 0) },
    { label: 'Onsite', value: String(kpis?.in_onsite ?? 0) },
    { label: 'Offer out', value: String(kpis?.in_offer ?? 0) },
    { label: 'Signed total', value: String(kpis?.signed_total ?? 0) },
    { label: 'Ramped total', value: String(kpis?.ramped_total ?? 0) },
    { label: 'Departed total', value: String(kpis?.departed_total ?? 0) },
    { label: 'VP candidates', value: String(kpis?.vp_count ?? 0) },
    { label: 'C-level candidates', value: String(kpis?.c_level_count ?? 0) },
    { label: 'Avg comp offered (L)', value: String(kpis?.avg_comp_offered ?? '—') },
    { label: 'Max equity (bps)', value: String(kpis?.max_equity_bps ?? 0) },
    { label: 'Avg calibration', value: String(kpis?.avg_calibration ?? '—') },
    { label: 'Offer acceptance %', value: String(kpis?.offer_acceptance_pct ?? 0) + '%' },
    { label: 'Ramp success %', value: String(kpis?.ramp_success_pct ?? 0) + '%' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'cand_count', header: 'Candidates', render: (r: any) => r.cand_count ?? 0 },
    { key: 'avg_calibration', header: 'Avg calibration', render: (r: any) => r.avg_calibration ?? '—' },
    { key: 'median_days_in_stage', header: 'Median days', render: (r: any) => r.median_days_in_stage ?? '—' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name ?? '—' },
    { key: 'target_role', header: 'Role', render: (r: any) => r.target_role ?? '—' },
    { key: 'role_level', header: 'Level', render: (r: any) => r.role_level ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'source_channel', header: 'Source', render: (r: any) => r.source_channel ?? '—' },
    { key: 'calibration_score', header: 'Cal', render: (r: any) => r.calibration_score ?? '—' },
    { key: 'days_in_pipeline', header: 'Days', render: (r: any) => r.days_in_pipeline ?? '—' },
    { key: 'comp_target_lakhs', header: 'Target (L)', render: (r: any) => r.comp_target_lakhs ?? '—' },
    { key: 'recruiter_owner_email', header: 'Owner', render: (r: any) => r.recruiter_owner_email ?? '—' },
  ];

  const offersCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name ?? '—' },
    { key: 'target_role', header: 'Role', render: (r: any) => r.target_role ?? '—' },
    { key: 'comp_offered_lakhs', header: 'Comp (L)', render: (r: any) => r.comp_offered_lakhs ?? '—' },
    { key: 'equity_bps', header: 'Equity bps', render: (r: any) => r.equity_bps ?? '—' },
    { key: 'offered_at', header: 'Offered', render: (r: any) => r.offered_at ? new Date(r.offered_at).toLocaleDateString() : '—' },
    { key: 'days_to_sign', header: 'Days to sign', render: (r: any) => r.days_to_sign ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const rampedCols: Column<any>[] = [
    { key: 'candidate_name', header: 'Candidate', render: (r: any) => r.candidate_name ?? '—' },
    { key: 'target_role', header: 'Role', render: (r: any) => r.target_role ?? '—' },
    { key: 'role_level', header: 'Level', render: (r: any) => r.role_level ?? '—' },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '—' },
    { key: 'ramped_at', header: 'Ramped', render: (r: any) => r.ramped_at ? new Date(r.ramped_at).toLocaleDateString() : '—' },
    { key: 'days_to_ramp', header: 'Days to ramp', render: (r: any) => r.days_to_ramp ?? '—' },
    { key: 'tenure_days', header: 'Tenure (d)', render: (r: any) => r.tenure_days ?? '—' },
  ];

  const calibrationCols: Column<any>[] = [
    { key: 'role_level', header: 'Level', render: (r: any) => r.role_level ?? '—' },
    { key: 'cand_count', header: 'Candidates', render: (r: any) => r.cand_count ?? 0 },
    { key: 'avg_calibration', header: 'Avg cal', render: (r: any) => r.avg_calibration ?? '—' },
    { key: 'high_calibration_pct', header: 'High cal % (cal {">"}= 4)', render: (r: any) => (r.high_calibration_pct ?? 0) + '%' },
    { key: 'signed_count', header: 'Signed', render: (r: any) => r.signed_count ?? 0 },
    { key: 'ramped_count', header: 'Ramped', render: (r: any) => r.ramped_count ?? 0 },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Executive Hire Pipeline
      </h1>
      <p style={{ color: '#666', marginBottom: 16, fontSize: 13 }}>
        VP / C-level hire funnel: source {">"} screen {">"} onsite {">"} offer {">"} signed {">"} ramped {">"} departed. Calibration 1-5 (4+ = high). Separate from engineer hiring (r1346 / r1432).
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 24 }}>
        {k.map((kpi) => (
          <div key={kpi.label} style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280' }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{kpi.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>7-stage funnel</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active pipeline (top 50)</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Offers extended</h2>
        <DataTable rows={offers} columns={offersCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Signed / ramped / departed</h2>
        <DataTable rows={ramped} columns={rampedCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Calibration by level</h2>
        <DataTable rows={calibration} columns={calibrationCols} rowKey={(r: any) => r.role_level} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent stage events</h2>
        <ul style={{ fontSize: 13, lineHeight: 1.6 }}>
          {events.length === 0 && <li style={{ color: '#9ca3af' }}>{"—"} no events yet</li>}
          {events.map((e: any) => (
            <li key={e.id}>
              <span style={{ color: '#6b7280' }}>{e.event_at ? new Date(e.event_at).toLocaleString() : '—'}</span>
              {' '}
              <strong>{e.candidate_name ?? '—'}</strong>
              {' ('}{e.target_role ?? '—'}{') '}
              {e.from_stage ?? '—'} {">"} {e.to_stage ?? '—'}
              {e.actor_email ? ' by ' + e.actor_email : ''}
              {e.notes ? ' — ' + e.notes : ''}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
