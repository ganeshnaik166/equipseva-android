import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, stakeholdersRes, topInfRes, blockersRes, engagementsRes] = await Promise.all([
    sb.rpc('stakeholder_summary_r1699'),
    sb.rpc('list_stakeholders_r1699'),
    sb.rpc('top_influencers_per_hospital_r1699'),
    sb.rpc('blockers_to_address_r1699'),
    sb.rpc('list_engagements_r1699', { p_stakeholder_id: null }),
  ]);

  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const stakeholders: any[] = stakeholdersRes.data ?? [];
  const topInfluencers: any[] = topInfRes.data ?? [];
  const blockers: any[] = blockersRes.data ?? [];
  const engagements: any[] = engagementsRes.data ?? [];

  const stakeholderCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'person_name', header: 'Person', render: (r: any) => r.person_name ?? '—' },
    { key: 'person_role', header: 'Role', render: (r: any) => r.person_role ?? '—' },
    { key: 'person_email', header: 'Email', render: (r: any) => r.person_email ?? '—' },
    { key: 'relationship', header: 'Relationship', render: (r: any) => r.relationship ?? '—' },
    { key: 'influence_score', header: 'Influence (1-10)', render: (r: any) => String(r.influence_score ?? '—') },
    { key: 'engagement_count', header: 'Engagements', render: (r: any) => String(r.engagement_count ?? 0) },
    { key: 'last_engaged_at', header: 'Last Engaged', render: (r: any) => r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—' },
  ];

  const topInfCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'person_name', header: 'Top Influencer', render: (r: any) => r.person_name ?? '—' },
    { key: 'person_role', header: 'Role', render: (r: any) => r.person_role ?? '—' },
    { key: 'relationship', header: 'Relationship', render: (r: any) => r.relationship ?? '—' },
    { key: 'influence_score', header: 'Score', render: (r: any) => String(r.influence_score ?? '—') },
    { key: 'last_engaged_at', header: 'Last Engaged', render: (r: any) => r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—' },
  ];

  const blockerCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'person_name', header: 'Blocker', render: (r: any) => r.person_name ?? '—' },
    { key: 'person_role', header: 'Role', render: (r: any) => r.person_role ?? '—' },
    { key: 'influence_score', header: 'Influence', render: (r: any) => String(r.influence_score ?? '—') },
    { key: 'days_since_engagement', header: 'Days Since Engaged', render: (r: any) => r.days_since_engagement != null ? String(r.days_since_engagement) : 'never' },
    { key: 'last_engaged_at', header: 'Last Engaged', render: (r: any) => r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—' },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'engagement_at', header: 'When', render: (r: any) => r.engagement_at ? new Date(r.engagement_at).toLocaleString() : '—' },
    { key: 'person_name', header: 'Stakeholder', render: (r: any) => r.person_name ?? '—' },
    { key: 'engagement_type', header: 'Type', render: (r: any) => r.engagement_type ?? '—' },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'summary', header: 'Summary', render: (r: any) => r.summary ?? '—' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, marginBottom: 8 }}>Hospital Stakeholder Map</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-hospital decision-maker, champion, and blocker map. Track influence (1-10) and engagement cadence.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          <Card label="Total Stakeholders" value={String(summary?.total_stakeholders ?? 0)} />
          <Card label="Champions" value={String(summary?.champions ?? 0)} />
          <Card label="Decision Makers" value={String(summary?.decision_makers ?? 0)} />
          <Card label="Influencers" value={String(summary?.influencers ?? 0)} />
          <Card label="Blockers" value={String(summary?.blockers ?? 0)} />
          <Card label="Neutral" value={String(summary?.neutral_count ?? 0)} />
          <Card label="Avg Influence" value={String(summary?.avg_influence ?? 0)} />
          <Card label="Engagements (30d)" value={String(summary?.engagements_last_30d ?? 0)} />
          <Card label="Positive Sentiment %" value={`${summary?.positive_sentiment_pct ?? 0}%`} />
          <Card label="Hospitals Covered" value={String(summary?.hospitals_covered ?? 0)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, marginBottom: 12 }}>Blockers to Address</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          High-influence blockers — prioritize highest score & longest gap (&gt;14d).
        </p>
        <DataTable rows={blockers} columns={blockerCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, marginBottom: 12 }}>Top Influencer per Hospital</h2>
        <DataTable rows={topInfluencers} columns={topInfCols} rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, marginBottom: 12 }}>All Stakeholders</h2>
        <DataTable rows={stakeholders} columns={stakeholderCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, marginBottom: 12 }}>Recent Engagements</h2>
        <DataTable rows={engagements} columns={engagementCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#888', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  );
}
