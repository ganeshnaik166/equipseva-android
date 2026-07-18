import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; vendors: number; pct: number };
type ScorecardRow = {
  vendor_name: string;
  hospital_name: string;
  category: string;
  vendor_tier: string;
  records: number;
  avg_otif_pct: number;
  avg_sla_gap_days: number;
  avg_quality_reject_pct: number;
  compliant_pct: number;
};
type CategoryRow = {
  category: string;
  vendors: number;
  avg_otif_pct: number;
  avg_quality_reject_pct: number;
  breaches: number;
  avg_payment_terms_days: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  avg_otif_pct: number;
  breaches: number;
  disputes: number;
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
  vendor_name: string;
  hospital_name: string;
  category: string;
  vendor_tier: string;
  compliance_verdict: string;
  otif_pct: number;
  actual_lead_days: number;
  sla_target_days: number;
  dispute_status: string;
  payment_terms_status: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3157_verdict_rollup'),
    supabase.rpc('founder_r3157_vendor_scorecard'),
    supabase.rpc('founder_r3157_category_matrix'),
    supabase.rpc('founder_r3157_sla_monthly_trend'),
    supabase.rpc('founder_r3157_capa_status_board'),
    supabase.rpc('founder_r3157_root_cause_pareto'),
    supabase.rpc('founder_r3157_regulatory_impact_digest'),
    supabase.rpc('founder_r3157_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'hospital_name', header: 'Entity' },
    { key: 'category', header: 'Category' },
    { key: 'vendor_tier', header: 'Tier' },
    { key: 'records', header: 'Records' },
    { key: 'avg_otif_pct', header: 'Avg OTIF %' },
    { key: 'avg_sla_gap_days', header: 'Avg SLA Gap (d)' },
    { key: 'avg_quality_reject_pct', header: 'Avg Reject %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'avg_otif_pct', header: 'Avg OTIF %' },
    { key: 'avg_quality_reject_pct', header: 'Avg Reject %' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'avg_payment_terms_days', header: 'Avg Terms (d)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'avg_otif_pct', header: 'Avg OTIF %' },
    { key: 'breaches', header: 'Breaches' },
    { key: 'disputes', header: 'Disputes' },
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
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'hospital_name', header: 'Entity' },
    { key: 'category', header: 'Category' },
    { key: 'vendor_tier', header: 'Tier' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'otif_pct', header: 'OTIF %' },
    { key: 'actual_lead_days', header: 'Actual (d)' },
    { key: 'sla_target_days', header: 'SLA (d)' },
    { key: 'dispute_status', header: 'Dispute' },
    { key: 'payment_terms_status', header: 'Payment' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor / Supplier SLA &amp; Payment-Terms Compliance Scorecard
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Supplier performance log — category &times; SLA target vs actual lead &times; OTIF % &times;
        quality-reject % &times; payment terms &times; dispute status &times; vendor tier &amp; CAPA closure.
        Founder-gated view: compliance verdicts, vendor scorecards, root-cause pareto, and
        regulatory-impact digest across procurement &amp; NABH supply surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No vendor records yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vendor / entity scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No vendor scorecards."
          rowKey={(r, i) => `${r.vendor_name}-${r.hospital_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category data."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. SLA monthly trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk vendor queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk vendors."
          rowKey={(r, i) => `${r.vendor_name}-${r.hospital_name}-${i}`}
        />
      </section>
    </main>
  );
}
