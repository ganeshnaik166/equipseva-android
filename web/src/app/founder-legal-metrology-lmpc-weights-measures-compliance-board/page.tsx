import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; item_lines: number; pct: number };
type StateRow = {
  state_region: string;
  total_lines: number;
  compliant: number;
  renewal_due: number;
  declaration_gap: number;
  verification_overdue: number;
  notice_received: number;
  avg_declaration_pct: number;
  avg_stamping_pct: number;
};
type MatrixRow = {
  compliance_area: string;
  compliance_status: string;
  item_lines: number;
  notices_total: number;
  avg_declaration_pct: number;
};
type TrendRow = {
  period_month: string;
  item_lines: number;
  compliant: number;
  notices_total: number;
  verification_due_total: number;
  avg_declaration_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_penalty_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_penalty_exposure_rupees: number;
  pct: number;
};
type NoticeRow = {
  compliance_area: string;
  item_lines: number;
  notices_total: number;
  notice_received_lines: number;
  verification_overdue_lines: number;
  avg_days_to_expiry: number;
};
type RiskRow = {
  site_name: string;
  item_line: string;
  lmpc_registration_no: string;
  state_region: string;
  period_month: string;
  compliance_area: string;
  compliance_status: string;
  days_to_expiry: number | null;
  notices_open: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    stateRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    noticeRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3678_compliance_status_rollup'),
    supabase.rpc('founder_r3678_state_scorecard'),
    supabase.rpc('founder_r3678_area_status_matrix'),
    supabase.rpc('founder_r3678_monthly_compliance_trend'),
    supabase.rpc('founder_r3678_capa_status_board'),
    supabase.rpc('founder_r3678_root_cause_pareto'),
    supabase.rpc('founder_r3678_notice_exposure_digest'),
    supabase.rpc('founder_r3678_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const stateRows: StateRow[] = (stateRes.data as StateRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const noticeRows: NoticeRow[] = (noticeRes.data as NoticeRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Status' },
    { key: 'item_lines', header: 'Item Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const stateCols: Column<StateRow>[] = [
    { key: 'state_region', header: 'State' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'declaration_gap', header: 'Declaration Gap' },
    { key: 'verification_overdue', header: 'Verification Overdue' },
    { key: 'notice_received', header: 'Notice Received' },
    { key: 'avg_declaration_pct', header: 'Avg Declaration %' },
    { key: 'avg_stamping_pct', header: 'Avg Stamping %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'compliance_area', header: 'Compliance Area' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'item_lines', header: 'Item Lines' },
    { key: 'notices_total', header: 'Notices Open' },
    { key: 'avg_declaration_pct', header: 'Avg Declaration %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'item_lines', header: 'Item Lines' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'notices_total', header: 'Notices Open' },
    { key: 'verification_due_total', header: 'Verifications Due' },
    { key: 'avg_declaration_pct', header: 'Avg Declaration %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_penalty_exposure_rupees', header: 'Avg Penalty Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_penalty_exposure_rupees', header: 'Total Penalty Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const noticeCols: Column<NoticeRow>[] = [
    { key: 'compliance_area', header: 'Compliance Area' },
    { key: 'item_lines', header: 'Item Lines' },
    { key: 'notices_total', header: 'Notices Open' },
    { key: 'notice_received_lines', header: 'Notice-Received Lines' },
    { key: 'verification_overdue_lines', header: 'Verification-Overdue Lines' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'item_line', header: 'Item Line' },
    { key: 'lmpc_registration_no', header: 'Registration No' },
    { key: 'state_region', header: 'State' },
    { key: 'period_month', header: 'Month' },
    { key: 'compliance_area', header: 'Area' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'notices_open', header: 'Notices' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Legal-Metrology / LMPC / Weights-Measures Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Legal-metrology compliance log — item line &times; state (MH / TN / DL / KA) &times;
        LMPC packaged-commodity registration &amp; expiry runway &times; declaration-compliant %
        &times; weighing / measuring instrument re-verification &amp; stamping currency &times;
        dealer licences &times; controller notices &amp; CAPA closure. Founder-gated view: status
        distribution, state scorecards, area &times; status matrix, monthly trend, root-cause
        pareto, and notice-exposure digest across Mumbai HQ, Chennai, Delhi warehouse &amp;
        Bengaluru refurb operations.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No compliance lines logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. State scorecard</h2>
        <DataTable
          rows={stateRows}
          columns={stateCols}
          emptyMessage="No state rollups."
          rowKey={(r, i) => String(r.state_region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Compliance area &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by compliance area."
          rowKey={(r, i) => `${r.compliance_area}-${r.compliance_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Notice-exposure digest</h2>
        <DataTable
          rows={noticeRows}
          columns={noticeCols}
          emptyMessage="No notice-exposure rollups."
          rowKey={(r, i) => String(r.compliance_area ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk compliance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.lmpc_registration_no}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
