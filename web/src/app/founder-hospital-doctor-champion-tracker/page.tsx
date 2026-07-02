import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [champions, topPerHospital, lapsed, engagements] = await Promise.all([
    sb.rpc('list_champions_r1751'),
    sb.rpc('top_champions_per_hospital_r1751'),
    sb.rpc('lapsed_champions_r1751'),
    sb.rpc('list_engagements_r1751', { p_champion_id: null }),
  ]);

  const championsRows: any[] = champions.data ?? [];
  const topRows: any[] = topPerHospital.data ?? [];
  const lapsedRows: any[] = lapsed.data ?? [];
  const engagementsRows: any[] = engagements.data ?? [];

  const activeCount = championsRows.filter((r) => r.status === 'active').length;
  const lapsedCount = championsRows.filter((r) => r.status === 'lapsed').length;
  const lostCount = championsRows.filter((r) => r.status === 'lost').length;
  const highScoreCount = championsRows.filter((r) => (r.champion_score ?? 0) >= 8).length;

  const championCols: Column<any>[] = [
    { key: 'doctor_name', header: 'Doctor', render: (r: any) => String(r.doctor_name ?? '') },
    { key: 'doctor_dept', header: 'Dept', render: (r: any) => String(r.doctor_dept ?? '—') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'champion_score', header: 'Score', render: (r: any) => String(r.champion_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    {
      key: 'last_engaged_at',
      header: 'Last engaged',
      render: (r: any) => (r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : '—'),
    },
    { key: 'doctor_email', header: 'Email', render: (r: any) => String(r.doctor_email ?? '—') },
    { key: 'doctor_phone', header: 'Phone', render: (r: any) => String(r.doctor_phone ?? '—') },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'top_doctor', header: 'Top doctor', render: (r: any) => String(r.top_doctor ?? '—') },
    { key: 'top_score', header: 'Top score', render: (r: any) => String(r.top_score ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
  ];

  const lapsedCols: Column<any>[] = [
    { key: 'doctor_name', header: 'Doctor', render: (r: any) => String(r.doctor_name ?? '') },
    { key: 'doctor_dept', header: 'Dept', render: (r: any) => String(r.doctor_dept ?? '—') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'champion_score', header: 'Score', render: (r: any) => String(r.champion_score ?? 0) },
    {
      key: 'last_engaged_at',
      header: 'Last engaged',
      render: (r: any) => (r.last_engaged_at ? new Date(r.last_engaged_at).toLocaleDateString() : 'never'),
    },
    {
      key: 'days_since_engagement',
      header: 'Days since',
      render: (r: any) => (r.days_since_engagement == null ? '—' : String(r.days_since_engagement)),
    },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'doctor_name', header: 'Doctor', render: (r: any) => String(r.doctor_name ?? '') },
    { key: 'engagement_type', header: 'Type', render: (r: any) => String(r.engagement_type ?? '') },
    {
      key: 'engagement_at',
      header: 'When',
      render: (r: any) => (r.engagement_at ? new Date(r.engagement_at).toLocaleString() : '—'),
    },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '—') },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Doctor Champion Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track doctors who champion us inside hospitals. High-score champions (score &gt;= 8) drive
        renewals &amp; referrals. Lapsed champions (no engagement &gt; 60 days) need re-activation.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active champions</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>High score (&gt;= 8)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{highScoreCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lapsed</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{lapsedCount}</div>
          </div>
          <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{lostCount}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All champions</h2>
        <DataTable
          rows={championsRows}
          columns={championCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top champion per hospital
        </h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Lapsed & at-risk champions
        </h2>
        <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
          Doctors with status lapsed, never engaged, or last engagement &gt; 60 days ago.
        </p>
        <DataTable
          rows={lapsedRows}
          columns={lapsedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent engagements</h2>
        <DataTable
          rows={engagementsRows}
          columns={engagementCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
