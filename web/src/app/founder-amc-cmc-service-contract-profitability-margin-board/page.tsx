import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  contract_verdict: string;
  contracts: number;
  total_value_rupees: number;
  total_margin_rupees: number;
  pct: number;
};
type HospRow = {
  hospital_name: string;
  contracts: number;
  total_value_rupees: number;
  total_cost_to_serve_rupees: number;
  total_margin_rupees: number;
  avg_margin_pct: number;
  loss_making: number;
  exit_candidates: number;
};
type MatrixRow = {
  contract_type: string;
  equipment_scope: string;
  contracts: number;
  total_value_rupees: number;
  avg_margin_pct: number;
  loss_making: number;
};
type TrendRow = {
  renewal_due_date: string;
  contracts: number;
  total_value_rupees: number;
  total_margin_rupees: number;
  loss_making: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_projected_gain_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_projected_gain_rupees: number;
  pct: number;
};
type RiskTierRow = {
  margin_risk_tier: string;
  findings: number;
  open_findings: number;
  total_projected_gain_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  contract_code: string;
  contract_type: string;
  equipment_scope: string;
  contract_value_rupees: number;
  cost_to_serve_rupees: number;
  margin_pct: number;
  sla_penalty_paid_rupees: number;
  renewal_due_date: string | null;
  contract_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskTierRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3317_contract_verdict_rollup'),
    supabase.rpc('founder_r3317_hospital_scorecard'),
    supabase.rpc('founder_r3317_type_scope_matrix'),
    supabase.rpc('founder_r3317_renewal_due_trend'),
    supabase.rpc('founder_r3317_capa_status_board'),
    supabase.rpc('founder_r3317_root_cause_pareto'),
    supabase.rpc('founder_r3317_margin_risk_digest'),
    supabase.rpc('founder_r3317_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskTierRows: RiskTierRow[] = (riskTierRes.data as RiskTierRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'contract_verdict', header: 'Verdict' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_value_rupees', header: 'Total Value (INR)' },
    { key: 'total_margin_rupees', header: 'Total Margin (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_value_rupees', header: 'Total Value (INR)' },
    { key: 'total_cost_to_serve_rupees', header: 'Cost To Serve (INR)' },
    { key: 'total_margin_rupees', header: 'Total Margin (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'loss_making', header: 'Loss-Making' },
    { key: 'exit_candidates', header: 'Exit Candidates' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'contract_type', header: 'Contract Type' },
    { key: 'equipment_scope', header: 'Equipment Scope' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_value_rupees', header: 'Total Value (INR)' },
    { key: 'avg_margin_pct', header: 'Avg Margin %' },
    { key: 'loss_making', header: 'Loss / Exit' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'renewal_due_date', header: 'Renewal Due' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_value_rupees', header: 'Total Value (INR)' },
    { key: 'total_margin_rupees', header: 'Total Margin (INR)' },
    { key: 'loss_making', header: 'Loss / Exit' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_projected_gain_rupees', header: 'Avg Projected Gain (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_projected_gain_rupees', header: 'Total Projected Gain (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskTierCols: Column<RiskTierRow>[] = [
    { key: 'margin_risk_tier', header: 'Margin Risk Tier' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_projected_gain_rupees', header: 'Total Projected Gain (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'contract_code', header: 'Contract' },
    { key: 'contract_type', header: 'Type' },
    { key: 'equipment_scope', header: 'Scope' },
    { key: 'contract_value_rupees', header: 'Value (INR)' },
    { key: 'cost_to_serve_rupees', header: 'Cost To Serve (INR)' },
    { key: 'margin_pct', header: 'Margin %' },
    { key: 'sla_penalty_paid_rupees', header: 'SLA Penalty (INR)' },
    { key: 'renewal_due_date', header: 'Renewal Due' },
    { key: 'contract_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        AMC/CMC Service-Contract Profitability &amp; Margin Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder finance board — contract type &times; equipment scope &times; contract value &times;
        cost-to-serve (parts, labour, travel) &times; gross margin &times; margin % &times; SLA
        penalty leakage &times; renewal-due horizon &amp; CAPA repricing/rescoping actions. Each
        annual/comprehensive maintenance contract is tracked from value to cost-to-serve so margin
        is known before renewals are priced; loss-making &amp; over-serviced contracts surface for
        renegotiation or exit.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Contract verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No contracts logged yet."
          rowKey={(r, i) => String(r.contract_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital margin scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Contract type &times; equipment scope matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No contracts by type."
          rowKey={(r, i) => `${r.contract_type}-${r.equipment_scope}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal-due trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No renewal-due data."
          rowKey={(r, i) => String(r.renewal_due_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-risk digest</h2>
        <DataTable
          rows={riskTierRows}
          columns={riskTierCols}
          emptyMessage="No margin-risk rollups."
          rowKey={(r, i) => String(r.margin_risk_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk contract queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r, i) => `${r.contract_code}-${i}`}
        />
      </section>
    </main>
  );
}
