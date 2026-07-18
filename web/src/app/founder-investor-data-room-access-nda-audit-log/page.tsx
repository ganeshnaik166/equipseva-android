import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { access_verdict: string; events: number; pct: number };
type InvestorRow = {
  investor_firm: string;
  total_events: number;
  downloads: number;
  flagged: number;
  blocked: number;
  nda_signed: number;
  sensitive_views: number;
  clean_pct: number;
};
type MatrixRow = {
  document_category: string;
  access_type: string;
  events: number;
  flagged: number;
  avg_session_min: number;
};
type TrendRow = {
  access_date: string;
  events: number;
  downloads: number;
  flagged: number;
  blocked: number;
  distinct_firms: number;
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
  investor_firm: string;
  fund_stage: string;
  document_category: string;
  access_type: string;
  ip_country: string;
  access_date: string;
  nda_status: string;
  access_verdict: string;
  flagged: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    investorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3141_access_verdict_rollup'),
    supabase.rpc('founder_r3141_investor_scorecard'),
    supabase.rpc('founder_r3141_document_access_matrix'),
    supabase.rpc('founder_r3141_access_daily_trend'),
    supabase.rpc('founder_r3141_capa_status_board'),
    supabase.rpc('founder_r3141_root_cause_pareto'),
    supabase.rpc('founder_r3141_regulatory_impact_digest'),
    supabase.rpc('founder_r3141_high_risk_access'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const investorRows: InvestorRow[] = (investorRes.data as InvestorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'access_verdict', header: 'Verdict' },
    { key: 'events', header: 'Events' },
    { key: 'pct', header: 'Share %' },
  ];

  const investorCols: Column<InvestorRow>[] = [
    { key: 'investor_firm', header: 'Investor Firm' },
    { key: 'total_events', header: 'Events' },
    { key: 'downloads', header: 'Downloads' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'blocked', header: 'Blocked / Revoked' },
    { key: 'nda_signed', header: 'NDA Signed' },
    { key: 'sensitive_views', header: 'Sensitive Views' },
    { key: 'clean_pct', header: 'Clean %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'document_category', header: 'Document Category' },
    { key: 'access_type', header: 'Access Type' },
    { key: 'events', header: 'Events' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'avg_session_min', header: 'Avg Session (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'access_date', header: 'Date' },
    { key: 'events', header: 'Events' },
    { key: 'downloads', header: 'Downloads' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'blocked', header: 'Blocked / Revoked' },
    { key: 'distinct_firms', header: 'Distinct Firms' },
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
    { key: 'investor_firm', header: 'Investor Firm' },
    { key: 'fund_stage', header: 'Stage' },
    { key: 'document_category', header: 'Document' },
    { key: 'access_type', header: 'Access' },
    { key: 'ip_country', header: 'IP Geo' },
    { key: 'access_date', header: 'Date' },
    { key: 'nda_status', header: 'NDA' },
    { key: 'access_verdict', header: 'Verdict' },
    { key: 'flagged', header: 'Flagged' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Investor Data-Room Access &amp; NDA Audit Log
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Data-room access events — investor firm &times; fund stage &times; NDA status &times; document
        category &times; access type &times; IP geolocation &times; watermark &amp; flag &amp; verdict,
        with NDA/access-review CAPA closure. Founder-gated view: access verdicts, investor scorecards,
        root-cause pareto, and regulatory-impact digest across SEBI disclosure &amp; DPDP surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Access verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No access events logged yet."
          rowKey={(r, i) => String(r.access_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Investor firm scorecard</h2>
        <DataTable
          rows={investorRows}
          columns={investorCols}
          emptyMessage="No investor rollups."
          rowKey={(r, i) => String(r.investor_firm ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Document category &times; access type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No access events by document."
          rowKey={(r, i) => `${r.document_category}-${r.access_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily access trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.access_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk access queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk access events."
          rowKey={(r, i) => `${r.investor_firm}-${r.access_date}-${i}`}
        />
      </section>
    </main>
  );
}
