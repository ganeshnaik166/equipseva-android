import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  instrument_verdict: string;
  instruments: number;
  total_amount_rupees: number;
  pct: number;
};
type CustomerRow = {
  customer_entity: string;
  total_instruments: number;
  won: number;
  lost: number;
  pending: number;
  reclaim_due: number;
  forfeited: number;
  total_amount_rupees: number;
  blocked_capital_rupees: number;
};
type MatrixRow = {
  instrument_type: string;
  tender_outcome: string;
  instruments: number;
  total_amount_rupees: number;
  blocked_capital_rupees: number;
  avg_days_to_expiry: number;
};
type TrendRow = {
  validity_end: string;
  instruments: number;
  total_amount_rupees: number;
  reclaim_due: number;
  forfeit_risk: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ExposureRow = {
  exposure_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  tender_ref: string;
  customer_entity: string;
  instrument_type: string;
  issuing_bank: string;
  amount_rupees: number;
  validity_end: string;
  tender_outcome: string;
  reclaim_status: string;
  days_to_expiry: number | null;
  instrument_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    customerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3289_instrument_verdict_rollup'),
    supabase.rpc('founder_r3289_customer_scorecard'),
    supabase.rpc('founder_r3289_type_outcome_matrix'),
    supabase.rpc('founder_r3289_validity_expiry_trend'),
    supabase.rpc('founder_r3289_capa_status_board'),
    supabase.rpc('founder_r3289_root_cause_pareto'),
    supabase.rpc('founder_r3289_exposure_impact_digest'),
    supabase.rpc('founder_r3289_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const customerRows: CustomerRow[] = (customerRes.data as CustomerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'instrument_verdict', header: 'Verdict' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const customerCols: Column<CustomerRow>[] = [
    { key: 'customer_entity', header: 'Customer Entity' },
    { key: 'total_instruments', header: 'Instruments' },
    { key: 'won', header: 'Won' },
    { key: 'lost', header: 'Lost / DQ' },
    { key: 'pending', header: 'Pending' },
    { key: 'reclaim_due', header: 'Reclaim Due' },
    { key: 'forfeited', header: 'Forfeited / Invoked' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'blocked_capital_rupees', header: 'Blocked Capital (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'instrument_type', header: 'Instrument Type' },
    { key: 'tender_outcome', header: 'Tender Outcome' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'blocked_capital_rupees', header: 'Blocked Capital (INR)' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'validity_end', header: 'Validity End' },
    { key: 'instruments', header: 'Instruments' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'reclaim_due', header: 'Reclaim Due' },
    { key: 'forfeit_risk', header: 'Forfeit Risk' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'exposure_impact', header: 'Exposure Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'tender_ref', header: 'Tender Ref' },
    { key: 'customer_entity', header: 'Customer' },
    { key: 'instrument_type', header: 'Instrument' },
    { key: 'issuing_bank', header: 'Issuing Bank' },
    { key: 'amount_rupees', header: 'Amount (INR)' },
    { key: 'validity_end', header: 'Validity End' },
    { key: 'tender_outcome', header: 'Outcome' },
    { key: 'reclaim_status', header: 'Reclaim Status' },
    { key: 'days_to_expiry', header: 'Days To Expiry' },
    { key: 'instrument_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Tender EMD, Bank-Guarantee &amp; Performance-Security Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Commercial finance board for capital locked in govt &amp; hospital tenders — EMD (DD &amp;
        BG), bid-security, performance bank-guarantee, security-deposit &amp; retention-money.
        Instrument verdict &times; customer entity &times; type&times;outcome matrix &times;
        validity-expiry trend &times; reclaim / renewal / forfeit-prevention CAPA. Founder-gated
        view: capital blocked, margin money &amp; BG commission bleed, reclaim-overdue and
        forfeiture exposure across SBI, HDFC, ICICI &amp; PSU banks.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Instrument verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No tender instruments logged yet."
          rowKey={(r, i) => String(r.instrument_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-entity scorecard</h2>
        <DataTable
          rows={customerRows}
          columns={customerCols}
          emptyMessage="No customer rollups."
          rowKey={(r, i) => String(r.customer_entity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Instrument type &times; tender-outcome matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No instruments by type."
          rowKey={(r, i) => `${r.instrument_type}-${r.tender_outcome}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Validity-expiry trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No expiry trend data."
          rowKey={(r, i) => String(r.validity_end ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure / cost-risk digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.exposure_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk instrument queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk instruments."
          rowKey={(r, i) => `${r.tender_ref}-${i}`}
        />
      </section>
    </main>
  );
}
