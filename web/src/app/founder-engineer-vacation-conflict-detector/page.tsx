import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CounterRow = {
  pending_requests: number;
  approved_upcoming: number;
  peak_week_conflicts: number;
  critical_gaps: number;
  total_engineers_on_leave_this_week: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    countersRes,
    pendingRes,
    conflictsRes,
    gapsRes,
    totalsRes,
    peakRes,
    decisionsRes,
  ] = await Promise.all([
    supabase.rpc('r2350_dashboard_counters'),
    supabase.rpc('r2350_pending_vacation_requests'),
    supabase.rpc('r2350_peak_week_conflicts'),
    supabase.rpc('r2350_zone_coverage_gaps'),
    supabase.rpc('r2350_engineer_leave_totals'),
    supabase.rpc('r2350_peak_weeks_summary'),
    supabase.rpc('r2350_recent_decisions'),
  ]);

  const counters: CounterRow = (countersRes.data?.[0] ?? {
    pending_requests: 0,
    approved_upcoming: 0,
    peak_week_conflicts: 0,
    critical_gaps: 0,
    total_engineers_on_leave_this_week: 0,
  }) as CounterRow;

  const pendingCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'starts_on', header: 'Starts', render: (r: any) => r.starts_on },
    { key: 'ends_on', header: 'Ends', render: (r: any) => r.ends_on },
    { key: 'total_days', header: 'Days', render: (r: any) => r.total_days },
    { key: 'reason', header: 'Reason', render: (r: any) => r.reason },
    { key: 'requested_at', header: 'Requested', render: (r: any) => new Date(r.requested_at).toLocaleString() },
  ];

  const conflictCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'starts_on', header: 'Leave starts', render: (r: any) => r.starts_on },
    { key: 'ends_on', header: 'Leave ends', render: (r: any) => r.ends_on },
    { key: 'peak_week_starts_on', header: 'Peak week', render: (r: any) => r.peak_week_starts_on },
    { key: 'expected_jobs', header: 'Expected jobs', render: (r: any) => r.expected_jobs },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gapCols: Column<any>[] = [
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'week_starts_on', header: 'Week of', render: (r: any) => r.week_starts_on },
    { key: 'baseline_engineers_needed', header: 'Needed', render: (r: any) => r.baseline_engineers_needed },
    { key: 'engineers_on_leave', header: 'On leave', render: (r: any) => r.engineers_on_leave },
    { key: 'gap_severity', header: 'Severity', render: (r: any) => r.gap_severity },
  ];

  const totalsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'approved_days', header: 'Approved days', render: (r: any) => r.approved_days },
    { key: 'pending_days', header: 'Pending days', render: (r: any) => r.pending_days },
    { key: 'upcoming_starts_on', header: 'Next leave', render: (r: any) => r.upcoming_starts_on ?? '-' },
  ];

  const peakCols: Column<any>[] = [
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'week_starts_on', header: 'Week of', render: (r: any) => r.week_starts_on },
    { key: 'expected_jobs', header: 'Expected jobs', render: (r: any) => r.expected_jobs },
    { key: 'expected_amc_visits', header: 'AMC visits', render: (r: any) => r.expected_amc_visits },
    { key: 'baseline_engineers_needed', header: 'Baseline engineers', render: (r: any) => r.baseline_engineers_needed },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'zone_code', header: 'Zone', render: (r: any) => r.zone_code },
    { key: 'starts_on', header: 'Starts', render: (r: any) => r.starts_on },
    { key: 'ends_on', header: 'Ends', render: (r: any) => r.ends_on },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '-' },
    { key: 'decided_by_email', header: 'By', render: (r: any) => r.decided_by_email ?? '-' },
    { key: 'override_note', header: 'Override note', render: (r: any) => r.override_note ?? '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Vacation Conflict Detector
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Detect engineer leave overlapping peak-demand weeks & shared-zone coverage gaps.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 32 }}>
        <Counter label="Pending requests" value={counters.pending_requests} />
        <Counter label="Approved upcoming" value={counters.approved_upcoming} />
        <Counter label="Peak-week conflicts" value={counters.peak_week_conflicts} />
        <Counter label="Critical gaps" value={counters.critical_gaps} />
        <Counter label="On leave this week" value={counters.total_engineers_on_leave_this_week} />
      </div>

      <Section title="Pending vacation requests">
        <DataTable
          rows={pendingRes.data ?? []}
          emptyMessage="No pending requests."
          rowKey={(r: any) => r.request_id}
          columns={pendingCols}
        />
      </Section>

      <Section title="Peak-week conflicts">
        <DataTable
          rows={conflictsRes.data ?? []}
          emptyMessage="No leave overlaps a peak week."
          rowKey={(r: any) => r.request_id}
          columns={conflictCols}
        />
      </Section>

      <Section title="Zone coverage gaps">
        <DataTable
          rows={gapsRes.data ?? []}
          emptyMessage="All zones covered."
          rowKey={(r: any) => `${r.zone_code}-${r.week_starts_on}`}
          columns={gapCols}
        />
      </Section>

      <Section title="Engineer leave totals (last 30 days & upcoming)">
        <DataTable
          rows={totalsRes.data ?? []}
          emptyMessage="No leave records."
          rowKey={(r: any) => `${r.engineer_email}-${r.zone_code}`}
          columns={totalsCols}
        />
      </Section>

      <Section title="Peak weeks ahead">
        <DataTable
          rows={peakRes.data ?? []}
          emptyMessage="No peak weeks forecast."
          rowKey={(r: any) => `${r.zone_code}-${r.week_starts_on}`}
          columns={peakCols}
        />
      </Section>

      <Section title="Recent decisions">
        <DataTable
          rows={decisionsRes.data ?? []}
          emptyMessage="No decisions logged."
          rowKey={(r: any) => r.request_id}
          columns={decisionCols}
        />
      </Section>
    </div>
  );
}

function Counter({ label, value }: { label: string; value: number }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </div>
  );
}
