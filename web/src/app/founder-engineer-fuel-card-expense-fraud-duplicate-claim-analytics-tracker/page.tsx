import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { fraud_verdict: string; claims: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  total_claims: number;
  clean: number;
  anomaly_review: number;
  fraud_flagged: number;
  duplicate_suspected: number;
  out_of_policy: number;
  total_flagged_rupees: number;
  clean_pct: number;
};
type MatrixRow = {
  expense_type: string;
  region: string;
  claims: number;
  flagged: number;
  total_flagged_rupees: number;
  avg_anomaly_score: number;
};
type TrendRow = {
  claim_date: string;
  claims: number;
  clean: number;
  flagged: number;
  duplicate_suspected: number;
  total_flagged_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovered_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovered_rupees: number;
  pct: number;
};
type RecoveryRow = {
  recovery_status: string;
  findings: number;
  open_findings: number;
  total_recovered_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  claim_ref: string;
  expense_type: string;
  claim_date: string;
  fraud_verdict: string;
  claim_amount_rupees: number;
  flagged_amount_rupees: number | null;
  anomaly_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    recoveryRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3408_fraud_verdict_rollup'),
    supabase.rpc('founder_r3408_engineer_scorecard'),
    supabase.rpc('founder_r3408_expense_type_region_matrix'),
    supabase.rpc('founder_r3408_daily_claim_trend'),
    supabase.rpc('founder_r3408_capa_status_board'),
    supabase.rpc('founder_r3408_root_cause_pareto'),
    supabase.rpc('founder_r3408_recovery_impact_digest'),
    supabase.rpc('founder_r3408_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const recoveryRows: RecoveryRow[] = (recoveryRes.data as RecoveryRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'fraud_verdict', header: 'Verdict' },
    { key: 'claims', header: 'Claims' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'total_claims', header: 'Claims' },
    { key: 'clean', header: 'Clean' },
    { key: 'anomaly_review', header: 'Anomaly Review' },
    { key: 'fraud_flagged', header: 'Fraud / Dup Flagged' },
    { key: 'duplicate_suspected', header: 'Dup Suspected' },
    { key: 'out_of_policy', header: 'Out of Policy' },
    { key: 'total_flagged_rupees', header: 'Flagged (INR)' },
    { key: 'clean_pct', header: 'Clean %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'expense_type', header: 'Expense Type' },
    { key: 'region', header: 'Region' },
    { key: 'claims', header: 'Claims' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'total_flagged_rupees', header: 'Flagged (INR)' },
    { key: 'avg_anomaly_score', header: 'Avg Anomaly' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'claim_date', header: 'Date' },
    { key: 'claims', header: 'Claims' },
    { key: 'clean', header: 'Clean' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'duplicate_suspected', header: 'Dup Suspected' },
    { key: 'total_flagged_rupees', header: 'Flagged (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovered_rupees', header: 'Avg Recovered (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovered_rupees', header: 'Total Recovered (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const recoveryCols: Column<RecoveryRow>[] = [
    { key: 'recovery_status', header: 'Recovery Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovered_rupees', header: 'Total Recovered (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'claim_ref', header: 'Claim Ref' },
    { key: 'expense_type', header: 'Type' },
    { key: 'claim_date', header: 'Date' },
    { key: 'fraud_verdict', header: 'Verdict' },
    { key: 'claim_amount_rupees', header: 'Amount (INR)' },
    { key: 'flagged_amount_rupees', header: 'Flagged (INR)' },
    { key: 'anomaly_score', header: 'Anomaly' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Fuel-Card &amp; Expense Fraud / Duplicate-Claim Analytics Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer expense-integrity ledger — fraud verdict &times; engineer &times; expense type
        (fuel, travel, toll, meals, accommodation, consumables, misc) &times; region &times; GPS-route
        consistency &times; fuel-qty vs distance &times; duplicate detection &times; out-of-policy &times;
        weekend/holiday flag &times; blacklisted vendor &times; anomaly score &times; flagged amount
        &amp; CAPA recovery closure. Founder-gated view: fraud verdicts, engineer scorecards, root-cause
        pareto, and recovery-impact digest across fuel-card and reimbursement surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Fraud verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No claims logged yet."
          rowKey={(r, i) => String(r.fraud_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer fraud scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Expense type &times; region matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No claims by expense type."
          rowKey={(r, i) => `${r.expense_type}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily claim trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.claim_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Recovery impact digest</h2>
        <DataTable
          rows={recoveryRows}
          columns={recoveryCols}
          emptyMessage="No recovery-impact rollups."
          rowKey={(r, i) => String(r.recovery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk claim queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.claim_ref}-${r.claim_date}-${i}`}
        />
      </section>
    </main>
  );
}
