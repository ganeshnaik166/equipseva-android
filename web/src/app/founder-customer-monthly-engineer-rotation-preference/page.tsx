import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RotationRow = {
  id: string;
  cycle_month: string;
  customer_org_name: string;
  city: string;
  preferred_engineer_name: string;
  actual_engineer_name: string;
  match_status: string;
  satisfaction_score: number;
  rotation_reason: string;
  outcome: string;
  jobs_in_month: number;
  monthly_revenue_rupees: number;
};

type ReasonRow = {
  rotation_reason: string;
  customer_count: number;
  avg_satisfaction: number;
  churn_count: number;
  total_revenue: number;
};

type OutcomeRow = {
  outcome: string;
  cust_count: number;
  share_pct: number;
  revenue_share_pct: number;
};

type CatalogRow = {
  id: string;
  rotation_reason: string;
  expected_satisfaction_delta: number;
  expected_churn_pct: number;
  mitigation_action: string;
  priority: string;
  active: boolean;
};

type MatchSummaryRow = {
  match_status: string;
  cust_count: number;
  avg_satisfaction: number;
  avg_jobs: number;
};

type Kpis = {
  total_customers: number;
  matched_pct: number;
  avg_satisfaction: number;
  at_risk_customers: number;
  churned_customers: number;
  total_monthly_revenue: number;
};

