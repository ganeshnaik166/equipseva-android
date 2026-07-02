import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerOnboardingWalkthroughPage() {
  const sb = await getSupabaseServerClient();

  const [walkthroughsRes, summaryRes, inProgressRes] = await Promise.all([
    sb.rpc('list_walkthroughs_r1790'),
    sb.rpc('founder_attendance_summary_r1790'),
    sb.rpc('in_progress_walkthroughs_r1790'),
  ]);

  const walkthroughs: any[] = Array.isArray(walkthroughsRes.data) ? walkthroughsRes.data : [];
  const summaryRows: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];
  const summary = summaryRows[0] ?? {
    total_walkthroughs: 0,
    founder_attended_count: 0,
    attendance_rate_pct: 0,
    avg_satisfaction: 0,
    completed_count: 0,
  };
  const inProgress: any[] = Array.isArray(inProgressRes.data) ? inProgressRes.data : [];

  const walkthroughCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '-') },
    { key: 'walkthrough_kickoff_date', header: 'Kickoff', render: (r: any) => String(r.walkthrough_kickoff_date ?? '-') },
    { key: 'scheduled_30d_review_at', header: '30d Review', render: (r: any) => r.scheduled_30d_review_at ? new Date(r.scheduled_30d_review_at).toLocaleDateString() : '-' },
    { key: 'scheduled_60d_review_at', header: '60d Review', render: (r: any) => r.scheduled_60d_review_at ? new Date(r.scheduled_60d_review_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'founder_attended', header: 'Founder', render: (r: any) => r.founder_attended ? 'Yes' : 'No' },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => r.satisfaction_score != null ? `${r.satisfaction_score}/10` : '-' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '-' },
  ];

  const inProgressCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? r.hospital_user_id ?? '-') },
    { key: 'walkthrough_kickoff_date', header: 'Kickoff', render: (r: any) => String(r.walkthrough_kickoff_date ?? '-') },
    { key: 'days_active', header: 'Days Active', render: (r: any) => String(r.days_active ?? 0) },
    { key: 'scheduled_30d_review_at', header: 'Next 30d', render: (r: any) => r.scheduled_30d_review_at ? new Date(r.scheduled_30d_review_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
  ];

  const summaryRowsForTable = [
    { metric: 'Total walkthroughs', value: String(summary.total_walkthroughs ?? 0) },
    { metric: 'Founder attended', value: String(summary.founder_attended_count ?? 0) },
    { metric: 'Attendance rate', value: `${summary.attendance_rate_pct ?? 0}%` },
    { metric: 'Avg satisfaction', value: `${summary.avg_satisfaction ?? 0} / 10` },
    { metric: 'Completed', value: String(summary.completed_count ?? 0) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => String(r.metric ?? '-') },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value ?? '-') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
          Founder Customer Onboarding Walkthrough
        </h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Founder-led 30 & 60 day reviews for new hospitals. Track kickoff, checkpoints, and CSAT.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Attendance Summary</h2>
        <DataTable
          rows={summaryRowsForTable}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.metric ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          In Progress & Scheduled
        </h2>
        <DataTable
          rows={inProgress}
          columns={inProgressCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Walkthroughs</h2>
        <DataTable
          rows={walkthroughs}
          columns={walkthroughCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
