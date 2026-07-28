import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { utilization_status: string; contracts: number; pct: number };
type TypeRow = {
  contract_type: string;
  contracts: number;
  total_entitled: number;
  total_consumed: number;
  total_remaining: number;
  avg_utilization_pct: number;
  over_consumed: number;
  exhausted: number;
};
type MatrixRow = {
  contract_type: string;
  utilization_status: string;
  contracts: number;
  avg_utilization_pct: number;
  total_breakdown_visits: number;
};
type TrendRow = {
  period_month: string;
  contracts: number;
  total_consumed: number;
  total_pm: number;
  total_breakdown: number;
  avg_utilization_pct: number;
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
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  customer_name: string;
  contract_code: string;
  device_model: string;
  contract_type: string;
  period_month: string;
  utilization_status: string;
  visits_entitled: number;
  visits_consumed: number;
  visits_remaining: number;
  utilization_pct: number | null;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3576_utilization_status_rollup'),
    supabase.rpc('founder_r3576_contract_type_scorecard'),
    supabase.rpc('founder_r3576_contract_type_status_matrix'),
    supabase.rpc('founder_r3576_monthly_visit_trend'),
    supabase.rpc('founder_r3576_capa_status_board'),
    supabase.rpc('founder_r3576_root_cause_pareto'),
    supabase.rpc('founder_r3576_entitlement_impact_digest'),
    supabase.rpc('founder_r3576_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'utilization_status', header: 'Utilization Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'contract_type', header: 'Contract Type' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_entitled', header: 'Entitled' },
    { key: 'total_consumed', header: 'Consumed' },
    { key: 'total_remaining', header: 'Remaining' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
    { key: 'over_consumed', header: 'Over-Consumed' },
    { key: 'exhausted', header: 'Exhausted' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'contract_type', header: 'Contract Type' },
    { key: 'utilization_status', header: 'Utilization Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
    { key: 'total_breakdown_visits', header: 'Breakdown Visits' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_consumed', header: 'Visits Consumed' },
    { key: 'total_pm', header: 'PM Visits' },
    { key: 'total_breakdown', header: 'Breakdown Visits' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
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
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'contract_code', header: 'Contract' },
    { key: 'device_model', header: 'Device' },
    { key: 'contract_type', header: 'Type' },
    { key: 'period_month', header: 'Period' },
    { key: 'utilization_status', header: 'Status' },
    { key: 'visits_entitled', header: 'Entitled' },
    { key: 'visits_consumed', header: 'Consumed' },
    { key: 'visits_remaining', header: 'Remaining' },
    { key: 'utilization_pct', header: 'Utilization %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Service-Contract Visits-Consumed-vs-Entitled Utilization Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        AMC/CMC/comprehensive service-contract entitlement tracking — PM &amp; breakdown visits
        consumed vs entitled across contract type &times; utilization status &times; monthly trend
        &times; months-elapsed pace. Flags under-utilized, over-consumed, exhausted &amp; breach-risk
        contracts where consumption outruns entitlement. Founder-gated view: utilization
        distribution, contract-type scorecards, root-cause pareto, and entitlement-impact digest with
        CAPA closure across renewal &amp; excess-billing recovery surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Utilization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No contract utilization logged yet."
          rowKey={(r, i) => String(r.utilization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Contract-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No contract-type rollups."
          rowKey={(r, i) => String(r.contract_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Contract type &times; utilization status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No contracts by type."
          rowKey={(r, i) => `${r.contract_type}-${r.utilization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly visit trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Entitlement-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No entitlement-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk contract queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r, i) => `${r.contract_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
