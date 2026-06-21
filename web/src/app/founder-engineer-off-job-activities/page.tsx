import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ActivityRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  activity_date: string | null;
  activity_type: string | null;
  duration_minutes: number | null;
  status: string | null;
  approved_by_email: string | null;
  created_at: string | null;
};

type SummaryRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  period_start: string | null;
  period_end: string | null;
  total_off_job_minutes: number | null;
  total_job_minutes: number | null;
  off_job_ratio_pct: number | null;
  recorded_at: string | null;
};

type TopRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  activity_count: number | null;
  total_minutes: number | null;
  approved_count: number | null;
};

type DistRow = {
  activity_type: string | null;
  activity_count: number | null;
  total_minutes: number | null;
  approved_count: number | null;
  disputed_count: number | null;
};

function fmtDate(d: string | null | undefined) {
  if (!d) return '-';
  try {
    return new Date(d).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return String(d);
  }
}

function fmtMinutes(n: number | null | undefined) {
  if (n == null) return '-';
  return String(n) + ' min';
}

function fmtPct(n: number | null | undefined) {
  if (n == null) return '-';
  return Number(n).toFixed(2) + '%';
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [actRes, sumRes, topRes, distRes] = await Promise.all([
    sb.rpc('list_off_job_activities_r1820'),
    sb.rpc('list_off_job_summaries_r1820'),
    sb.rpc('top_off_job_engineers_r1820'),
    sb.rpc('off_job_activity_distribution_r1820'),
  ]);

  const activities: ActivityRow[] = (actRes.data as ActivityRow[] | null) ?? [];
  const summaries: SummaryRow[] = (sumRes.data as SummaryRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const dist: DistRow[] = (distRes.data as DistRow[] | null) ?? [];

  const activityColumns: Column<ActivityRow>[] = [
    { key: 'activity_date', header: 'Date', render: (r: any) => r.activity_date ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'activity_type', header: 'Type', render: (r: any) => r.activity_type ?? '-' },
    { key: 'duration_minutes', header: 'Duration', render: (r: any) => fmtMinutes(r.duration_minutes) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'approved_by_email', header: 'Approved by', render: (r: any) => r.approved_by_email ?? '-' },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const summaryColumns: Column<SummaryRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'period_start', header: 'Period start', render: (r: any) => r.period_start ?? '-' },
    { key: 'period_end', header: 'Period end', render: (r: any) => r.period_end ?? '-' },
    { key: 'total_off_job_minutes', header: 'Off-job mins', render: (r: any) => fmtMinutes(r.total_off_job_minutes) },
    { key: 'total_job_minutes', header: 'Job mins', render: (r: any) => fmtMinutes(r.total_job_minutes) },
    { key: 'off_job_ratio_pct', header: 'Off-job ratio', render: (r: any) => fmtPct(r.off_job_ratio_pct) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const topColumns: Column<TopRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'activity_count', header: 'Activities', render: (r: any) => String(r.activity_count ?? 0) },
    { key: 'total_minutes', header: 'Total minutes', render: (r: any) => fmtMinutes(r.total_minutes) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
  ];

  const distColumns: Column<DistRow>[] = [
    { key: 'activity_type', header: 'Type', render: (r: any) => r.activity_type ?? '-' },
    { key: 'activity_count', header: 'Count', render: (r: any) => String(r.activity_count ?? 0) },
    { key: 'total_minutes', header: 'Total minutes', render: (r: any) => fmtMinutes(r.total_minutes) },
    { key: 'approved_count', header: 'Approved', render: (r: any) => String(r.approved_count ?? 0) },
    { key: 'disputed_count', header: 'Disputed', render: (r: any) => String(r.disputed_count ?? 0) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>
        Engineer Off-Job Activities
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Time engineers spend on non-job activities — admin, training, inventory, customer relationship,
        team meetings, and personal development. Off-job ratio &gt;= 25% flags utilisation risk; ratio &lt; 10%
        flags under-investment in training and customer success.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Activity-type distribution</h2>
        <DataTable
          rows={dist}
          columns={distColumns}
          rowKey={(r: any, i: number) => String(r.activity_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent activities</h2>
        <DataTable
          rows={activities}
          columns={activityColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top off-job engineers</h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Period summaries</h2>
        <DataTable
          rows={summaries}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
