import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { spend_status: string; apps: number; pct: number };
type DeptRow = {
  owner_department: string;
  total_apps: number;
  optimized: number;
  underutilized: number;
  shadow_apps: number;
  redundant_apps: number;
  sso_missing: number;
  total_annual_spend_rupees: number;
  avg_utilization_pct: number;
};
type MatrixRow = {
  app_category: string;
  spend_status: string;
  apps: number;
  total_annual_spend_rupees: number;
  avg_utilization_pct: number;
};
type TrendRow = {
  period_month: string;
  apps: number;
  total_annual_spend_rupees: number;
  avg_utilization_pct: number;
  shadow_apps: number;
  worsening_apps: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type WasteRow = {
  owner_department: string;
  apps: number;
  seats_licensed_total: number;
  seats_active_total: number;
  seats_wasted: number;
  wasted_spend_rupees: number;
  avg_utilization_pct: number;
};
type RiskRow = {
  app_name: string;
  owner_department: string;
  app_category: string;
  period_month: string;
  spend_status: string;
  seats_licensed: number;
  seats_active: number;
  seat_utilization_pct: number | null;
  annual_spend_rupees: number | null;
  days_to_renewal: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    wasteRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3673_spend_status_rollup'),
    supabase.rpc('founder_r3673_department_scorecard'),
    supabase.rpc('founder_r3673_category_status_matrix'),
    supabase.rpc('founder_r3673_monthly_spend_trend'),
    supabase.rpc('founder_r3673_capa_status_board'),
    supabase.rpc('founder_r3673_root_cause_pareto'),
    supabase.rpc('founder_r3673_seat_waste_digest'),
    supabase.rpc('founder_r3673_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const wasteRows: WasteRow[] = (wasteRes.data as WasteRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'apps', header: 'Apps' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'owner_department', header: 'Department' },
    { key: 'total_apps', header: 'Apps' },
    { key: 'optimized', header: 'Optimized' },
    { key: 'underutilized', header: 'Underutilized' },
    { key: 'shadow_apps', header: 'Shadow IT' },
    { key: 'redundant_apps', header: 'Redundant' },
    { key: 'sso_missing', header: 'No SSO' },
    { key: 'total_annual_spend_rupees', header: 'Annual Spend (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'app_category', header: 'Category' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'apps', header: 'Apps' },
    { key: 'total_annual_spend_rupees', header: 'Annual Spend (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'apps', header: 'Apps' },
    { key: 'total_annual_spend_rupees', header: 'Annual Spend (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'shadow_apps', header: 'Shadow IT' },
    { key: 'worsening_apps', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const wasteCols: Column<WasteRow>[] = [
    { key: 'owner_department', header: 'Department' },
    { key: 'apps', header: 'Apps' },
    { key: 'seats_licensed_total', header: 'Seats Licensed' },
    { key: 'seats_active_total', header: 'Seats Active' },
    { key: 'seats_wasted', header: 'Seats Wasted' },
    { key: 'wasted_spend_rupees', header: 'Wasted Spend (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'app_name', header: 'App' },
    { key: 'owner_department', header: 'Department' },
    { key: 'app_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'seats_licensed', header: 'Licensed' },
    { key: 'seats_active', header: 'Active' },
    { key: 'seat_utilization_pct', header: 'Util %' },
    { key: 'annual_spend_rupees', header: 'Annual Spend (INR)' },
    { key: 'days_to_renewal', header: 'Days to Renewal' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        SaaS-Subscription Spend / Shadow-IT License Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-application SaaS governance log — app (Zoho, Slack, Figma, Tally, Darwinbox, GitHub)
        &times; owner department &times; period month &times; seats licensed vs active &times;
        seat utilization &times; annual spend &times; cost per active seat &times; renewal runway
        &times; SSO integration &times; shadow-IT discovery &amp; CAPA closure. Founder-gated view:
        spend-status distribution, department scorecards, seat-waste digest, root-cause pareto,
        and a high-risk queue of shadow-IT &amp; redundant licences.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No SaaS spend rows logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department spend scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.owner_department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. App category &times; spend status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No apps by category."
          rowKey={(r, i) => `${r.app_category}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Seat-waste digest by department</h2>
        <DataTable
          rows={wasteRows}
          columns={wasteCols}
          emptyMessage="No seat-waste rollups."
          rowKey={(r, i) => String(r.owner_department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk license queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk licences."
          rowKey={(r, i) => `${r.app_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
