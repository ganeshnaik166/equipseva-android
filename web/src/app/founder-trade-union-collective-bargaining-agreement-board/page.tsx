import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cba_status: string; entries: number; pct: number };
type UnionRow = {
  union_name: string;
  entries: number;
  total_members: number;
  wage_compliant_entries: number;
  strike_notices: number;
  total_grievances_raised: number;
  total_grievances_resolved: number;
  avg_committee_meetings: number;
  min_days_to_cba_expiry: number | null;
};
type MatrixRow = {
  union_class: string;
  cba_status: string;
  entries: number;
  avg_members: number | null;
};
type TrendRow = {
  period_month: string;
  entries: number;
  grievances_raised: number;
  grievances_resolved: number;
  strike_notices: number;
  worsening_entries: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type DisputeRow = {
  site_name: string;
  unions_at_risk: number;
  strike_notices: number;
  wage_noncompliant: number;
  open_grievances: number;
  min_days_to_cba_expiry: number | null;
};
type RiskRow = {
  union_name: string;
  site_name: string;
  period_month: string;
  cba_status: string;
  union_class: string;
  days_to_cba_expiry: number | null;
  strike_notice_issued: boolean;
  wage_settlement_compliant: boolean;
  grievances_raised: number | null;
  grievances_resolved: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    disputeRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3750_cba_status_rollup'),
    supabase.rpc('founder_r3750_union_scorecard'),
    supabase.rpc('founder_r3750_union_class_status_matrix'),
    supabase.rpc('founder_r3750_monthly_grievance_trend'),
    supabase.rpc('founder_r3750_capa_status_board'),
    supabase.rpc('founder_r3750_root_cause_pareto'),
    supabase.rpc('founder_r3750_dispute_digest'),
    supabase.rpc('founder_r3750_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unionRows: UnionRow[] = (unionRes.data as UnionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const disputeRows: DisputeRow[] = (disputeRes.data as DisputeRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cba_status', header: 'CBA Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const unionCols: Column<UnionRow>[] = [
    { key: 'union_name', header: 'Union' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_members', header: 'Total Members' },
    { key: 'wage_compliant_entries', header: 'Wage Compliant' },
    { key: 'strike_notices', header: 'Strike Notices' },
    { key: 'total_grievances_raised', header: 'Grievances Raised' },
    { key: 'total_grievances_resolved', header: 'Grievances Resolved' },
    { key: 'avg_committee_meetings', header: 'Avg Committee Meetings' },
    { key: 'min_days_to_cba_expiry', header: 'Min Days to CBA Expiry' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'union_class', header: 'Union Class' },
    { key: 'cba_status', header: 'CBA Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_members', header: 'Avg Members' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'grievances_raised', header: 'Grievances Raised' },
    { key: 'grievances_resolved', header: 'Grievances Resolved' },
    { key: 'strike_notices', header: 'Strike Notices' },
    { key: 'worsening_entries', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const disputeCols: Column<DisputeRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'unions_at_risk', header: 'Unions at Risk' },
    { key: 'strike_notices', header: 'Strike Notices' },
    { key: 'wage_noncompliant', header: 'Wage Non-Compliant' },
    { key: 'open_grievances', header: 'Open Grievances' },
    { key: 'min_days_to_cba_expiry', header: 'Min Days to CBA Expiry' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'union_name', header: 'Union' },
    { key: 'site_name', header: 'Site' },
    { key: 'period_month', header: 'Month' },
    { key: 'cba_status', header: 'CBA Status' },
    { key: 'union_class', header: 'Union Class' },
    { key: 'days_to_cba_expiry', header: 'Days to CBA Expiry' },
    { key: 'strike_notice_issued', header: 'Strike Notice' },
    { key: 'wage_settlement_compliant', header: 'Wage Compliant' },
    { key: 'grievances_raised', header: 'Grievances Raised' },
    { key: 'grievances_resolved', header: 'Grievances Resolved' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Trade Union / Collective-Bargaining Agreement Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Trade union recognition &amp; collective-bargaining agreement (CBA) compliance per site
        &times; union &mdash; CBA validity windows, wage-settlement compliance, grievance-committee
        meeting cadence, and strike/lockout risk indicators. Founder-gated view: CBA-status
        distribution, per-union scorecards, union-class &times; status matrix, monthly grievance
        trend, CAPA closure board, root-cause pareto, a dispute digest by site, and a high-risk
        queue of escalated disputes &amp; strike-risk unions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. CBA-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No trade-union rows logged yet."
          rowKey={(r, i) => String(r.cba_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Union scorecard</h2>
        <DataTable
          rows={unionRows}
          columns={unionCols}
          emptyMessage="No union rollups."
          rowKey={(r, i) => String(r.union_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Union class &times; CBA status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No unions by class."
          rowKey={(r, i) => `${r.union_class}-${r.cba_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly grievance trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Dispute digest by site</h2>
        <DataTable
          rows={disputeRows}
          columns={disputeCols}
          emptyMessage="No active disputes."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk unions."
          rowKey={(r, i) => `${r.union_name}-${r.site_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
