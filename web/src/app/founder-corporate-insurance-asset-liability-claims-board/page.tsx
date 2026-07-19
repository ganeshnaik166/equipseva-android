import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { renewal_verdict: string; policies: number; pct: number };
type InsurerRow = {
  insurer: string;
  policies: number;
  total_sum_insured_rupees: number;
  total_premium_rupees: number;
  claims_filed: number;
  total_claims_amount_rupees: number;
  total_settled_rupees: number;
  claims_pending: number;
};
type MatrixRow = {
  insurance_type: string;
  coverage_adequacy: string;
  policies: number;
  total_sum_insured_rupees: number;
  total_premium_rupees: number;
};
type TrendRow = {
  policy_end: string;
  policies: number;
  total_sum_insured_rupees: number;
  total_premium_rupees: number;
  underinsured: number;
  gaps: number;
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
type RiskDigestRow = {
  risk_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  policy_name: string;
  insurance_type: string;
  insurer: string;
  coverage_adequacy: string;
  renewal_verdict: string;
  sum_insured_rupees: number;
  claims_pending: number;
  claims_amount_rupees: number;
  policy_end: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    insurerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    riskRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3325_renewal_verdict_rollup'),
    supabase.rpc('founder_r3325_insurer_scorecard'),
    supabase.rpc('founder_r3325_type_adequacy_matrix'),
    supabase.rpc('founder_r3325_renewal_expiry_trend'),
    supabase.rpc('founder_r3325_capa_status_board'),
    supabase.rpc('founder_r3325_root_cause_pareto'),
    supabase.rpc('founder_r3325_risk_impact_digest'),
    supabase.rpc('founder_r3325_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const insurerRows: InsurerRow[] = (insurerRes.data as InsurerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const riskRows: RiskDigestRow[] = (riskRes.data as RiskDigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'renewal_verdict', header: 'Renewal Verdict' },
    { key: 'policies', header: 'Policies' },
    { key: 'pct', header: 'Share %' },
  ];

  const insurerCols: Column<InsurerRow>[] = [
    { key: 'insurer', header: 'Insurer' },
    { key: 'policies', header: 'Policies' },
    { key: 'total_sum_insured_rupees', header: 'Sum Insured (INR)' },
    { key: 'total_premium_rupees', header: 'Premium (INR)' },
    { key: 'claims_filed', header: 'Claims Filed YTD' },
    { key: 'total_claims_amount_rupees', header: 'Claims Amount (INR)' },
    { key: 'total_settled_rupees', header: 'Settled (INR)' },
    { key: 'claims_pending', header: 'Claims Pending' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'insurance_type', header: 'Insurance Type' },
    { key: 'coverage_adequacy', header: 'Coverage Adequacy' },
    { key: 'policies', header: 'Policies' },
    { key: 'total_sum_insured_rupees', header: 'Sum Insured (INR)' },
    { key: 'total_premium_rupees', header: 'Premium (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'policy_end', header: 'Policy End' },
    { key: 'policies', header: 'Policies' },
    { key: 'total_sum_insured_rupees', header: 'Sum Insured (INR)' },
    { key: 'total_premium_rupees', header: 'Premium (INR)' },
    { key: 'underinsured', header: 'Underinsured' },
    { key: 'gaps', header: 'Gaps' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const riskCols: Column<RiskDigestRow>[] = [
    { key: 'risk_impact', header: 'Risk Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'policy_name', header: 'Policy' },
    { key: 'insurance_type', header: 'Type' },
    { key: 'insurer', header: 'Insurer' },
    { key: 'coverage_adequacy', header: 'Adequacy' },
    { key: 'renewal_verdict', header: 'Renewal Verdict' },
    { key: 'sum_insured_rupees', header: 'Sum Insured (INR)' },
    { key: 'claims_pending', header: 'Claims Pending' },
    { key: 'claims_amount_rupees', header: 'Claims Amount (INR)' },
    { key: 'policy_end', header: 'Policy End' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Corporate Insurance, Asset-Liability &amp; Claims Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Corporate insurance portfolio &mdash; policy &times; insurance type &times; insurer &times;
        sum insured &times; annual premium &times; coverage adequacy &times; claims filed YTD &times;
        settlement &amp; pending &times; deductible &times; broker &times; renewal verdict &amp; CAPA
        closure. Founder-gated risk view: insurer scorecards, type &times; adequacy matrix, renewal
        expiry timeline, root-cause pareto, and board / financial-materiality digest across the
        asset, liability, marine-transit, professional-indemnity, product-liability, D&amp;O and
        cyber surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Renewal verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No policies logged yet."
          rowKey={(r, i) => String(r.renewal_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Insurer scorecard</h2>
        <DataTable
          rows={insurerRows}
          columns={insurerCols}
          emptyMessage="No insurer rollups."
          rowKey={(r, i) => String(r.insurer ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Insurance type &times; coverage adequacy matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No policies by type."
          rowKey={(r, i) => `${r.insurance_type}-${r.coverage_adequacy}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal expiry timeline</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No expiry data."
          rowKey={(r, i) => String(r.policy_end ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Risk impact digest</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk-impact rollups."
          rowKey={(r, i) => String(r.risk_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk policy queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk policies."
          rowKey={(r, i) => `${r.policy_name}-${i}`}
        />
      </section>
    </main>
  );
}
