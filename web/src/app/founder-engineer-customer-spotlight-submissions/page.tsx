import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [subsRes, topRes, featuredRes] = await Promise.all([
    sb.rpc('list_spotlight_submissions_r1776'),
    sb.rpc('top_contributing_engineers_r1776'),
    sb.rpc('recent_featured_stories_r1776'),
  ]);

  const subs: any[] = Array.isArray(subsRes.data) ? subsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const featured: any[] = Array.isArray(featuredRes.data) ? featuredRes.data : [];

  const totalSubs = subs.length;
  const featuredCount = subs.filter((s) => s.status === 'featured').length;
  const pendingCount = subs.filter((s) => s.status === 'submitted' || s.status === 'under_review').length;
  const totalReward = subs.reduce((acc, s) => acc + (Number(s.reward_rupees) || 0), 0);

  const subCols: Column<any>[] = [
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => (r.submitted_at ? new Date(r.submitted_at).toLocaleString() : '-') },
    { key: 'story_title', header: 'Title', render: (r: any) => r.story_title ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'reward_rupees', header: 'Reward (₹)', render: (r: any) => Number(r.reward_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'featured_at', header: 'Featured', render: (r: any) => (r.featured_at ? new Date(r.featured_at).toLocaleDateString() : '-') },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'total_submissions', header: 'Total Submissions', render: (r: any) => Number(r.total_submissions ?? 0).toLocaleString('en-IN') },
    { key: 'featured_count', header: 'Featured', render: (r: any) => Number(r.featured_count ?? 0).toLocaleString('en-IN') },
    { key: 'total_reward_rupees', header: 'Total Reward (₹)', render: (r: any) => Number(r.total_reward_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const featuredCols: Column<any>[] = [
    { key: 'featured_at', header: 'Featured At', render: (r: any) => (r.featured_at ? new Date(r.featured_at).toLocaleString() : '-') },
    { key: 'story_title', header: 'Title', render: (r: any) => r.story_title ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'reward_rupees', header: 'Reward (₹)', render: (r: any) => Number(r.reward_rupees ?? 0).toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Customer Spotlight Submissions
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Field engineers submit customer success stories for marketing review & featuring.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Submissions</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalSubs.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Featured</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{featuredCount.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Pending Review</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{pendingCount.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Reward Paid (₹)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalReward.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Submissions</h2>
        <DataTable
          rows={subs}
          columns={subCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Contributing Engineers</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Featured Stories</h2>
        <DataTable
          rows={featured}
          columns={featuredCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
