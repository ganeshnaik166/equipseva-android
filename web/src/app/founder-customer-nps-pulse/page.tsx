import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [surveys, trend, byHospital, actions] = await Promise.all([
    sb.rpc('list_nps_surveys_r2216'),
    sb.rpc('aggregate_nps_trend_r2216'),
    sb.rpc('top_nps_by_hospital_r2216'),
    sb.rpc('recent_actions_nps_r2216'),
  ]);

  const surveyCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '' },
    { key: 'score', header: 'Score 0–10', render: (r: any) => String(r.score ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '' },
    { key: 'verbatim', header: 'Verbatim', render: (r: any) => r.verbatim ?? '' },
    { key: 'surveyed_at', header: 'Surveyed', render: (r: any) => r.surveyed_at ? new Date(r.surveyed_at).toLocaleString() : '' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '' },
    { key: 'response_count', header: 'Responses', render: (r: any) => String(r.response_count ?? 0) },
    { key: 'promoter_count', header: 'Promoters', render: (r: any) => String(r.promoter_count ?? 0) },
    { key: 'detractor_count', header: 'Detractors', render: (r: any) => String(r.detractor_count ?? 0) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
  ];

  const hospCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '' },
    { key: 'response_count', header: 'Responses', render: (r: any) => String(r.response_count ?? 0) },
    { key: 'promoter_count', header: 'Promoters', render: (r: any) => String(r.promoter_count ?? 0) },
    { key: 'detractor_count', header: 'Detractors', render: (r: any) => String(r.detractor_count ?? 0) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => String(r.nps_score ?? 0) },
  ];

  const actCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '' },
    { key: 'op_name', header: 'Op', render: (r: any) => r.op_name ?? '' },
    { key: 'after_value', header: 'Payload', render: (r: any) => r.after_value ? JSON.stringify(r.after_value) : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer NPS Pulse</h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Quarterly NPS by hospital & engineer & city — trend over time & detractor follow-up
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>NPS Trend (per quarter)</h2>
        <DataTable columns={trendCols} rows={trend.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top hospitals by response volume</h2>
        <DataTable columns={hospCols} rows={byHospital.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent survey responses</h2>
        <DataTable columns={surveyCols} rows={surveys.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent founder actions</h2>
        <DataTable columns={actCols} rows={actions.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
