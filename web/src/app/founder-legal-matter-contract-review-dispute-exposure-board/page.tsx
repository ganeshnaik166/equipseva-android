import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  matter_status: string;
  matters: number;
  total_exposure_rupees: number;
  pct: number;
};
type HospRow = {
  hospital_name: string;
  total_matters: number;
  open_matters: number;
  disputes: number;
  external_counsel_matters: number;
  critical_matters: number;
  total_exposure_rupees: number;
  resolved_pct: number;
};
type MatrixRow = {
  matter_type: string;
  risk_rating: string;
  matters: number;
  total_exposure_rupees: number;
  avg_exposure_rupees: number;
};
type TrendRow = {
  opened_date: string;
  matters_opened: number;
  disputes: number;
  contract_reviews: number;
  exposure_opened_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  matter_ref: string;
  matter_type: string;
  matter_status: string;
  risk_rating: string;
  exposure_amount_rupees: number;
  external_counsel_engaged: boolean;
  next_deadline_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3221_matter_status_rollup'),
    supabase.rpc('founder_r3221_hospital_scorecard'),
    supabase.rpc('founder_r3221_type_risk_matrix'),
    supabase.rpc('founder_r3221_opened_daily_trend'),
    supabase.rpc('founder_r3221_capa_status_board'),
    supabase.rpc('founder_r3221_root_cause_pareto'),
    supabase.rpc('founder_r3221_regulatory_impact_digest'),
    supabase.rpc('founder_r3221_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'matter_status', header: 'Status' },
    { key: 'matters', header: 'Matters' },
    { key: 'total_exposure_rupees', header: 'Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'total_matters', header: 'Matters' },
    { key: 'open_matters', header: 'Open' },
    { key: 'disputes', header: 'Disputes' },
    { key: 'external_counsel_matters', header: 'Ext. Counsel' },
    { key: 'critical_matters', header: 'Critical' },
    { key: 'total_exposure_rupees', header: 'Exposure (INR)' },
    { key: 'resolved_pct', header: 'Resolved %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'matter_type', header: 'Matter Type' },
    { key: 'risk_rating', header: 'Risk' },
    { key: 'matters', header: 'Matters' },
    { key: 'total_exposure_rupees', header: 'Exposure (INR)' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'opened_date', header: 'Opened' },
    { key: 'matters_opened', header: 'Matters' },
    { key: 'disputes', header: 'Disputes' },
    { key: 'contract_reviews', header: 'Contract Reviews' },
    { key: 'exposure_opened_rupees', header: 'Exposure (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital / Entity' },
    { key: 'matter_ref', header: 'Ref' },
    { key: 'matter_type', header: 'Type' },
    { key: 'matter_status', header: 'Status' },
    { key: 'risk_rating', header: 'Risk' },
    { key: 'exposure_amount_rupees', header: 'Exposure (INR)' },
    { key: 'external_counsel_engaged', header: 'Ext. Counsel' },
    { key: 'next_deadline_date', header: 'Next Deadline' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Legal Matter, Contract Review &amp; Dispute Exposure Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Legal board — matter type &times; counterparty &times; exposure &times; external counsel &times;
        hearing/deadline dates &amp; resolution verdicts, with follow-up CAPA closure. Founder-gated view:
        status rollups, hospital scorecards, type &times; risk matrix, root-cause pareto, and
        regulatory-impact digest across CDSCO, labour-department &amp; DPDP surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Matter status rollup</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No legal matters logged yet."
          rowKey={(r, i) => String(r.matter_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital / entity exposure scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Matter type &times; risk matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matters by type."
          rowKey={(r, i) => `${r.matter_type}-${r.risk_rating}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Matters opened daily trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.opened_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk matter queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk matters."
          rowKey={(r, i) => `${r.matter_ref}-${i}`}
        />
      </section>
    </main>
  );
}
