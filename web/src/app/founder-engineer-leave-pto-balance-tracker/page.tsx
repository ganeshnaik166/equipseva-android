import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [kpis, balances, pending, conflicts, byCity, burnout] = await Promise.all([
    sb.rpc('rpc_eng_leave_kpis_r2266'),
    sb.rpc('rpc_eng_leave_balances_r2266'),
    sb.rpc('rpc_eng_leave_pending_r2266'),
    sb.rpc('rpc_eng_leave_conflicts_r2266'),
    sb.rpc('rpc_eng_leave_by_city_r2266'),
    sb.rpc('rpc_eng_leave_burnout_r2266'),
  ]);

  const k = (kpis.data as Array<Record<string, unknown>> | null)?.[0] ?? null;
  const balanceRows = (balances.data as Array<Record<string, unknown>>) ?? [];
  const pendingRows = (pending.data as Array<Record<string, unknown>>) ?? [];
  const conflictRows = (conflicts.data as Array<Record<string, unknown>>) ?? [];
  const cityRows = (byCity.data as Array<Record<string, unknown>>) ?? [];
  const burnoutRows = (burnout.data as Array<Record<string, unknown>>) ?? [];

  const balCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'city', header: 'City', render: (r) => String(r.city ?? '') },
    { key: 'pto_used', header: 'PTO used / allocated', render: (r) => `${r.pto_days_used} / ${r.annual_pto_days_allocated}` },
    { key: 'pto_pending', header: 'PTO pending', render: (r) => String(r.pto_days_pending ?? 0) },
    { key: 'sick', header: 'Sick used / allocated', render: (r) => `${r.sick_days_used} / ${r.sick_days_allocated}` },
    { key: 'carryover', header: 'Carryover', render: (r) => String(r.carryover_from_prior_year ?? 0) },
    { key: 'burnout', header: 'Burnout score', render: (r) => `${Number(r.burnout_risk_score).toFixed(1)} / 100` },
    { key: 'last', header: 'Last leave', render: (r) => r.last_leave_taken_at ? String(r.last_leave_taken_at).slice(0,10) : '-' },
  ];

  const pendCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'city', header: 'City', render: (r) => String(r.city ?? '') },
    { key: 'leave_type', header: 'Type', render: (r) => String(r.leave_type ?? '') },
    { key: 'start_date', header: 'Start', render: (r) => String(r.start_date ?? '') },
    { key: 'end_date', header: 'End', render: (r) => String(r.end_date ?? '') },
    { key: 'days_requested', header: 'Days', render: (r) => String(r.days_requested ?? 0) },
    { key: 'conflicts_with_peak_week', header: 'Peak conflict', render: (r) => r.conflicts_with_peak_week ? 'YES' : 'no' },
    { key: 'open_jobs_in_window', header: 'Open jobs', render: (r) => String(r.open_jobs_in_window ?? 0) },
    { key: 'reason', header: 'Reason', render: (r) => String(r.reason ?? '') },
  ];

  const conflictCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'peak_week_label', header: 'Peak week', render: (r) => String(r.peak_week_label ?? '') },
    { key: 'start_date', header: 'Start', render: (r) => String(r.start_date ?? '') },
    { key: 'end_date', header: 'End', render: (r) => String(r.end_date ?? '') },
    { key: 'open_jobs_in_window', header: 'Open jobs in window', render: (r) => String(r.open_jobs_in_window ?? 0) },
    { key: 'coverage_engineer_assigned', header: 'Coverage', render: (r) => String(r.coverage_engineer_assigned ?? 'TBD') },
    { key: 'approval_status', header: 'Status', render: (r) => String(r.approval_status ?? '') },
  ];

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => String(r.city ?? '') },
    { key: 'engineers', header: 'Engineers', render: (r) => String(r.engineers ?? 0) },
    { key: 'total_pending_days', header: 'Pending days', render: (r) => String(r.total_pending_days ?? 0) },
    { key: 'total_used_days', header: 'Used days', render: (r) => String(r.total_used_days ?? 0) },
    { key: 'pending_requests', header: 'Pending requests', render: (r) => String(r.pending_requests ?? 0) },
    { key: 'avg_burnout', header: 'Avg burnout', render: (r) => Number(r.avg_burnout ?? 0).toFixed(1) },
  ];

  const burnCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => String(r.engineer_name ?? '') },
    { key: 'city', header: 'City', render: (r) => String(r.city ?? '') },
    { key: 'burnout', header: 'Burnout', render: (r) => `${Number(r.burnout_risk_score).toFixed(1)} / 100` },
    { key: 'last', header: 'Last leave', render: (r) => r.last_leave_taken_at ? String(r.last_leave_taken_at).slice(0,10) : 'never' },
    { key: 'pto_used', header: 'PTO used', render: (r) => `${r.pto_days_used} of ${r.annual_pto_days_allocated}` },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700 }}>Engineer Leave & PTO Balance Tracker</h1>
      <p style={{ color: '#555', marginTop: 6 }}>
        Per-engineer balances, planned leave, peak-demand conflicts &amp; approval queue. Burnout score &gt;= 70 flagged red.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginTop: 16 }}>
        <Kpi label="Engineers tracked" value={String(k?.total_engineers ?? 0)} />
        <Kpi label="PTO allocated (days)" value={String(k?.total_pto_allocated ?? 0)} />
        <Kpi label="PTO used (days)" value={String(k?.total_pto_used ?? 0)} />
        <Kpi label="Pending requests" value={String(k?.pending_requests ?? 0)} />
        <Kpi label="Peak-week conflicts" value={String(k?.peak_week_conflicts ?? 0)} />
        <Kpi label="High burnout (>= 70)" value={String(k?.high_burnout_count ?? 0)} />
        <Kpi label="Avg burnout" value={Number(k?.avg_burnout ?? 0).toFixed(1)} />
      </section>

      <h2 style={{ marginTop: 24, fontSize: 20, fontWeight: 600 }}>Pending approval queue</h2>
      <p style={{ color: '#666', fontSize: 13 }}>Sorted by peak-week conflict first, then submission age.</p>
      <DataTable columns={pendCols} rows={pendingRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24, fontSize: 20, fontWeight: 600 }}>Peak-week conflicts</h2>
      <p style={{ color: '#666', fontSize: 13 }}>Leave overlapping AMC renewal weeks & chain rollouts.</p>
      <DataTable columns={conflictCols} rows={conflictRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24, fontSize: 20, fontWeight: 600 }}>Balances by engineer</h2>
      <DataTable columns={balCols} rows={balanceRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24, fontSize: 20, fontWeight: 600 }}>City rollup</h2>
      <DataTable columns={cityCols} rows={cityRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ marginTop: 24, fontSize: 20, fontWeight: 600 }}>Burnout watchlist (score &gt;= 60)</h2>
      <p style={{ color: '#666', fontSize: 13 }}>Engineers needing forced PTO & coverage rotation.</p>
      <DataTable columns={burnCols} rows={burnoutRows} rowKey={(_, i) => String(i)} />
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
