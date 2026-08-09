import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { compliance_status: string; records: number; pct: number };
type ContractorRow = {
  contractor_name: string;
  total_records: number;
  compliant: number;
  renewal_due: number;
  register_gap: number;
  wage_gap: number;
  non_compliant: number;
  total_workers: number;
  avg_wage_compliance_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  site_type: string;
  compliance_status: string;
  records: number;
  total_workers: number;
  avg_registers_current_pct: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  compliant: number;
  non_compliant: number;
  avg_registers_current_pct: number;
  avg_wage_compliance_pct: number;
  pf_esi_pending: number;
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
type GapRow = {
  contractor_name: string;
  gap_records: number;
  register_gap_records: number;
  wage_gap_records: number;
  avg_registers_current_pct: number;
  avg_wage_compliance_pct: number;
  pf_esi_pending: number;
};
type RiskRow = {
  site_name: string;
  contractor_name: string;
  period_month: string;
  clra_licence_no: string;
  licence_expiry: string | null;
  days_to_expiry: number | null;
  contract_workers: number;
  compliance_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    contractorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3679_compliance_status_rollup'),
    supabase.rpc('founder_r3679_contractor_scorecard'),
    supabase.rpc('founder_r3679_site_type_status_matrix'),
    supabase.rpc('founder_r3679_monthly_compliance_trend'),
    supabase.rpc('founder_r3679_capa_status_board'),
    supabase.rpc('founder_r3679_root_cause_pareto'),
    supabase.rpc('founder_r3679_wage_register_gap_digest'),
    supabase.rpc('founder_r3679_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const contractorRows: ContractorRow[] = (contractorRes.data as ContractorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const contractorCols: Column<ContractorRow>[] = [
    { key: 'contractor_name', header: 'Contractor' },
    { key: 'total_records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'register_gap', header: 'Register Gap' },
    { key: 'wage_gap', header: 'Wage Gap' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'total_workers', header: 'Workers' },
    { key: 'avg_wage_compliance_pct', header: 'Avg Wage %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'site_type', header: 'Site Type' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_workers', header: 'Workers' },
    { key: 'avg_registers_current_pct', header: 'Avg Registers %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'avg_registers_current_pct', header: 'Avg Registers %' },
    { key: 'avg_wage_compliance_pct', header: 'Avg Wage %' },
    { key: 'pf_esi_pending', header: 'PF/ESI Pending' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'contractor_name', header: 'Contractor' },
    { key: 'gap_records', header: 'Gap Records' },
    { key: 'register_gap_records', header: 'Register Gaps' },
    { key: 'wage_gap_records', header: 'Wage Gaps' },
    { key: 'avg_registers_current_pct', header: 'Avg Registers %' },
    { key: 'avg_wage_compliance_pct', header: 'Avg Wage %' },
    { key: 'pf_esi_pending', header: 'PF/ESI Pending' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'contractor_name', header: 'Contractor' },
    { key: 'period_month', header: 'Month' },
    { key: 'clra_licence_no', header: 'Licence No' },
    { key: 'licence_expiry', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'contract_workers', header: 'Workers' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Contract-Labour (CLRA) Licence / Register Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Contract Labour (Regulation &amp; Abolition) Act compliance — site &times; contractor
        &times; CLRA licence &amp; expiry &times; statutory registers currency &times; wage
        compliance &times; PF/ESI remittance &times; open inspections across Mumbai HQ, Chennai
        workshop, Delhi warehouse, Bengaluru refurb center &amp; deployed customer sites.
        Founder-gated view: compliance-status rollups, contractor scorecards, root-cause pareto,
        wage/register-gap digest and high-risk renewal queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No CLRA compliance records logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Contractor compliance scorecard</h2>
        <DataTable
          rows={contractorRows}
          columns={contractorCols}
          emptyMessage="No contractor rollups."
          rowKey={(r, i) => String(r.contractor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Site type &times; compliance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by site type."
          rowKey={(r, i) => `${r.site_type}-${r.compliance_status}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Wage / register gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No wage or register gaps."
          rowKey={(r, i) => `${r.contractor_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk compliance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.clra_licence_no}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
