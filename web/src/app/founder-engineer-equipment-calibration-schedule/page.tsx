import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerEquipmentCalibrationSchedulePage() {
  const sb = await getSupabaseServerClient();

  const [schedRes, overdueRes, upcomingRes, auditsRes] = await Promise.all([
    sb.rpc('list_calibration_schedules_r1832', { p_status: null }),
    sb.rpc('overdue_calibrations_r1832'),
    sb.rpc('upcoming_calibrations_r1832', { p_days: 30 }),
    sb.rpc('list_calibration_audits_r1832', { p_schedule_id: null }),
  ]);

  const schedules: any[] = Array.isArray(schedRes.data) ? schedRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const audits: any[] = Array.isArray(auditsRes.data) ? auditsRes.data : [];

  const totalSchedules = schedules.length;
  const overdueCount = overdue.length;
  const upcomingCount = upcoming.length;
  const exemptCount = schedules.filter((s) => s.status === 'exempt').length;

  const schedCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'hospital_user_id', header: 'Hospital', render: (r: any) => String(r.hospital_user_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_calibrated_at', header: 'Last Calibrated', render: (r: any) => r.last_calibrated_at ? new Date(r.last_calibrated_at).toLocaleDateString() : '—' },
    { key: 'next_due_at', header: 'Next Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '—' },
    { key: 'calibration_interval_months', header: 'Interval (mo)', render: (r: any) => String(r.calibration_interval_months ?? '') },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'next_due_at', header: 'Was Due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => String(r.equipment_name ?? '') },
    { key: 'next_due_at', header: 'Due Date', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleDateString() : '' },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const auditCols: Column<any>[] = [
    { key: 'audit_at', header: 'When', render: (r: any) => r.audit_at ? new Date(r.audit_at).toLocaleString() : '' },
    { key: 'audit_type', header: 'Type', render: (r: any) => String(r.audit_type ?? '') },
    { key: 'audit_outcome', header: 'Outcome', render: (r: any) => String(r.audit_outcome ?? '') },
    { key: 'notes', header: 'Notes', render: (r: any) => String(r.notes ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Equipment Calibration Schedule</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-equipment calibration cycle & due-date tracking. Founder console — round r1832.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Schedules</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalSchedules}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fca5a5', borderRadius: 8, background: '#fef2f2' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Overdue</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{overdueCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #fde68a', borderRadius: 8, background: '#fffbeb' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Upcoming (30d)</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#92400e' }}>{upcomingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Exempt</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{exemptCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Overdue Calibrations</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Upcoming Calibrations (next 30 days)</h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Schedules</h2>
        <DataTable rows={schedules} columns={schedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Audit Log</h2>
        <DataTable rows={audits} columns={auditCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
