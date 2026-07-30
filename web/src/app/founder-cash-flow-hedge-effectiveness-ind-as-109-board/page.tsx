import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  effectiveness_status: string;
  relationships: number;
  total_notional_rupees: number;
  pct: number;
};
type TypeRow = {
  hedge_type: string;
  relationships: number;
  highly_effective: number;
  effective: number;
  ineffective: number;
  total_notional_rupees: number;
  avg_effectiveness_pct: number;
  total_oci_reserve_rupees: number;
};
type MatrixRow = {
  hedge_type: string;
  effectiveness_status: string;
  relationships: number;
  total_notional_rupees: number;
  total_ineffective_rupees: number;
  avg_effectiveness_pct: number;
};
type TrendRow = {
  period_month: string;
  relationships: number;
  avg_effectiveness_pct: number;
  total_effective_rupees: number;
  total_ineffective_rupees: number;
  total_oci_reserve_rupees: number;
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
  effectiveness_status: string;
  relationships: number;
  total_notional_rupees: number;
  total_effective_rupees: number;
  total_ineffective_rupees: number;
  total_oci_reserve_rupees: number;
};
type RiskRow = {
  hedge_relationship: string;
  hedged_item: string;
  hedge_type: string;
  period_month: string;
  notional_rupees: number;
  effectiveness_pct: number;
  ineffective_portion_rupees: number;
  effectiveness_status: string;
  trend_dir: string;
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
    supabase.rpc('founder_r3632_effectiveness_status_rollup'),
    supabase.rpc('founder_r3632_hedge_type_scorecard'),
    supabase.rpc('founder_r3632_hedge_type_status_matrix'),
    supabase.rpc('founder_r3632_monthly_effectiveness_trend'),
    supabase.rpc('founder_r3632_capa_status_board'),
    supabase.rpc('founder_r3632_root_cause_pareto'),
    supabase.rpc('founder_r3632_ineffectiveness_digest'),
    supabase.rpc('founder_r3632_high_risk_queue'),
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
    { key: 'effectiveness_status', header: 'Effectiveness Status' },
    { key: 'relationships', header: 'Relationships' },
    { key: 'total_notional_rupees', header: 'Total Notional (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'hedge_type', header: 'Hedge Type' },
    { key: 'relationships', header: 'Relationships' },
    { key: 'highly_effective', header: 'Highly Effective' },
    { key: 'effective', header: 'Effective' },
    { key: 'ineffective', header: 'Ineffective / De-desig' },
    { key: 'total_notional_rupees', header: 'Total Notional (INR)' },
    { key: 'avg_effectiveness_pct', header: 'Avg Effectiveness %' },
    { key: 'total_oci_reserve_rupees', header: 'OCI Reserve (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'hedge_type', header: 'Hedge Type' },
    { key: 'effectiveness_status', header: 'Effectiveness Status' },
    { key: 'relationships', header: 'Relationships' },
    { key: 'total_notional_rupees', header: 'Total Notional (INR)' },
    { key: 'total_ineffective_rupees', header: 'Ineffective Portion (INR)' },
    { key: 'avg_effectiveness_pct', header: 'Avg Effectiveness %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period Month' },
    { key: 'relationships', header: 'Relationships' },
    { key: 'avg_effectiveness_pct', header: 'Avg Effectiveness %' },
    { key: 'total_effective_rupees', header: 'Effective Portion (INR)' },
    { key: 'total_ineffective_rupees', header: 'Ineffective Portion (INR)' },
    { key: 'total_oci_reserve_rupees', header: 'OCI Reserve (INR)' },
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
    { key: 'effectiveness_status', header: 'Effectiveness Status' },
    { key: 'relationships', header: 'Relationships' },
    { key: 'total_notional_rupees', header: 'Total Notional (INR)' },
    { key: 'total_effective_rupees', header: 'Effective Portion (INR)' },
    { key: 'total_ineffective_rupees', header: 'Ineffective Portion (INR)' },
    { key: 'total_oci_reserve_rupees', header: 'OCI Reserve (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hedge_relationship', header: 'Relationship' },
    { key: 'hedged_item', header: 'Hedged Item' },
    { key: 'hedge_type', header: 'Type' },
    { key: 'period_month', header: 'Period' },
    { key: 'notional_rupees', header: 'Notional (INR)' },
    { key: 'effectiveness_pct', header: 'Effectiveness %' },
    { key: 'ineffective_portion_rupees', header: 'Ineffective (INR)' },
    { key: 'effectiveness_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cash-Flow Hedge Effectiveness (Ind-AS 109) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Ind-AS 109 cash-flow hedge effectiveness ledger &mdash; hedge relationship &times; hedged item
        &times; hedge type (forwards, options, swaps, forward covers &amp; natural hedges) &times; hedge
        ratio &times; MTM gain/loss &times; effective portion &times; ineffective portion &times; OCI
        reserve &times; effectiveness % across USD &amp; EUR import payables, project-loan interest and
        service-export receivables. Founder-gated view: effectiveness-status distribution, hedge-type
        scorecards, ineffectiveness digest, root-cause pareto and the high-risk (ineffective /
        de-designated) remediation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Effectiveness-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No hedge relationships logged yet."
          rowKey={(r, i) => String(r.effectiveness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hedge-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No hedge-type rollups."
          rowKey={(r, i) => String(r.hedge_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Hedge type &times; effectiveness-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No relationships by hedge type."
          rowKey={(r, i) => `${r.hedge_type}-${r.effectiveness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly effectiveness trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Ineffectiveness digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No ineffectiveness digest."
          rowKey={(r, i) => String(r.effectiveness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk hedge queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk relationships."
          rowKey={(r, i) => `${r.hedge_relationship}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
