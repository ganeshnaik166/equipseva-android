import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: number | null; unit: string };
type TopEngRow = {
  id: string;
  engineer_name: string | null;
  hospital_name: string | null;
  nps_score: number | null;
  prev_month_nps: number | null;
  nps_lift: number | null;
  recommendation_rate: number | null;
};
type DetractorRow = {
  id: string;
  engineer_name: string | null;
  hospital_name: string | null;
  nps_score: number | null;
  detractors: number | null;
  top_weakness: string | null;
  region: string | null;
};
type HospLeader = {
  id: string;
  hospital_name: string | null;
  region: string | null;
  avg_nps: number | null;
  avg_recommendation_rate: number | null;
  total_surveys_responded: number | null;
};
type ActionRow = {
  id: string;
  action_type: string | null;
  action_status: string | null;
  engineer_name: string | null;
  hospital_name: string | null;
  trigger_nps_score: number | null;
  target_nps_lift: number | null;
  realized_nps_lift: number | null;
  owner_name: string | null;
};
type RegionRow = {
  id: string;
  region: string | null;
  avg_nps: number | null;
  avg_lift: number | null;
  total_visits: number | null;
  response_rate_pct: number | null;
};
type TrendRow = {
  id: string;
  survey_month: string | null;
  avg_nps: number | null;
  avg_lift: number | null;
  total_promoters: number | null;
  total_detractors: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiR, topR, detR, hospR, actR, regR, trendR] = await Promise.all([
    supabase.rpc('rpc_r2920_nps_kpi_summary'),
    supabase.rpc('rpc_r2920_top_engineers_by_lift'),
    supabase.rpc('rpc_r2920_detractor_engineers'),
    supabase.rpc('rpc_r2920_hospital_recommendation_leaderboard'),
    supabase.rpc('rpc_r2920_action_effectiveness'),
    supabase.rpc('rpc_r2920_regional_breakdown'),
    supabase.rpc('rpc_r2920_month_over_month_trend'),
  ]);

  const kpis: KpiRow[] = (kpiR.data ?? []) as KpiRow[];
  const top: TopEngRow[] = (topR.data ?? []) as TopEngRow[];
  const det: DetractorRow[] = (detR.data ?? []) as DetractorRow[];
  const hosp: HospLeader[] = (hospR.data ?? []) as HospLeader[];
  const acts: ActionRow[] = (actR.data ?? []) as ActionRow[];
  const regs: RegionRow[] = (regR.data ?? []) as RegionRow[];
  const trends: TrendRow[] = (trendR.data ?? []) as TrendRow[];

  const fmt = (v: number | null | undefined, suffix = '') =>
    v === null || v === undefined ? '—' : `${Number(v).toFixed(2)}${suffix}`;

  const topCols: Column<TopEngRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'nps_score', header: 'NPS', render: (r) => fmt(r.nps_score) },
    { key: 'prev_month_nps', header: 'Prev NPS', render: (r) => fmt(r.prev_month_nps) },
    { key: 'nps_lift', header: 'Lift', render: (r) => fmt(r.nps_lift, ' pts') },
    { key: 'recommendation_rate', header: 'Reco %', render: (r) => fmt(r.recommendation_rate, '%') },
  ];

  const detCols: Column<DetractorRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'region', header: 'Region', render: (r) => r.region ?? '—' },
    { key: 'nps_score', header: 'NPS', render: (r) => fmt(r.nps_score) },
    { key: 'detractors', header: 'Detractors', render: (r) => r.detractors ?? 0 },
    { key: 'top_weakness', header: 'Weakness', render: (r) => r.top_weakness ?? '—' },
  ];

  const hospCols: Column<HospLeader>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'region', header: 'Region', render: (r) => r.region ?? '—' },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmt(r.avg_nps) },
    { key: 'avg_recommendation_rate', header: 'Avg Reco %', render: (r) => fmt(r.avg_recommendation_rate, '%') },
    { key: 'total_surveys_responded', header: 'Responses', render: (r) => r.total_surveys_responded ?? 0 },
  ];

  const actCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r) => r.action_type ?? '—' },
    { key: 'action_status', header: 'Status', render: (r) => r.action_status ?? '—' },
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name ?? '—' },
    { key: 'trigger_nps_score', header: 'Trigger NPS', render: (r) => fmt(r.trigger_nps_score) },
    { key: 'target_nps_lift', header: 'Target Lift', render: (r) => fmt(r.target_nps_lift) },
    { key: 'realized_nps_lift', header: 'Realized Lift', render: (r) => fmt(r.realized_nps_lift) },
    { key: 'owner_name', header: 'Owner', render: (r) => r.owner_name ?? '—' },
  ];

  const regCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region ?? '—' },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmt(r.avg_nps) },
    { key: 'avg_lift', header: 'Avg Lift', render: (r) => fmt(r.avg_lift) },
    { key: 'total_visits', header: 'Visits', render: (r) => r.total_visits ?? 0 },
    { key: 'response_rate_pct', header: 'Response %', render: (r) => fmt(r.response_rate_pct, '%') },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'survey_month', header: 'Month', render: (r) => r.survey_month ?? '—' },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmt(r.avg_nps) },
    { key: 'avg_lift', header: 'Avg Lift', render: (r) => fmt(r.avg_lift) },
    { key: 'total_promoters', header: 'Promoters', render: (r) => r.total_promoters ?? 0 },
    { key: 'total_detractors', header: 'Detractors', render: (r) => r.total_detractors ?? 0 },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>
          Customer Monthly Engineer Post-Visit Hospital Recommendation NPS Lift
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Founder console · r2920 · monthly post-visit NPS & recommendation lift per engineer & hospital
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        {kpis.map((k, i) => (
          <div key={`${k.metric}-${i}`} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 14 }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280' }}>{k.metric}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 6 }}>
              {k.value === null || k.value === undefined ? '—' : Number(k.value).toFixed(2)}
              <span style={{ fontSize: 12, color: '#6b7280', marginLeft: 4 }}>{k.unit}</span>
            </div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top engineers by NPS lift</h2>
        <DataTable
          rows={top}
          columns={topCols}
          emptyMessage="No engineers ranked yet"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Detractor engineers (NPS &lt; 50)</h2>
        <DataTable
          rows={det}
          columns={detCols}
          emptyMessage="No detractor engineers this month"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital recommendation leaderboard</h2>
        <DataTable
          rows={hosp}
          columns={hospCols}
          emptyMessage="No hospital responses captured"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>NPS lift actions & effectiveness</h2>
        <DataTable
          rows={acts}
          columns={actCols}
          emptyMessage="No coaching/lift actions open"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Regional breakdown</h2>
        <DataTable
          rows={regs}
          columns={regCols}
          emptyMessage="No regional data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Month-over-month trend</h2>
        <DataTable
          rows={trends}
          columns={trendCols}
          emptyMessage="No trend data yet"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
