import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  readiness_verdict: string;
  licenses: number;
  total_penalty_exposure_rupees: number;
  pct: number;
};
type SiteRow = {
  site_name: string;
  total_licenses: number;
  valid_licenses: number;
  renewal_due: number;
  expired_or_showcause: number;
  open_observations: number;
  total_penalty_exposure_rupees: number;
  avg_days_to_expiry: number;
};
type MatrixRow = {
  regulatory_body: string;
  license_type: string;
  licenses: number;
  compliant: number;
  avg_days_to_expiry: number;
  total_penalty_exposure_rupees: number;
};
type TrendRow = {
  expiry_date: string;
  licenses: number;
  renewal_due: number;
  expired_or_showcause: number;
  total_penalty_exposure_rupees: number;
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
type DigestRow = {
  regulatory_body: string;
  licenses: number;
  open_observations: number;
  critical_gaps: number;
  total_penalty_exposure_rupees: number;
};
type RiskRow = {
  site_name: string;
  regulatory_body: string;
  license_type: string;
  reference_no: string;
  expiry_date: string;
  days_to_expiry: number;
  renewal_status: string;
  readiness_verdict: string;
  penalty_exposure_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3349_readiness_verdict_rollup'),
    supabase.rpc('founder_r3349_site_scorecard'),
    supabase.rpc('founder_r3349_body_license_matrix'),
    supabase.rpc('founder_r3349_expiry_trend'),
    supabase.rpc('founder_r3349_capa_status_board'),
    supabase.rpc('founder_r3349_root_cause_pareto'),
    supabase.rpc('founder_r3349_regulatory_body_risk_digest'),
    supabase.rpc('founder_r3349_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Readiness Verdict' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'total_penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'total_licenses', header: 'Licenses' },
    { key: 'valid_licenses', header: 'Valid' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'expired_or_showcause', header: 'Expired / Show-Cause' },
    { key: 'open_observations', header: 'Open Obs' },
    { key: 'total_penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'regulatory_body', header: 'Regulatory Body' },
    { key: 'license_type', header: 'License Type' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_days_to_expiry', header: 'Avg Days To Expiry' },
    { key: 'total_penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'expiry_date', header: 'Expiry Date' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'expired_or_showcause', header: 'Expired / Show-Cause' },
    { key: 'total_penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'regulatory_body', header: 'Regulatory Body' },
    { key: 'licenses', header: 'Licenses' },
    { key: 'open_observations', header: 'Open Obs' },
    { key: 'critical_gaps', header: 'Critical / Prep Gaps' },
    { key: 'total_penalty_exposure_rupees', header: 'Penalty Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'regulatory_body', header: 'Body' },
    { key: 'license_type', header: 'License Type' },
    { key: 'reference_no', header: 'Reference No' },
    { key: 'expiry_date', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days To Expiry' },
    { key: 'renewal_status', header: 'Renewal Status' },
    { key: 'readiness_verdict', header: 'Readiness' },
    { key: 'penalty_exposure_rupees', header: 'Penalty (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder CDSCO / AERB Regulatory-License &amp; Inspection-Readiness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Statutory register for EquipSeva as a MedTech service provider &mdash; regulatory body
        &times; license type &times; renewal status &times; inspection outcome &times; open
        observations &times; penalty exposure &times; readiness verdict &amp; CAPA closure.
        Founder-gated view across CDSCO, AERB, legal-metrology, state drug authority, BIS &amp;
        CPCB obligations: readiness verdicts, site scorecards, renewal-calendar trend, root-cause
        pareto and regulatory-body risk digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No licenses logged yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site readiness scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Regulatory body &times; license type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No licenses by body."
          rowKey={(r, i) => `${r.regulatory_body}-${r.license_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Expiry renewal-calendar trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.expiry_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory-body risk digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No regulatory-body rollups."
          rowKey={(r, i) => String(r.regulatory_body ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk license queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk licenses."
          rowKey={(r, i) => `${r.reference_no}-${i}`}
        />
      </section>
    </main>
  );
}
