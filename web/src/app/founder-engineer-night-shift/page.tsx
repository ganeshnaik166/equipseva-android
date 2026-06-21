import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function Card({ k }: { k: Kpi }) {
  return (
    <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 8, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
    </div>
  );
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let optins: any[] = [];
  let upcoming: any[] = [];
  let history: any[] = [];
  let gaps: any[] = [];

  try {
    const r = await sb.rpc('founder_night_shift_kpis');
    kpis = (r.data as any) || {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_night_shift_optins_list');
    optins = (r.data as any[]) || [];
  } catch { optins = []; }
  try {
    const r = await sb.rpc('founder_night_shift_upcoming');
    upcoming = (r.data as any[]) || [];
  } catch { upcoming = []; }
  try {
    const r = await sb.rpc('founder_night_shift_history');
    history = (r.data as any[]) || [];
  } catch { history = []; }
  try {
    const r = await sb.rpc('founder_night_shift_coverage_gaps');
    gaps = (r.data as any[]) || [];
  } catch { gaps = []; }

  const cards: Kpi[] = [
    { label: 'Opt-ins total', value: kpis.optins_total ?? '—' },
    { label: 'Willing engineers', value: kpis.optins_willing ?? '—' },
    { label: 'Avg premium (rs)', value: kpis.avg_premium_rupees ?? '—' },
    { label: 'Max premium (rs)', value: kpis.max_premium_rupees ?? '—' },
    { label: 'Avg max shifts/wk', value: kpis.avg_max_shifts_per_week ?? '—' },
    { label: 'Shifts total', value: kpis.shifts_total ?? '—' },
    { label: 'Shifts tonight', value: kpis.shifts_tonight ?? '—' },
    { label: 'Shifts this week', value: kpis.shifts_this_week ?? '—' },
    { label: 'Shifts completed', value: kpis.shifts_completed ?? '—' },
    { label: 'Shifts cancelled', value: kpis.shifts_cancelled ?? '—' },
    { label: 'Shifts no-show', value: kpis.shifts_no_show ?? '—' },
    { label: 'Code Red calls taken', value: kpis.code_red_calls_taken ?? '—' },
    { label: 'Premium paid (rs)', value: kpis.total_premium_paid_rupees ?? '—' },
    { label: 'States covered', value: kpis.states_covered ?? '—' },
    { label: 'Avg shifts/engineer', value: kpis.avg_shifts_per_engineer ?? '—' },
    { label: 'Top engineer shifts', value: kpis.top_engineer_shifts ?? '—' },
  ];

  const optinCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'willing', header: 'Willing', render: (r: any) => (r.willing ? 'yes' : 'no') },
    { key: 'premium_pay_per_shift_rupees', header: 'Premium (rs)', render: (r: any) => r.premium_pay_per_shift_rupees ?? '—' },
    { key: 'max_shifts_per_week', header: 'Max/wk', render: (r: any) => r.max_shifts_per_week ?? '—' },
    { key: 'preferred_start_hour', header: 'Start hr', render: (r: any) => r.preferred_start_hour ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => r.shift_date ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'region_state', header: 'State', render: (r: any) => r.region_state ?? '—' },
    { key: 'shift_start_at', header: 'Start', render: (r: any) => r.shift_start_at ?? '—' },
    { key: 'premium_pay_rupees', header: 'Premium', render: (r: any) => r.premium_pay_rupees ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const historyCols: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => r.shift_date ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'region_state', header: 'State', render: (r: any) => r.region_state ?? '—' },
    { key: 'premium_pay_rupees', header: 'Premium', render: (r: any) => r.premium_pay_rupees ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'code_red_calls_taken', header: 'Code Red', render: (r: any) => r.code_red_calls_taken ?? '—' },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => r.shift_date ?? '—' },
    { key: 'state', header: 'State', render: (r: any) => r.state ?? '—' },
    { key: 'engineers_scheduled', header: 'Engineers', render: (r: any) => r.engineers_scheduled ?? 0 },
    { key: 'is_gap', header: 'Gap?', render: (r: any) => (r.is_gap ? 'GAP' : 'ok') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, marginBottom: 4 }}>Engineer Night-Shift Roster</h1>
      <div style={{ color: '#666', marginBottom: 16, fontSize: 13 }}>
        Engineers willing to take emergency night-shift Code Red calls. Rotation schedule, per-shift premium pay, coverage gaps. (r1623)
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 24 }}>
        {cards.map((c, i) => <Card key={i} k={c} />)}
      </div>

      <h2 style={{ fontSize: 16, margin: '16px 0 8px' }}>Engineer opt-ins</h2>
      <DataTable columns={optinCols} rows={optins} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, margin: '24px 0 8px' }}>Upcoming roster (next 14 nights)</h2>
      <DataTable columns={upcomingCols} rows={upcoming} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, margin: '24px 0 8px' }}>Coverage gaps (next 14 nights)</h2>
      <DataTable columns={gapsCols} rows={gaps} rowKey={(r: any) => `${r.shift_date}-${r.state}`} />

      <h2 style={{ fontSize: 16, margin: '24px 0 8px' }}>Recent history (last 30 nights)</h2>
      <DataTable columns={historyCols} rows={history} rowKey={(r: any) => r.id} />
    </div>
  );
}
