import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { authorization_status: string; partners: number; pct: number };
type TypeRow = {
  partner_type: string;
  total_partners: number;
  authorized: number;
  renewal_due: number;
  suspended: number;
  cold_chain_partners: number;
  avg_audit_score: number;
  avg_training_pct: number;
  authorized_pct: number;
};
type MatrixRow = {
  partner_type: string;
  authorization_status: string;
  partners: number;
  avg_days_to_expiry: number;
  avg_audit_score: number;
};
type TrendRow = {
  period_month: string;
  partners: number;
  authorized: number;
  renewal_due: number;
  suspended: number;
  avg_audit_score: number;
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
type ExpiryRow = {
  expiry_bucket: string;
  partners: number;
  cold_chain_partners: number;
  avg_days_to_expiry: number;
  min_days_to_expiry: number;
};
type RiskRow = {
  partner_name: string;
  partner_code: string;
  partner_type: string;
  territory: string;
  period_month: string;
  authorization_status: string;
  wholesale_licence_no: string;
  licence_expiry: string | null;
  days_to_expiry: number | null;
  audit_score: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    expiryRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3649_authorization_status_rollup'),
    supabase.rpc('founder_r3649_partner_type_scorecard'),
    supabase.rpc('founder_r3649_partner_type_status_matrix'),
    supabase.rpc('founder_r3649_monthly_authorization_trend'),
    supabase.rpc('founder_r3649_capa_status_board'),
    supabase.rpc('founder_r3649_root_cause_pareto'),
    supabase.rpc('founder_r3649_expiry_exposure_digest'),
    supabase.rpc('founder_r3649_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const expiryRows: ExpiryRow[] = (expiryRes.data as ExpiryRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'authorization_status', header: 'Authorization Status' },
    { key: 'partners', header: 'Partners' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'partner_type', header: 'Partner Type' },
    { key: 'total_partners', header: 'Partners' },
    { key: 'authorized', header: 'Authorized' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'suspended', header: 'Suspended / Delisted' },
    { key: 'cold_chain_partners', header: 'Cold-Chain Capable' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
    { key: 'avg_training_pct', header: 'Avg Training %' },
    { key: 'authorized_pct', header: 'Authorized %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'partner_type', header: 'Partner Type' },
    { key: 'authorization_status', header: 'Authorization Status' },
    { key: 'partners', header: 'Partners' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'partners', header: 'Partners' },
    { key: 'authorized', header: 'Authorized' },
    { key: 'renewal_due', header: 'Renewal Due' },
    { key: 'suspended', header: 'Suspended / Delisted' },
    { key: 'avg_audit_score', header: 'Avg Audit Score' },
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

  const expiryCols: Column<ExpiryRow>[] = [
    { key: 'expiry_bucket', header: 'Expiry Bucket' },
    { key: 'partners', header: 'Partners' },
    { key: 'cold_chain_partners', header: 'Cold-Chain Capable' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'min_days_to_expiry', header: 'Min Days to Expiry' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'partner_name', header: 'Partner' },
    { key: 'partner_code', header: 'Code' },
    { key: 'partner_type', header: 'Type' },
    { key: 'territory', header: 'Territory' },
    { key: 'period_month', header: 'Month' },
    { key: 'authorization_status', header: 'Status' },
    { key: 'wholesale_licence_no', header: 'Licence No' },
    { key: 'licence_expiry', header: 'Expiry' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'audit_score', header: 'Audit Score' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Distributor / Importer Regulatory-Authorization Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Distributor &amp; importer regulatory-authorization register &mdash; Form MD-42 wholesale
        licence status per partner (distributors, importers, C&amp;F agents, stockists, e-pharmacies)
        &times; territory &times; licence expiry &times; cold-chain capability &times; complaints routed
        &times; training completion &times; audit score &times; authorization status &amp; trend, with
        CAPA closure. Founder-gated view: authorization distribution, partner-type scorecards,
        expiry-exposure digest, root-cause pareto, and a high-risk queue across CDSCO &amp; state
        licensing surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Authorization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No partner authorizations logged yet."
          rowKey={(r, i) => String(r.authorization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Partner-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No partner-type rollups."
          rowKey={(r, i) => String(r.partner_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Partner type &times; authorization status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No partners by type."
          rowKey={(r, i) => `${r.partner_type}-${r.authorization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly authorization trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Expiry-exposure digest</h2>
        <DataTable
          rows={expiryRows}
          columns={expiryCols}
          emptyMessage="No expiry-exposure data."
          rowKey={(r, i) => String(r.expiry_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk authorization queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk partners."
          rowKey={(r, i) => `${r.partner_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
