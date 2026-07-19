import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  partner_verdict: string;
  partners: number;
  total_revenue_rupees: number;
  pct: number;
};
type TerritoryRow = {
  territory: string;
  total_partners: number;
  activated: number;
  underperforming: number;
  kyc_ok: number;
  cert_current: number;
  total_revenue_rupees: number;
  avg_sla_adherence_pct: number;
};
type MatrixRow = {
  partner_type: string;
  onboarding_stage: string;
  partners: number;
  total_revenue_rupees: number;
  avg_engineers_trained: number;
};
type TrendRow = {
  onboarding_start_date: string;
  partners: number;
  activated: number;
  avg_sla_adherence_pct: number;
  total_revenue_rupees: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  partner_firm: string;
  partner_code: string;
  territory: string;
  partner_type: string;
  onboarding_stage: string;
  agreement_status: string;
  kyc_compliance: string;
  certification_status: string;
  sla_adherence_pct: number | null;
  escalations_open: number;
  partner_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    territoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3377_partner_verdict_rollup'),
    supabase.rpc('founder_r3377_territory_scorecard'),
    supabase.rpc('founder_r3377_type_stage_matrix'),
    supabase.rpc('founder_r3377_onboarding_trend'),
    supabase.rpc('founder_r3377_capa_status_board'),
    supabase.rpc('founder_r3377_root_cause_pareto'),
    supabase.rpc('founder_r3377_regulatory_impact_digest'),
    supabase.rpc('founder_r3377_high_risk_partners'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const territoryRows: TerritoryRow[] = (territoryRes.data as TerritoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'partner_verdict', header: 'Verdict' },
    { key: 'partners', header: 'Partners' },
    { key: 'total_revenue_rupees', header: 'YTD Revenue (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const territoryCols: Column<TerritoryRow>[] = [
    { key: 'territory', header: 'Territory' },
    { key: 'total_partners', header: 'Partners' },
    { key: 'activated', header: 'Activated' },
    { key: 'underperforming', header: 'Under / Off' },
    { key: 'kyc_ok', header: 'KYC OK' },
    { key: 'cert_current', header: 'Cert Current' },
    { key: 'total_revenue_rupees', header: 'YTD Revenue (INR)' },
    { key: 'avg_sla_adherence_pct', header: 'Avg SLA %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'partner_type', header: 'Partner Type' },
    { key: 'onboarding_stage', header: 'Onboarding Stage' },
    { key: 'partners', header: 'Partners' },
    { key: 'total_revenue_rupees', header: 'YTD Revenue (INR)' },
    { key: 'avg_engineers_trained', header: 'Avg Engineers Trained' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'onboarding_start_date', header: 'Onboarding Start' },
    { key: 'partners', header: 'Partners' },
    { key: 'activated', header: 'Activated' },
    { key: 'avg_sla_adherence_pct', header: 'Avg SLA %' },
    { key: 'total_revenue_rupees', header: 'YTD Revenue (INR)' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'partner_firm', header: 'Partner Firm' },
    { key: 'partner_code', header: 'Code' },
    { key: 'territory', header: 'Territory' },
    { key: 'partner_type', header: 'Type' },
    { key: 'onboarding_stage', header: 'Stage' },
    { key: 'agreement_status', header: 'Agreement' },
    { key: 'kyc_compliance', header: 'KYC' },
    { key: 'certification_status', header: 'Certification' },
    { key: 'sla_adherence_pct', header: 'SLA %' },
    { key: 'escalations_open', header: 'Escalations' },
    { key: 'partner_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Distributor &amp; Channel-Partner Onboarding &amp; Certification Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder growth view of resellers, service partners &amp; regional distributors in territories
        EquipSeva does not cover directly &mdash; partner firm &times; territory &times; partner type
        &times; onboarding stage &times; agreement status &times; KYC compliance &times; engineers
        trained &times; certification currency &times; credit terms &times; YTD revenue &times; SLA
        adherence &times; escalations &amp; CAPA closure. Founder-gated: verdict rollups, territory
        scorecards, root-cause pareto and compliance-impact digest across dealer-agreement, GST &amp;
        DPDP surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Partner verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No partners onboarded yet."
          rowKey={(r, i) => String(r.partner_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Territory scorecard</h2>
        <DataTable
          rows={territoryRows}
          columns={territoryCols}
          emptyMessage="No territory rollups."
          rowKey={(r, i) => String(r.territory ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Partner type &times; onboarding stage matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No partners by type."
          rowKey={(r, i) => `${r.partner_type}-${r.onboarding_stage}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Onboarding-start trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.onboarding_start_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk partner queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk partners."
          rowKey={(r, i) => `${r.partner_code}-${i}`}
        />
      </section>
    </main>
  );
}
