import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  realization_status: string;
  claims: number;
  pending_rupees: number;
  pct: number;
};
type UnitRow = {
  business_unit: string;
  total_claims: number;
  realized: number;
  on_track: number;
  at_risk: number;
  eligible_rupees: number;
  realized_rupees: number;
  pending_rupees: number;
  realization_pct: number;
};
type MatrixRow = {
  scheme_type: string;
  realization_status: string;
  claims: number;
  eligible_rupees: number;
  realized_rupees: number;
  pending_rupees: number;
};
type TrendRow = {
  period_month: string;
  claims: number;
  eligible_rupees: number;
  claimed_rupees: number;
  realized_rupees: number;
  pending_rupees: number;
  realization_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  scheme_type: string;
  claims: number;
  pending_rupees: number;
  eligible_rupees: number;
  avg_aging_days: number;
};
type RiskRow = {
  claim_ref: string;
  scheme_name: string;
  business_unit: string;
  scheme_type: string;
  period_month: string;
  realization_status: string;
  export_value_rupees: number | null;
  eligible_incentive_rupees: number | null;
  pending_rupees: number | null;
  aging_days: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3625_realization_status_rollup'),
    supabase.rpc('founder_r3625_business_unit_scorecard'),
    supabase.rpc('founder_r3625_scheme_status_matrix'),
    supabase.rpc('founder_r3625_monthly_realization_trend'),
    supabase.rpc('founder_r3625_capa_status_board'),
    supabase.rpc('founder_r3625_root_cause_pareto'),
    supabase.rpc('founder_r3625_pending_incentive_digest'),
    supabase.rpc('founder_r3625_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_claims', header: 'Claims' },
    { key: 'realized', header: 'Realized' },
    { key: 'on_track', header: 'On Track' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'eligible_rupees', header: 'Eligible (INR)' },
    { key: 'realized_rupees', header: 'Realized (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'realization_pct', header: 'Realization %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scheme_type', header: 'Scheme Type' },
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'eligible_rupees', header: 'Eligible (INR)' },
    { key: 'realized_rupees', header: 'Realized (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'claims', header: 'Claims' },
    { key: 'eligible_rupees', header: 'Eligible (INR)' },
    { key: 'claimed_rupees', header: 'Claimed (INR)' },
    { key: 'realized_rupees', header: 'Realized (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'realization_pct', header: 'Realization %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'scheme_type', header: 'Scheme Type' },
    { key: 'claims', header: 'Claims' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'eligible_rupees', header: 'Eligible (INR)' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'claim_ref', header: 'Claim Ref' },
    { key: 'scheme_name', header: 'Scheme' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'scheme_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'realization_status', header: 'Status' },
    { key: 'export_value_rupees', header: 'Export Value (INR)' },
    { key: 'eligible_incentive_rupees', header: 'Eligible (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Export-Incentive / Duty-Drawback / RODTEP Realization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder export-incentive finance view — eligibility-vs-realization per scheme (duty drawback,
        RODTEP, EPCG, advance authorization, MEIS/SEIS) &times; business unit &times; export value
        &times; eligible &amp; claimed &amp; realized &amp; pending incentive &times; realization %
        &times; aging &times; realization status &amp; CAPA recovery. Founder-gated: status
        distribution, business-unit scorecards, scheme &times; status matrix, monthly realization
        trend, root-cause pareto, pending-incentive digest, and the high-risk (stuck &amp;
        lapsed-risk) recovery queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Realization-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No export-incentive claims logged yet."
          rowKey={(r, i) => String(r.realization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scheme type &times; realization-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No claims by scheme type."
          rowKey={(r, i) => `${r.scheme_type}-${r.realization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly realization trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Pending-incentive digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No pending-incentive rollups."
          rowKey={(r, i) => String(r.scheme_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk realization queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.claim_ref}-${i}`}
        />
      </section>
    </main>
  );
}
