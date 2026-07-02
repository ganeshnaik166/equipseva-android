import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerShiftScheduleTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [shiftsRes, swapsRes, coverageRes, lockedRes] = await Promise.all([
    sb.rpc('list_shifts_r1732'),
    sb.rpc('list_swaps_r1732'),
    sb.rpc('weekly_coverage_summary_r1732'),
    sb.rpc('locked_shifts_r1732'),
  ]);

  const shifts: any[] = Array.isArray(shiftsRes.data) ? shiftsRes.data : [];
  const swaps: any[] = Array.isArray(swapsRes.data) ? swapsRes.data : [];
  const coverage: any[] = Array.isArray(coverageRes.data) ? coverageRes.data : [];
  const locked: any[] = Array.isArray(lockedRes.data) ? lockedRes.data : [];

  const totalShifts = shifts.length;
  const swapPending = shifts.filter((s) => s.swap_requested).length;
  const lockedCount = locked.length;
  const onCallCount = shifts.filter((s) => s.shift_type === 'on_call').length;

  const shiftColumns: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => String(r.shift_date ?? '-') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '-') },
    { key: 'shift_type', header: 'Type', render: (r: any) => String(r.shift_type ?? '-') },
    {
      key: 'window',
      header: 'Window',
      render: (r: any) => `${String(r.shift_start ?? '').slice(0, 5)} - ${String(r.shift_end ?? '').slice(0, 5)}`,
    },
    {
      key: 'swap_requested',
      header: 'Swap?',
      render: (r: any) => (r.swap_requested ? 'pending' : '-'),
    },
    {
      key: 'locked_by_founder',
      header: 'Locked',
      render: (r: any) => (r.locked_by_founder ? 'yes' : 'no'),
    },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '-') },
  ];

  const swapColumns: Column<any>[] = [
    { key: 'shift_date', header: 'Shift Date', render: (r: any) => String(r.shift_date ?? '-') },
    { key: 'shift_type', header: 'Shift Type', render: (r: any) => String(r.shift_type ?? '-') },
    { key: 'requested_by_email', header: 'Requested By', render: (r: any) => String(r.requested_by_email ?? '-') },
    { key: 'target_email', header: 'Target', render: (r: any) => String(r.target_email ?? '-') },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '-') },
    {
      key: 'approved',
      header: 'Status',
      render: (r: any) =>
        r.approved === null || r.approved === undefined
          ? 'pending'
          : r.approved
          ? 'approved'
          : 'rejected',
    },
    {
      key: 'requested_at',
      header: 'Requested',
      render: (r: any) => (r.requested_at ? new Date(r.requested_at).toLocaleString() : '-'),
    },
    { key: 'decided_by_email', header: 'Decided By', render: (r: any) => String(r.decided_by_email ?? '-') },
  ];

  const coverageColumns: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => String(r.shift_date ?? '-') },
    { key: 'total_shifts', header: 'Total', render: (r: any) => String(r.total_shifts ?? 0) },
    { key: 'day_shifts', header: 'Day', render: (r: any) => String(r.day_shifts ?? 0) },
    { key: 'night_shifts', header: 'Night', render: (r: any) => String(r.night_shifts ?? 0) },
    { key: 'on_call_shifts', header: 'On-Call', render: (r: any) => String(r.on_call_shifts ?? 0) },
    { key: 'off_or_leave', header: 'Off / Leave', render: (r: any) => String(r.off_or_leave ?? 0) },
    {
      key: 'swap_pending',
      header: 'Swap Pending',
      render: (r: any) => String(r.swap_pending ?? 0),
    },
  ];

  const lockedColumns: Column<any>[] = [
    { key: 'shift_date', header: 'Date', render: (r: any) => String(r.shift_date ?? '-') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '-') },
    { key: 'shift_type', header: 'Type', render: (r: any) => String(r.shift_type ?? '-') },
    {
      key: 'window',
      header: 'Window',
      render: (r: any) => `${String(r.shift_start ?? '').slice(0, 5)} - ${String(r.shift_end ?? '').slice(0, 5)}`,
    },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '-') },
    {
      key: 'created_at',
      header: 'Created',
      render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString() : '-'),
    },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', marginBottom: '8px' }}>Engineer Shift Schedule Tracker</h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Per-engineer weekly shift schedule, on-call rotation, and founder-locked shifts. Window = last 7 days &gt;
        next 14 days.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', marginBottom: '12px' }}>Headline KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px' }}>
          <KpiCard label="Shifts in Window" value={totalShifts} />
          <KpiCard label="Swap Pending" value={swapPending} />
          <KpiCard label="Locked by Founder" value={lockedCount} />
          <KpiCard label="On-Call Slots" value={onCallCount} />
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', marginBottom: '12px' }}>Weekly Coverage Summary</h2>
        <p style={{ color: '#666', marginBottom: '8px', fontSize: '13px' }}>
          Rows where Swap Pending &gt;= 1 indicate days needing founder review.
        </p>
        <DataTable
          rows={coverage}
          columns={coverageColumns}
          rowKey={(r: any, i: number) => String(r.shift_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', marginBottom: '12px' }}>Shift Schedule</h2>
        <DataTable
          rows={shifts}
          columns={shiftColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', marginBottom: '12px' }}>Swap Requests</h2>
        <DataTable
          rows={swaps}
          columns={swapColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', marginBottom: '12px' }}>Founder-Locked Shifts</h2>
        <p style={{ color: '#666', marginBottom: '8px', fontSize: '13px' }}>
          Locked shifts cannot be swapped without founder override. Shows last 30 days & forward.
        </p>
        <DataTable
          rows={locked}
          columns={lockedColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div
      style={{
        border: '1px solid #e5e5e5',
        borderRadius: '8px',
        padding: '12px 16px',
        background: '#fafafa',
      }}
    >
      <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
        {label}
      </div>
      <div style={{ fontSize: '24px', fontWeight: 600, marginTop: '4px' }}>{value}</div>
    </div>
  );
}
