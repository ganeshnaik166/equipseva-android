import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type InterviewRow = {
  id: string;
  interview_with_name: string | null;
  hospital_id: string | null;
  hospital_name: string | null;
  interview_date: string | null;
  key_insights_md: string | null;
  pain_points_md: string | null;
  status: string | null;
  created_at: string | null;
};

type TopInsightRow = {
  insight_category: string | null;
  insight_count: number | null;
  latest_taken_at: string | null;
};

type RecentInsightRow = {
  id: string;
  interview_id: string | null;
  interview_with_name: string | null;
  insight_category: string | null;
  insight_md: string | null;
  taken_at: string | null;
  by_email: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [interviewsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_interviews_r2006'),
    sb.rpc('top_insights_r2006'),
    sb.rpc('recent_insights_r2006'),
  ]);

  const interviews: InterviewRow[] = (interviewsRes.data as InterviewRow[] | null) ?? [];
  const topInsights: TopInsightRow[] = (topRes.data as TopInsightRow[] | null) ?? [];
  const recentInsights: RecentInsightRow[] = (recentRes.data as RecentInsightRow[] | null) ?? [];

  const interviewCols: Column<InterviewRow>[] = [
    { key: 'interview_with_name', header: 'Interviewee', render: (r: any) => String(r.interview_with_name ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'interview_date', header: 'Date', render: (r: any) => String(r.interview_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'key_insights_md', header: 'Key Insights', render: (r: any) => String(r.key_insights_md ?? '').slice(0, 120) },
    { key: 'pain_points_md', header: 'Pain Points', render: (r: any) => String(r.pain_points_md ?? '').slice(0, 120) },
  ];

  const topCols: Column<TopInsightRow>[] = [
    { key: 'insight_category', header: 'Category', render: (r: any) => String(r.insight_category ?? '') },
    { key: 'insight_count', header: 'Count', render: (r: any) => String(r.insight_count ?? 0) },
    { key: 'latest_taken_at', header: 'Latest', render: (r: any) => String(r.latest_taken_at ?? '').slice(0, 19) },
  ];

  const recentCols: Column<RecentInsightRow>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => String(r.taken_at ?? '').slice(0, 19) },
    { key: 'interview_with_name', header: 'Interview', render: (r: any) => String(r.interview_with_name ?? '') },
    { key: 'insight_category', header: 'Category', render: (r: any) => String(r.insight_category ?? '') },
    { key: 'insight_md', header: 'Insight', render: (r: any) => String(r.insight_md ?? '').slice(0, 160) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Customer Discovery Interviews</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track founder-led customer discovery interviews and log structured insights across pricing, feature, competitive, relationship, process, and customer-problem categories.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Interviews</h2>
        <DataTable
          rows={interviews}
          columns={interviewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Insight Categories</h2>
        <DataTable
          rows={topInsights}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.insight_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Insights</h2>
        <DataTable
          rows={recentInsights}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
