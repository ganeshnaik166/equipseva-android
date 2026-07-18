import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; entities: number; pct: number };
type EntityRow = {
  entity_name: string;
  records: number;
  total_headcount: number;
  total_gross_rupees: number;
  pf_gap_rupees: number;
  esi_gap_rupees: number;
  tds_gap_rupees: number;
  penalty_exposure_rupees: number;
  compliance_pct: number;
};
type MatrixRow = {
  filing_status: string;
  penalty_risk: string;
  entities: number;
  penalty_exposure_rupees: number;
};
type TrendRow = {
  pay_month: string;
  entities: number;
  total_gross_rupees: number;
  total_penalty_rupees: number;
  fully_compliant: number;
  non_compliant: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  entity_name: string;
  entity_state: string;
  pay_cycle_label: string;
  filing_status: string;
  penalty_risk: string;
  compliance_verdict: string;
  estimated_penalty_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3173_verdict_rollup'),
    supabase.rpc('founder_r3173_entity_scorecard'),
    supabase.rpc('founder_r3173_filing_penalty_matrix'),
    supabase.rpc('founder_r3173_pay_month_trend'),
    supabase.rpc('founder_r3173_capa_status_board'),
    supabase.rpc('founder_r3173_root_cause_pareto'),
    supabase.rpc('founder_r3173_regulatory_impact_digest'),
    supabase.rpc('founder_r3173_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'entities', header: 'Entities' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'records', header: 'Months' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'total_gross_rupees', header: 'Gross Payroll (INR)' },
    { key: 'pf_gap_rupees', header: 'PF Gap (INR)' },
    { key: 'esi_gap_rupees', header: 'ESI Gap (INR)' },
    { key: 'tds_gap_rupees', header: 'TDS Gap (INR)' },
    { key: 'penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'filing_status', header: 'Filing Status' },
    { key: 'penalty_risk', header: 'Penalty Risk' },
    { key: 'entities', header: 'Entities' },
    { key: 'penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'pay_month', header: 'Pay Month' },
    { key: 'entities', header: 'Entities' },
    { key: 'total_gross_rupees', header: 'Gross Payroll (INR)' },
    { key: 'total_penalty_rupees', header: 'Penalty (INR)' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'entity_state', header: 'State' },
    { key: 'pay_cycle_label', header: 'Pay Cycle' },
    { key: 'filing_status', header: 'Filing Status' },
    { key: 'penalty_risk', header: 'Penalty Risk' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'estimated_penalty_rupees', header: 'Est. Penalty (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Payroll &amp; Statutory-Compliance (PF/ESI/TDS) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Monthly payroll statutory log — headcount &times; gross payroll &times; PF/ESI/TDS due-vs-paid
        &times; challan filing &times; penalty risk &times; compliance verdict &amp; CAPA closure.
        Founder-gated view: verdict rollup, entity scorecards, root-cause pareto, and
        regulatory-impact digest across EPFO, ESIC &amp; Income-Tax surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No compliance records yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity statutory scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.entity_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Filing status &times; penalty risk matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No filing-status data."
          rowKey={(r, i) => `${r.filing_status}-${r.penalty_risk}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Pay-month trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.pay_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entities."
          rowKey={(r, i) => `${r.entity_name}-${r.pay_cycle_label}-${i}`}
        />
      </section>
    </main>
  );
}
