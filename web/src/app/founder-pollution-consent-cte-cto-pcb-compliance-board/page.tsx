import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; consents: number; pct: number };
type BoardRow = {
  state_board: string;
  total_consents: number;
  compliant: number;
  renewal_due: number;
  condition_gap: number;
  notices_received: number;
  notices_open_total: number;
  avg_condition_compliance_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  consent_class: string;
  compliance_status: string;
  consents: number;
  avg_days_to_expiry: number;
  avg_condition_compliance_pct: number;
};
type TrendRow = {
  period_month: string;
  consents: number;
  compliant: number;
  notices_received: number;
  returns_pending: number;
  avg_condition_compliance_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_penalty_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_penalty_exposure_rupees: number;
  pct: number;
};
type GapRow = {
  category_band: string;
  consents: number;
  conditions_total_sum: number;
  conditions_met_sum: number;
  open_condition_gaps: number;
  avg_condition_compliance_pct: number;
};
type RiskRow = {
  facility_name: string;
  state_board: string;
  consent_no: string;
  consent_class: string;
  period_month: string;
  valid_till: string;
  days_to_expiry: number;
  compliance_status: string;
  notices_open: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    boardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3680_compliance_status_rollup'),
    supabase.rpc('founder_r3680_state_board_scorecard'),
    supabase.rpc('founder_r3680_class_status_matrix'),
    supabase.rpc('founder_r3680_monthly_compliance_trend'),
    supabase.rpc('founder_r3680_capa_status_board'),
    supabase.rpc('founder_r3680_root_cause_pareto'),
    supabase.rpc('founder_r3680_condition_gap_digest'),
    supabase.rpc('founder_r3680_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const boardRows: BoardRow[] = (boardRes.data as BoardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'consents', header: 'Consents' },
    { key: 'pct', header: 'Share %' },
  ];

  const boardCols: Column<BoardRow>[] = [
    { key: 'state_board', header: 'State Board' },
    { key: 'total_consents', header: 'Consents' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'condition_gap', header: 'Condition Gap' },
    { key: 'notices_received', header: 'Notices Received' },
    { key: 'notices_open_total', header: 'Notices Open' },
    { key: 'avg_condition_compliance_pct', header: 'Avg Condition %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'consent_class', header: 'Consent Class' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'consents', header: 'Consents' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_condition_compliance_pct', header: 'Avg Condition %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'consents', header: 'Consents' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'notices_received', header: 'Notices Received' },
    { key: 'returns_pending', header: 'Returns Pending' },
    { key: 'avg_condition_compliance_pct', header: 'Avg Condition %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_penalty_exposure_rupees', header: 'Avg Penalty Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_penalty_exposure_rupees', header: 'Total Penalty Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'category_band', header: 'Category Band' },
    { key: 'consents', header: 'Consents' },
    { key: 'conditions_total_sum', header: 'Conditions Total' },
    { key: 'conditions_met_sum', header: 'Conditions Met' },
    { key: 'open_condition_gaps', header: 'Open Gaps' },
    { key: 'avg_condition_compliance_pct', header: 'Avg Condition %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'facility_name', header: 'Facility' },
    { key: 'state_board', header: 'State Board' },
    { key: 'consent_no', header: 'Consent No' },
    { key: 'consent_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'valid_till', header: 'Valid Till' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'notices_open', header: 'Notices Open' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Pollution-Consent (CTE/CTO) / PCB Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        State pollution-control-board consent ledger — facility (Mumbai HQ, Chennai service hub,
        Delhi warehouse, Bengaluru refurb center) &times; state board (MPCB, TNPCB, DPCC, KSPCB)
        &times; consent class (CTE new, CTO operate, renewal, white-category exempt, hazwaste
        authorization) &times; validity &amp; days-to-expiry &times; condition compliance &times;
        returns filed &times; notices &amp; CAPA closure. Founder-gated view: compliance-status
        rollups, state-board scorecards, root-cause pareto, and condition-gap digest across
        CTE/CTO &amp; hazwaste-authorization surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No consents logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. State-board scorecard</h2>
        <DataTable
          rows={boardRows}
          columns={boardCols}
          emptyMessage="No state-board rollups."
          rowKey={(r, i) => String(r.state_board ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Consent class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No consents by class."
          rowKey={(r, i) => `${r.consent_class}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Condition-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No condition-gap rollups."
          rowKey={(r, i) => String(r.category_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk consent queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk consents."
          rowKey={(r, i) => `${r.consent_no}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
