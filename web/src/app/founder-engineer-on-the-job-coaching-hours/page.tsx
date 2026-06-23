import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [coaching, credits, topJuniors, topics, certStatus, monthlyTrend, ownerLoad] = await Promise.all([
    supabase.rpc('list_coaching_r2554'),
    supabase.rpc('list_credits_r2554'),
    supabase.rpc('top_coached_juniors_r2554'),
    supabase.rpc('topic_kind_breakdown_r2554'),
    supabase.rpc('certification_status_summary_r2554'),
    supabase.rpc('monthly_hours_trend_r2554'),
    supabase.rpc('owner_load_r2554'),
  ]);

  const coachingRows = (coaching.data ?? []) as any[];
  const creditsRows = (credits.data ?? []) as any[];
  const topJuniorsRows = (topJuniors.data ?? []) as any[];
  const topicsRows = (topics.data ?? []) as any[];
  const certStatusRows = (certStatus.data ?? []) as any[];
  const monthlyTrendRows = (monthlyTrend.data ?? []) as any[];
  const ownerLoadRows = (ownerLoad.data ?? []) as any[];

  const coachingCols: Column<any>[] = [
    { key: 'coached_at', header: 'Coached At', render: (r: any) => r.coached_at ? new Date(r.coached_at).toLocaleString() : '-' },
    { key: 'topic_kind', header: 'Topic', render: (r: any) => r.topic_kind ?? '-' },
    { key: 'hours', header: 'Hours', render: (r: any) => String(r.hours ?? 0) },
    { key: 'certification_credit_hours', header: 'Cert Credit Hrs', render: (r: any) => String(r.certification_credit_hours ?? 0) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const creditsCols: Column<any>[] = [
    { key: 'period_start', header: 'Period Start', render: (r: any) => r.period_start ?? '-' },
    { key: 'period_end', header: 'Period End', render: (r: any) => r.period_end ?? '-' },
    { key: 'total_hours', header: 'Total Hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'certified_hours', header: 'Certified Hrs', render: (r: any) => String(r.certified_hours ?? 0) },
    { key: 'certification_target_hours', header: 'Target Hrs', render: (r: any) => String(r.certification_target_hours ?? 0) },
    { key: 'certification_status', header: 'Cert Status', render: (r: any) => r.certification_status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topJuniorsCols: Column<any>[] = [
    { key: 'junior_engineer_user_id', header: 'Junior', render: (r: any) => r.junior_engineer_user_id ?? 'unassigned' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => String(r.session_count ?? 0) },
    { key: 'total_hours', header: 'Total Hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'certification_credit_total', header: 'Cert Credit', render: (r: any) => String(r.certification_credit_total ?? 0) },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => String(r.positive_outcomes ?? 0) },
  ];

  const topicsCols: Column<any>[] = [
    { key: 'topic_kind', header: 'Topic', render: (r: any) => r.topic_kind ?? '-' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => String(r.session_count ?? 0) },
    { key: 'total_hours', header: 'Total Hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'avg_credit_hours', header: 'Avg Credit', render: (r: any) => String(r.avg_credit_hours ?? 0) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => String(r.positive_count ?? 0) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => String(r.negative_count ?? 0) },
  ];

  const certStatusCols: Column<any>[] = [
    { key: 'certification_status', header: 'Cert Status', render: (r: any) => r.certification_status ?? '-' },
    { key: 'junior_count', header: 'Juniors', render: (r: any) => String(r.junior_count ?? 0) },
    { key: 'total_hours_sum', header: 'Total Hrs', render: (r: any) => String(r.total_hours_sum ?? 0) },
    { key: 'certified_hours_sum', header: 'Certified Hrs', render: (r: any) => String(r.certified_hours_sum ?? 0) },
    { key: 'target_hours_sum', header: 'Target Hrs', render: (r: any) => String(r.target_hours_sum ?? 0) },
    { key: 'pct_to_target', header: 'Pct To Target', render: (r: any) => String(r.pct_to_target ?? 0) + '%' },
  ];

  const monthlyTrendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label ?? '-' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => String(r.session_count ?? 0) },
    { key: 'total_hours', header: 'Total Hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'certification_credit_total', header: 'Cert Credit', render: (r: any) => String(r.certification_credit_total ?? 0) },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => String(r.session_count ?? 0) },
    { key: 'total_hours', header: 'Total Hrs', render: (r: any) => String(r.total_hours ?? 0) },
    { key: 'certification_credit_total', header: 'Cert Credit', render: (r: any) => String(r.certification_credit_total ?? 0) },
    { key: 'juniors_tracked', header: 'Juniors Tracked', render: (r: any) => String(r.juniors_tracked ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer On-the-Job Coaching Hours</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Senior => junior on-job coaching tracker: hours, topics, outcomes & certification credit progress.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Coaching Sessions</h2>
        <DataTable
          rows={coachingRows}
          columns={coachingCols}
          emptyMessage="No coaching sessions logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Certification Credits</h2>
        <DataTable
          rows={creditsRows}
          columns={creditsCols}
          emptyMessage="No credit periods tracked yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Coached Juniors</h2>
        <DataTable
          rows={topJuniorsRows}
          columns={topJuniorsCols}
          emptyMessage="No junior data yet"
          rowKey={(r: any, i: number) => String(r.junior_engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Topic Kind Breakdown</h2>
        <DataTable
          rows={topicsRows}
          columns={topicsCols}
          emptyMessage="No topic data yet"
          rowKey={(r: any, i: number) => String(r.topic_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Certification Status Summary</h2>
        <DataTable
          rows={certStatusRows}
          columns={certStatusCols}
          emptyMessage="No certification data yet"
          rowKey={(r: any, i: number) => String(r.certification_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Monthly Hours Trend</h2>
        <DataTable
          rows={monthlyTrendRows}
          columns={monthlyTrendCols}
          emptyMessage="No monthly data yet"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Owner Load</h2>
        <DataTable
          rows={ownerLoadRows}
          columns={ownerLoadCols}
          emptyMessage="No owner data yet"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
