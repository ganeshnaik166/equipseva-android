import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

async function callRpc(sb: any, name: string) {
  try {
    const { data, error } = await sb.rpc(name);
    if (error) return [];
    return Array.isArray(data) ? data : data ? [data] : [];
  } catch {
    return [];
  }
}

export default async function FounderEngineerHolidayCalendarPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const overviewRows = await callRpc(sb, 'founder_engineer_leave_calendar_overview');
  const upcoming = await callRpc(sb, 'founder_engineer_leave_calendar_list_upcoming');
  const perState = await callRpc(sb, 'founder_engineer_leave_calendar_per_state');
  const redlineCities = await callRpc(sb, 'founder_engineer_leave_calendar_redline_cities');
  const byType = await callRpc(sb, 'founder_engineer_leave_calendar_by_type');
  const pending = await callRpc(sb, 'founder_engineer_leave_calendar_pending_approvals');
  const topAbsentees = await callRpc(sb, 'founder_engineer_leave_calendar_top_absentees');

  const ov: any = overviewRows[0] ?? {};
  const redCount = Array.isArray(redlineCities) ? redlineCities.filter((c: any) => c.status === 'redline').length : 0;
  const warnCount = Array.isArray(redlineCities) ? redlineCities.filter((c: any) => c.status === 'warn').length : 0;
  const okCount = Array.isArray(redlineCities) ? redlineCities.filter((c: any) => c.status === 'ok').length : 0;
  const pendingCount = Array.isArray(pending) ? pending.length : 0;
  const upcomingCount = Array.isArray(upcoming) ? upcoming.length : 0;
  const stateCount = Array.isArray(perState) ? perState.length : 0;
  const lowestStatePct = Array.isArray(perState) && perState.length > 0
    ? Number(perState[0]?.availability_pct ?? 0)
    : 0;
  const topAbsenteeDays = Array.isArray(topAbsentees) && topAbsentees.length > 0
    ? Number(topAbsentees[0]?.total_leave_days ?? 0)
    : 0;

  const kpis: Kpi[] = [
    { label: 'Total engineers', value: String(ov.total_engineers ?? '—') },
    { label: 'On leave today', value: String(ov.on_leave_today ?? '—') },
    { label: 'Planned next 7d', value: String(ov.planned_next_7d ?? '—') },
    { label: 'Planned next 30d', value: String(ov.planned_next_30d ?? '—') },
    { label: 'Actual last 30d', value: String(ov.actual_last_30d ?? '—') },
    { label: 'Pending approvals', value: String(ov.approved_pending ?? '—') },
    { label: 'Cities redline', value: String(ov.cities_redline ?? '—') },
    { label: 'States covered', value: String(ov.states_with_leave ?? '—') },
    { label: 'Redline cities (now)', value: String(redCount) },
    { label: 'Warn cities', value: String(warnCount) },
    { label: 'Healthy cities', value: String(okCount) },
    { label: 'Pending rows', value: String(pendingCount) },
    { label: 'Upcoming rows', value: String(upcomingCount) },
    { label: 'States listed', value: String(stateCount) },
    { label: 'Lowest state availability %', value: lowestStatePct ? lowestStatePct.toFixed(2) : '—' },
    { label: 'Top absentee days (180d)', value: topAbsenteeDays ? topAbsenteeDays.toFixed(0) : '—' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'leave_type', header: 'Type', render: (r: any) => r.leave_type ?? '—' },
    { key: 'start_date', header: 'Start', render: (r: any) => r.start_date ?? '—' },
    { key: 'end_date', header: 'End', render: (r: any) => r.end_date ?? '—' },
    { key: 'days_count', header: 'Days', render: (r: any) => String(r.days_count ?? '—') },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'approved', header: 'Approved', render: (r: any) => (r.approved ? 'yes' : 'no') },
  ];

  const stateCols: Column<any>[] = [
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'total_engineers', header: 'Engineers', render: (r: any) => String(r.total_engineers ?? '—') },
    { key: 'on_leave_today', header: 'On leave', render: (r: any) => String(r.on_leave_today ?? '—') },
    { key: 'available', header: 'Available', render: (r: any) => String(r.available ?? '—') },
    { key: 'availability_pct', header: 'Availability %', render: (r: any) => r.availability_pct != null ? Number(r.availability_pct).toFixed(2) : '—' },
  ];

  const redlineCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'total_engineers', header: 'Engineers', render: (r: any) => String(r.total_engineers ?? '—') },
    { key: 'on_leave_today', header: 'On leave', render: (r: any) => String(r.on_leave_today ?? '—') },
    { key: 'available', header: 'Available', render: (r: any) => String(r.available ?? '—') },
    { key: 'availability_pct', header: 'Avail %', render: (r: any) => r.availability_pct != null ? Number(r.availability_pct).toFixed(2) : '—' },
    { key: 'redline_pct', header: 'Redline %', render: (r: any) => r.redline_pct != null ? Number(r.redline_pct).toFixed(2) : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'leave_type', header: 'Type', render: (r: any) => r.leave_type ?? '—' },
    { key: 'start_date', header: 'Start', render: (r: any) => r.start_date ?? '—' },
    { key: 'end_date', header: 'End', render: (r: any) => r.end_date ?? '—' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason ?? '—' },
  ];

  const absenteeCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'total_leave_days', header: 'Days (180d)', render: (r: any) => String(r.total_leave_days ?? '—') },
    { key: 'leave_count', header: 'Leaves', render: (r: any) => String(r.leave_count ?? '—') },
    { key: 'last_leave_date', header: 'Last leave', render: (r: any) => r.last_leave_date ?? '—' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Engineer holiday and leave calendar</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Pan-India planned and actual engineer leaves. Per-state availability with redline alerts when a city drops below threshold.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(180px,1fr))', gap: 12 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
            <div style={{ color: '#888', fontSize: 12 }}>{k.label}</div>
            <div style={{ fontWeight: 700, fontSize: 18 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Upcoming leaves</h2>
        <DataTable columns={upcomingCols} rows={upcoming as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Per-state availability</h2>
        <DataTable columns={stateCols} rows={perState as any[]} rowKey={(r: any) => r.state_code ?? Math.random().toString()} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>City redline status</h2>
        <DataTable columns={redlineCols} rows={redlineCities as any[]} rowKey={(r: any) => r.city ?? Math.random().toString()} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Pending approvals</h2>
        <DataTable columns={pendingCols} rows={pending as any[]} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Top absentees (180d)</h2>
        <DataTable columns={absenteeCols} rows={topAbsentees as any[]} rowKey={(r: any) => r.engineer_id ?? Math.random().toString()} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Leaves by type (90d)</h2>
        <ul>
          {Array.isArray(byType) && byType.map((b: any) => (
            <li key={b.leave_type ?? Math.random().toString()}>
              {b.leave_type ?? '—'}: {String(b.cnt ?? '—')} leaves, {String(b.total_days ?? '—')} days total, avg {String(b.avg_days ?? '—')}
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
