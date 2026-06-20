import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any, digits = 0): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN', { maximumFractionDigits: digits });
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(1) + '%';
}

function fmtDate(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString('en-IN'); } catch { return String(d); }
}

function fmtDateTime(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return String(d); }
}

export default async function FounderHospitalSatisfactionDrilldownPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let list: any[] = [];
  let trend: any[] = [];
  let nps: any[] = [];
  let ladder: any[] = [];
  let signals: any[] = [];

  try {
    const r = await sb.rpc('founder_hospital_satisfaction_overview_v2');
    overview = (r.data && r.data[0]) || null;
  } catch (_e) { overview = null; }

  try {
    const r = await sb.rpc('founder_hospital_satisfaction_list_v2');
    list = (r.data as any[]) || [];
  } catch (_e) { list = []; }

  try {
    const firstId = list && list[0] && list[0].hospital_org_id;
    if (firstId) {
      const r = await sb.rpc('founder_hospital_satisfaction_trend_v2', { p_hospital_org_id: firstId });
      trend = (r.data as any[]) || [];
    }
  } catch (_e) { trend = []; }

  try {
    const r = await sb.rpc('founder_hospital_nps_responses_v2');
    nps = (r.data as any[]) || [];
  } catch (_e) { nps = []; }

  try {
    const r = await sb.rpc('founder_hospital_action_ladder_list_v2');
    ladder = (r.data as any[]) || [];
  } catch (_e) { ladder = []; }

  try {
    const r = await sb.rpc('founder_hospital_escalation_signals_v2');
    signals = (r.data as any[]) || [];
  } catch (_e) { signals = []; }

  const focusHospital = (list && list[0]) || null;

  const kpis: Kpi[] = [
    { label: 'Hospitals tracked', value: fmtNum(overview?.total_hospitals) },
    { label: 'Green band', value: fmtNum(overview?.green_band) },
    { label: 'Amber band', value: fmtNum(overview?.amber_band) },
    { label: 'Red band', value: fmtNum(overview?.red_band) },
    { label: 'Avg NPS', value: fmtNum(overview?.avg_nps, 1) },
    { label: 'Avg rating', value: fmtNum(overview?.avg_rating, 2) },
    { label: 'Responses 30d', value: fmtNum(overview?.total_responses_30d) },
    { label: 'Escalations', value: fmtNum(overview?.total_escalations) },
    { label: 'Open disputes', value: fmtNum(overview?.total_disputes) },
    { label: 'Avg recurrence', value: fmtPct(overview?.recurrence_rate_avg) },
    { label: 'Live NPS samples', value: fmtNum(nps.length) },
    { label: 'Ladder events', value: fmtNum(ladder.length) },
    { label: 'Hot signals', value: fmtNum(signals.length) },
    { label: 'Focus hospital', value: focusHospital?.hospital_name ?? '—' },
    { label: 'Focus NPS', value: fmtNum(focusHospital?.nps_score, 1) },
    { label: 'Focus band', value: focusHospital?.health_band ?? '—' },
  ];

  const listColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '—') },
    { key: 'state', header: 'State', render: (r: any) => String(r.state ?? '—') },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => fmtNum(r.avg_rating, 2) },
    { key: 'response_count', header: 'Resp.', render: (r: any) => fmtNum(r.response_count) },
    { key: 'recurrence_rate', header: 'Recur.', render: (r: any) => fmtPct(r.recurrence_rate) },
    { key: 'escalation_count', header: 'Esc.', render: (r: any) => fmtNum(r.escalation_count) },
    { key: 'dispute_count', header: 'Disputes', render: (r: any) => fmtNum(r.dispute_count) },
    { key: 'health_band', header: 'Band', render: (r: any) => String(r.health_band ?? '—') },
    { key: 'snapshot_date', header: 'As of', render: (r: any) => fmtDate(r.snapshot_date) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => fmtDate(r.snapshot_date) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => fmtNum(r.avg_rating, 2) },
    { key: 'response_count', header: 'Resp.', render: (r: any) => fmtNum(r.response_count) },
    { key: 'recurrence_rate', header: 'Recur.', render: (r: any) => fmtPct(r.recurrence_rate) },
    { key: 'escalation_count', header: 'Esc.', render: (r: any) => fmtNum(r.escalation_count) },
    { key: 'dispute_count', header: 'Disputes', render: (r: any) => fmtNum(r.dispute_count) },
    { key: 'health_band', header: 'Band', render: (r: any) => String(r.health_band ?? '—') },
  ];

  const npsColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'rating', header: 'Rating', render: (r: any) => fmtNum(r.rating) },
    { key: 'job_kind', header: 'Kind', render: (r: any) => String(r.job_kind ?? '—') },
    { key: 'rated_at', header: 'Rated', render: (r: any) => fmtDateTime(r.rated_at) },
    { key: 'job_id', header: 'Job', render: (r: any) => String(r.job_id ?? '—').slice(0, 8) },
  ];

  const ladderColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'rung', header: 'Rung', render: (r: any) => String(r.rung ?? '—') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '—') },
    { key: 'taken_at', header: 'When', render: (r: any) => fmtDateTime(r.taken_at) },
  ];

  const signalsColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'open_disputes', header: 'Open disputes', render: (r: any) => fmtNum(r.open_disputes) },
    { key: 'red_jobs_30d', header: 'Red jobs 30d', render: (r: any) => fmtNum(r.red_jobs_30d) },
    { key: 'low_rating_30d', header: 'Low rating 30d', render: (r: any) => fmtNum(r.low_rating_30d) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <div style={{ fontSize: '12px', color: '#888', textTransform: 'uppercase', letterSpacing: '0.08em' }}>r1543 HEAVY</div>
        <h1 style={{ fontSize: '28px', fontWeight: 700, margin: '4px 0 8px' }}>Hospital Satisfaction Drilldown</h1>
        <p style={{ color: '#555', margin: 0 }}>
          Per-hospital NPS history, recurrence rate, escalations and dispute count, with founder action ladder.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '12px 14px', background: '#fff' }}>
            <div style={{ fontSize: '11px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.06em' }}>{k.label}</div>
            <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>Hospitals — latest posture</h2>
        <DataTable columns={listColumns} rows={list} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>
          Trend — {focusHospital?.hospital_name ?? 'no focus hospital'} (90d)
        </h2>
        <DataTable columns={trendColumns} rows={trend} rowKey={(r: any) => String(r.snapshot_date)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>Live NPS responses (30d)</h2>
        <DataTable columns={npsColumns} rows={nps} rowKey={(r: any) => r.job_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>Escalation signals</h2>
        <DataTable columns={signalsColumns} rows={signals} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, margin: '0 0 12px' }}>Founder action ladder</h2>
        <DataTable columns={ladderColumns} rows={ladder} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
