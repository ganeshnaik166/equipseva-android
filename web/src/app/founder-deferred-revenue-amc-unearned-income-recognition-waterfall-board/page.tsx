import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  recognition_status: string;
  contracts: number;
  deferred_balance_rupees: number;
  pct: number;
};
type SegRow = {
  customer_segment: string;
  contracts: number;
  total_contract_value_rupees: number;
  recognized_to_date_rupees: number;
  deferred_balance_rupees: number;
  avg_recognition_pct: number;
  behind_or_stalled: number;
  recognition_health_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  recognition_status: string;
  contracts: number;
  deferred_balance_rupees: number;
  avg_recognition_pct: number;
};
type TrendRow = {
  period_month: string;
  contracts: number;
  monthly_recognition_rupees: number;
  recognized_to_date_rupees: number;
  deferred_balance_rupees: number;
  avg_recognition_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  revenue_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  revenue_at_risk_rupees: number;
  pct: number;
};
type DigestRow = {
  trend_dir: string;
  contracts: number;
  deferred_balance_rupees: number;
  monthly_recognition_rupees: number;
  avg_months_remaining: number;
  avg_recognition_pct: number;
};
type RiskRow = {
  contract_code: string;
  customer_segment: string;
  contract_type: string;
  recognition_status: string;
  contract_value_rupees: number;
  recognized_to_date_rupees: number;
  deferred_balance_rupees: number;
  months_remaining: number | null;
  recognition_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    segRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3493_recognition_status_rollup'),
    supabase.rpc('founder_r3493_customer_segment_scorecard'),
    supabase.rpc('founder_r3493_segment_status_matrix'),
    supabase.rpc('founder_r3493_monthly_recognition_trend'),
    supabase.rpc('founder_r3493_capa_status_board'),
    supabase.rpc('founder_r3493_root_cause_pareto'),
    supabase.rpc('founder_r3493_deferred_balance_impact_digest'),
    supabase.rpc('founder_r3493_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const segRows: SegRow[] = (segRes.data as SegRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'recognition_status', header: 'Recognition Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'deferred_balance_rupees', header: 'Deferred Balance (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const segCols: Column<SegRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'total_contract_value_rupees', header: 'Contract Value (INR)' },
    { key: 'recognized_to_date_rupees', header: 'Recognized (INR)' },
    { key: 'deferred_balance_rupees', header: 'Deferred Balance (INR)' },
    { key: 'avg_recognition_pct', header: 'Avg Recognition %' },
    { key: 'behind_or_stalled', header: 'Behind / Stalled' },
    { key: 'recognition_health_pct', header: 'Health %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'recognition_status', header: 'Recognition Status' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'deferred_balance_rupees', header: 'Deferred Balance (INR)' },
    { key: 'avg_recognition_pct', header: 'Avg Recognition %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'monthly_recognition_rupees', header: 'Monthly Recognition (INR)' },
    { key: 'recognized_to_date_rupees', header: 'Recognized (INR)' },
    { key: 'deferred_balance_rupees', header: 'Deferred Balance (INR)' },
    { key: 'avg_recognition_pct', header: 'Avg Recognition %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'trend_dir', header: 'Trend' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'deferred_balance_rupees', header: 'Deferred Balance (INR)' },
    { key: 'monthly_recognition_rupees', header: 'Monthly Recognition (INR)' },
    { key: 'avg_months_remaining', header: 'Avg Months Left' },
    { key: 'avg_recognition_pct', header: 'Avg Recognition %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'contract_code', header: 'Contract' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'contract_type', header: 'Type' },
    { key: 'recognition_status', header: 'Status' },
    { key: 'contract_value_rupees', header: 'Value (INR)' },
    { key: 'recognized_to_date_rupees', header: 'Recognized (INR)' },
    { key: 'deferred_balance_rupees', header: 'Deferred (INR)' },
    { key: 'months_remaining', header: 'Months Left' },
    { key: 'recognition_pct', header: 'Recognition %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Deferred-Revenue / AMC Unearned-Income Recognition-Waterfall Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder view of unearned AMC &amp; CMC revenue — contract &times; customer segment &times;
        contract value &times; recognized-to-date &times; deferred balance &times; monthly recognition
        &times; months remaining &times; recognition % &times; recognition status (on-schedule, ahead,
        behind, stalled, fully-recognized) &times; trend direction &amp; CAPA closure. Rollups cover the
        recognition waterfall, segment scorecards, root-cause pareto, and a deferred-balance impact
        digest to surface where unearned income is stuck or slipping.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recognition-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No contracts logged yet."
          rowKey={(r, i) => String(r.recognition_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={segRows}
          columns={segCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; recognition-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.customer_segment}-${r.recognition_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly recognition trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Deferred-balance impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk recognition queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk contracts."
          rowKey={(r, i) => `${r.contract_code}-${i}`}
        />
      </section>
    </main>
  );
}
