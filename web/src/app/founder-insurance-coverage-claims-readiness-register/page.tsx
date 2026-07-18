import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; policies: number; pct: number };
type EntityRow = {
  hospital_name: string;
  total_policies: number;
  claims_ready: number;
  high_exposure: number;
  non_compliant: number;
  gaps: number;
  total_claims_filed: number;
  avg_readiness: number;
  total_sum_insured: number;
};
type TypeRow = {
  policy_type: string;
  coverage_gap_flag: string;
  policies: number;
  total_sum_insured: number;
  avg_readiness: number;
};
type TrendRow = {
  renewal_date: string;
  renewals: number;
  total_premium: number;
  avg_readiness: number;
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
  hospital_name: string;
  policy_type: string;
  insurer_name: string;
  renewal_date: string;
  coverage_gap_flag: string;
  claim_status: string;
  readiness_score: number;
  readiness_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    entityRes,
    typeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3161_readiness_verdict_rollup'),
    supabase.rpc('founder_r3161_entity_scorecard'),
    supabase.rpc('founder_r3161_policy_type_matrix'),
    supabase.rpc('founder_r3161_renewal_trend'),
    supabase.rpc('founder_r3161_capa_status_board'),
    supabase.rpc('founder_r3161_root_cause_pareto'),
    supabase.rpc('founder_r3161_regulatory_impact_digest'),
    supabase.rpc('founder_r3161_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const entityRows: EntityRow[] = (entityRes.data as EntityRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Readiness Verdict' },
    { key: 'policies', header: 'Policies' },
    { key: 'pct', header: 'Share %' },
  ];

  const entityCols: Column<EntityRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_policies', header: 'Policies' },
    { key: 'claims_ready', header: 'Claims-Ready' },
    { key: 'high_exposure', header: 'High Exposure' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'gaps', header: 'Coverage Gaps' },
    { key: 'total_claims_filed', header: 'Claims Filed' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
    { key: 'total_sum_insured', header: 'Total SI (INR)' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'policy_type', header: 'Policy Type' },
    { key: 'coverage_gap_flag', header: 'Coverage Gap' },
    { key: 'policies', header: 'Policies' },
    { key: 'total_sum_insured', header: 'Total SI (INR)' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'renewal_date', header: 'Renewal Date' },
    { key: 'renewals', header: 'Renewals' },
    { key: 'total_premium', header: 'Total Premium (INR)' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
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
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'policy_type', header: 'Policy Type' },
    { key: 'insurer_name', header: 'Insurer' },
    { key: 'renewal_date', header: 'Renewal' },
    { key: 'coverage_gap_flag', header: 'Coverage Gap' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'readiness_score', header: 'Readiness' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Insurance-Coverage &amp; Claims-Readiness Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Policy register — policy type &times; insurer &times; sum insured &times; premium &times; renewal
        &times; coverage gap &times; claims &amp; readiness score with CAPA closure. Founder-gated view:
        readiness verdicts, entity scorecards, root-cause pareto, and regulatory-impact digest across
        NABH &amp; IRDAI surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No policies registered yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Entity readiness scorecard</h2>
        <DataTable
          rows={entityRows}
          columns={entityCols}
          emptyMessage="No entity rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Policy type &times; coverage gap matrix</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No policies by type."
          rowKey={(r, i) => `${r.policy_type}-${r.coverage_gap_flag}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Renewal timeline trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No renewal data."
          rowKey={(r, i) => String(r.renewal_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk &amp; priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk policies."
          rowKey={(r, i) => `${r.hospital_name}-${r.policy_type}-${i}`}
        />
      </section>
    </main>
  );
}
