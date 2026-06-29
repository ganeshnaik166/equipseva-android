import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = { metric: string; value: string; context: string };
type LeaderboardRow = {
  engineer_name: string;
  city: string;
  tier_at_month: string;
  total_repairs: number;
  rft_rate_pct: number;
  rework_rate_pct: number;
  customer_csat_avg: number;
  risk_flag: string;
};
type TrendRow = {
  month_label: string;
  total_repairs: number;
  rft_rate_pct: number;
  rework_rate_pct: number;
  avg_csat: number;
  avg_repair_hours: number;
};
type CityRow = {
  city: string;
  engineer_count: number;
  total_repairs: number;
  rft_rate_pct: number;
  rework_rate_pct: number;
  avg_csat: number;
};
type RootCauseRow = {
  root_cause: string;
  incident_count: number;
  total_cost_rupees: number;
  avg_csat_drop: number;
  open_count: number;
};
type OpenIncidentRow = {
  engineer_name: string;
  hospital_name: string;
  equipment_kind: string;
  root_cause: string;
  severity: string;
  cost_to_company_rupees: number;
  incident_date: string;
  corrective_action: string;
};
type RedFlagRow = {
  engineer_name: string;
  city: string;
  month_label: string;
  rft_rate_pct: number;
  rework_rate_pct: number;
  customer_csat_avg: number;
  risk_flag: string;
  recommendation: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, leaderboard, trend, city, rootCause, openHigh, redFlag] = await Promise.all([
    supabase.rpc('founder_r2906_overview'),
    supabase.rpc('founder_r2906_engineer_leaderboard'),
    supabase.rpc('founder_r2906_monthly_trend'),
    supabase.rpc('founder_r2906_city_breakdown'),
    supabase.rpc('founder_r2906_root_cause_distribution'),
    supabase.rpc('founder_r2906_high_severity_open'),
    supabase.rpc('founder_r2906_red_flag_engineers'),
  ]);

  const overviewRows = (overview.data ?? []) as OverviewRow[];
  const leaderboardRows = (leaderboard.data ?? []) as LeaderboardRow[];
  const trendRows = (trend.data ?? []) as TrendRow[];
  const cityRows = (city.data ?? []) as CityRow[];
  const rootCauseRows = (rootCause.data ?? []) as RootCauseRow[];
  const openHighRows = (openHigh.data ?? []) as OpenIncidentRow[];
  const redFlagRows = (redFlag.data ?? []) as RedFlagRow[];

  const overviewCols: Column<OverviewRow>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric },
    { key: 'value', header: 'Value', render: (r) => r.value },
    { key: 'context', header: 'Context', render: (r) => r.context },
  ];

  const leaderboardCols: Column<LeaderboardRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'tier_at_month', header: 'Tier', render: (r) => r.tier_at_month },
    { key: 'total_repairs', header: 'Repairs', render: (r) => String(r.total_repairs) },
    { key: 'rft_rate_pct', header: 'RFT %', render: (r) => `${r.rft_rate_pct}%` },
    { key: 'rework_rate_pct', header: 'Rework %', render: (r) => `${r.rework_rate_pct}%` },
    { key: 'customer_csat_avg', header: 'CSAT', render: (r) => String(r.customer_csat_avg) },
    { key: 'risk_flag', header: 'Risk', render: (r) => r.risk_flag.toUpperCase() },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'total_repairs', header: 'Repairs', render: (r) => String(r.total_repairs) },
    { key: 'rft_rate_pct', header: 'RFT %', render: (r) => `${r.rft_rate_pct}%` },
    { key: 'rework_rate_pct', header: 'Rework %', render: (r) => `${r.rework_rate_pct}%` },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => String(r.avg_csat) },
    { key: 'avg_repair_hours', header: 'Avg Hours', render: (r) => String(r.avg_repair_hours) },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'engineer_count', header: 'Engineers', render: (r) => String(r.engineer_count) },
    { key: 'total_repairs', header: 'Repairs', render: (r) => String(r.total_repairs) },
    { key: 'rft_rate_pct', header: 'RFT %', render: (r) => `${r.rft_rate_pct}%` },
    { key: 'rework_rate_pct', header: 'Rework %', render: (r) => `${r.rework_rate_pct}%` },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r) => String(r.avg_csat) },
  ];

  const rootCauseCols: Column<RootCauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'incident_count', header: 'Incidents', render: (r) => String(r.incident_count) },
    { key: 'total_cost_rupees', header: 'Cost (₹)', render: (r) => `₹${r.total_cost_rupees}` },
    { key: 'avg_csat_drop', header: 'Avg CSAT Drop', render: (r) => String(r.avg_csat_drop) },
    { key: 'open_count', header: 'Open', render: (r) => String(r.open_count) },
  ];

  const openHighCols: Column<OpenIncidentRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'equipment_kind', header: 'Equipment', render: (r) => r.equipment_kind },
    { key: 'root_cause', header: 'Root Cause', render: (r) => r.root_cause },
    { key: 'severity', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'cost_to_company_rupees', header: 'Cost (₹)', render: (r) => `₹${r.cost_to_company_rupees}` },
    { key: 'incident_date', header: 'Date', render: (r) => r.incident_date },
    { key: 'corrective_action', header: 'Action', render: (r) => r.corrective_action },
  ];

  const redFlagCols: Column<RedFlagRow>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'rft_rate_pct', header: 'RFT %', render: (r) => `${r.rft_rate_pct}%` },
    { key: 'rework_rate_pct', header: 'Rework %', render: (r) => `${r.rework_rate_pct}%` },
    { key: 'customer_csat_avg', header: 'CSAT', render: (r) => String(r.customer_csat_avg) },
    { key: 'risk_flag', header: 'Flag', render: (r) => r.risk_flag.toUpperCase() },
    { key: 'recommendation', header: 'Recommendation', render: (r) => r.recommendation },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
          Engineer Monthly Customer Repair — RFT vs Rework Rate
        </h1>
        <p style={{ color: '#6b7280', fontSize: '14px' }}>
          Round r2906 · founder console · right-first-time performance & rework cost telemetry per engineer per month
        </p>
      </header>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>KPI Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '12px' }}>
          {overviewRows.map((r, i) => (
            <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px', background: '#fff' }}>
              <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                {r.metric}
              </div>
              <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '6px' }}>{r.value}</div>
              <div style={{ fontSize: '12px', color: '#9ca3af', marginTop: '4px' }}>{r.context}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Engineer Leaderboard — RFT Ranking</h2>
        <DataTable
          rows={leaderboardRows}
          columns={leaderboardCols}
          emptyMessage="No engineer data."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>City Breakdown</h2>
        <DataTable
          rows={cityRows}
          columns={cityCols}
          emptyMessage="No city data."
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Root Cause Distribution</h2>
        <DataTable
          rows={rootCauseRows}
          columns={rootCauseCols}
          emptyMessage="No root cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Open High-Severity Rework Incidents</h2>
        <DataTable
          rows={openHighRows}
          columns={openHighCols}
          emptyMessage="No open high-severity incidents."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Red-Flag Engineers — Intervention Queue</h2>
        <DataTable
          rows={redFlagRows}
          columns={redFlagCols}
          emptyMessage="No red-flag engineers."
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