function fmtRupees(n: number): string {
  if (!n) return '₹0';
  return '₹' + Math.round(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, rowsRes, reasonRes, outcomeRes, catalogRes, matchRes, atRiskRes] = await Promise.all([
    supabase.rpc('founder_r2688_rotation_kpis'),
    supabase.rpc('founder_r2688_rotation_rows'),
    supabase.rpc('founder_r2688_reason_breakdown'),
    supabase.rpc('founder_r2688_outcome_mix'),
    supabase.rpc('founder_r2688_catalog_rows'),
    supabase.rpc('founder_r2688_match_status_summary'),
    supabase.rpc('founder_r2688_at_risk_customers'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_customers: 0,
    matched_pct: 0,
    avg_satisfaction: 0,
    at_risk_customers: 0,
    churned_customers: 0,
    total_monthly_revenue: 0,
  };
  const rows: RotationRow[] = (rowsRes.data as RotationRow[]) ?? [];
  const reasons: ReasonRow[] = (reasonRes.data as ReasonRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];
  const catalog: CatalogRow[] = (catalogRes.data as CatalogRow[]) ?? [];
  const matchSummary: MatchSummaryRow[] = (matchRes.data as MatchSummaryRow[]) ?? [];
  const atRisk: RotationRow[] = (atRiskRes.data as RotationRow[]) ?? [];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>
        Customer Monthly Engineer Rotation Preference
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r2688 · preferred engineer vs actual, satisfaction, rotation reason, outcome
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <KpiCard label="Total Customers" value={String(kpis.total_customers)} />
        <KpiCard label="Matched %" value={`${kpis.matched_pct}%`} />
        <KpiCard label="Avg Satisfaction" value={`${kpis.avg_satisfaction} / 10`} />
        <KpiCard label="At Risk" value={String(kpis.at_risk_customers)} />
        <KpiCard label="Churned" value={String(kpis.churned_customers)} />
        <KpiCard label="Monthly Revenue" value={fmtRupees(kpis.total_monthly_revenue)} />
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Customer Rotation Snapshot</h2>
      <DataTable
        rows={rows}
        columns={[
          { key: 'customer_org_name', header: 'Customer', render: (r: RotationRow) => r.customer_org_name },
          { key: 'city', header: 'City', render: (r: RotationRow) => r.city },
          { key: 'preferred_engineer_name', header: 'Preferred Eng', render: (r: RotationRow) => r.preferred_engineer_name },
          { key: 'actual_engineer_name', header: 'Actual Eng', render: (r: RotationRow) => r.actual_engineer_name },
          { key: 'match_status', header: 'Match', render: (r: RotationRow) => r.match_status },
          { key: 'satisfaction_score', header: 'CSAT', render: (r: RotationRow) => r.satisfaction_score.toFixed(1) },
          { key: 'rotation_reason', header: 'Reason', render: (r: RotationRow) => r.rotation_reason },
          { key: 'outcome', header: 'Outcome', render: (r: RotationRow) => r.outcome },
          { key: 'jobs_in_month', header: 'Jobs', render: (r: RotationRow) => String(r.jobs_in_month) },
          { key: 'monthly_revenue_rupees', header: 'Revenue', render: (r: RotationRow) => fmtRupees(r.monthly_revenue_rupees) },
        ]}
        emptyMessage="No data"
        rowKey={(r: RotationRow, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Rotation Reason Breakdown</h2>
      <DataTable
        rows={reasons}
        columns={[
          { key: 'rotation_reason', header: 'Reason', render: (r: ReasonRow) => r.rotation_reason },
          { key: 'customer_count', header: 'Customers', render: (r: ReasonRow) => String(r.customer_count) },
          { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: ReasonRow) => Number(r.avg_satisfaction).toFixed(2) },
          { key: 'churn_count', header: 'Churned', render: (r: ReasonRow) => String(r.churn_count) },
          { key: 'total_revenue', header: 'Revenue', render: (r: ReasonRow) => fmtRupees(r.total_revenue) },
        ]}
        emptyMessage="No data"
        rowKey={(r: ReasonRow, i: number) => String(r.rotation_reason ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Outcome Mix</h2>
      <DataTable
        rows={outcomes}
        columns={[
          { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
          { key: 'cust_count', header: 'Customers', render: (r: OutcomeRow) => String(r.cust_count) },
          { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => `${r.share_pct}%` },
          { key: 'revenue_share_pct', header: 'Rev Share %', render: (r: OutcomeRow) => `${r.revenue_share_pct}%` },
        ]}
        emptyMessage="No data"
        rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Match Status Summary</h2>
      <DataTable
        rows={matchSummary}
        columns={[
          { key: 'match_status', header: 'Match Status', render: (r: MatchSummaryRow) => r.match_status },
          { key: 'cust_count', header: 'Customers', render: (r: MatchSummaryRow) => String(r.cust_count) },
          { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: MatchSummaryRow) => Number(r.avg_satisfaction).toFixed(2) },
          { key: 'avg_jobs', header: 'Avg Jobs', render: (r: MatchSummaryRow) => Number(r.avg_jobs).toFixed(2) },
        ]}
        emptyMessage="No data"
        rowKey={(r: MatchSummaryRow, i: number) => String(r.match_status ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>At-Risk & Churned Customers</h2>
      <DataTable
        rows={atRisk}
        columns={[
          { key: 'customer_org_name', header: 'Customer', render: (r: RotationRow) => r.customer_org_name },
          { key: 'preferred_engineer_name', header: 'Preferred', render: (r: RotationRow) => r.preferred_engineer_name },
          { key: 'actual_engineer_name', header: 'Actual', render: (r: RotationRow) => r.actual_engineer_name },
          { key: 'satisfaction_score', header: 'CSAT', render: (r: RotationRow) => r.satisfaction_score.toFixed(1) },
          { key: 'rotation_reason', header: 'Reason', render: (r: RotationRow) => r.rotation_reason },
          { key: 'outcome', header: 'Outcome', render: (r: RotationRow) => r.outcome },
          { key: 'monthly_revenue_rupees', header: 'Revenue', render: (r: RotationRow) => fmtRupees(r.monthly_revenue_rupees) },
        ]}
        emptyMessage="No data"
        rowKey={(r: RotationRow, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Rotation Outcome Catalog</h2>
      <DataTable
        rows={catalog}
        columns={[
          { key: 'rotation_reason', header: 'Reason', render: (r: CatalogRow) => r.rotation_reason },
          { key: 'expected_satisfaction_delta', header: 'CSAT Delta', render: (r: CatalogRow) => Number(r.expected_satisfaction_delta).toFixed(1) },
          { key: 'expected_churn_pct', header: 'Expected Churn %', render: (r: CatalogRow) => `${Number(r.expected_churn_pct).toFixed(2)}%` },
          { key: 'mitigation_action', header: 'Mitigation', render: (r: CatalogRow) => r.mitigation_action },
          { key: 'priority', header: 'Priority', render: (r: CatalogRow) => r.priority },
          { key: 'active', header: 'Active', render: (r: CatalogRow) => (r.active ? 'yes' : 'no') },
        ]}
        emptyMessage="No data"
        rowKey={(r: CatalogRow, i: number) => String(r.id ?? i)}
      />
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
