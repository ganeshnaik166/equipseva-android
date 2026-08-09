import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { attainment_status: string; reps: number; pct: number };
type RegionRow = {
  region: string;
  total_reps: number;
  over_achievers: number;
  on_quota: number;
  below_quota: number;
  at_risk: number;
  disputed: number;
  avg_attainment_pct: number;
  total_commission_paid_rupees: number;
  on_time_payout_pct: number;
};
type MatrixRow = {
  plan_class: string;
  attainment_status: string;
  reps: number;
  avg_attainment_pct: number;
  total_commission_earned_rupees: number;
};
type TrendRow = {
  period_month: string;
  reps: number;
  total_quota_rupees: number;
  total_attainment_rupees: number;
  avg_attainment_pct: number;
  total_commission_paid_rupees: number;
  late_payouts: number;
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
type DisputeRow = {
  region: string;
  reps: number;
  total_disputes_open: number;
  disputed_reps: number;
  total_clawbacks_rupees: number;
  avg_payout_accuracy_pct: number;
};
type RiskRow = {
  rep_code: string;
  rep_name: string;
  region: string;
  period_month: string;
  plan_class: string;
  attainment_status: string;
  attainment_pct: number | null;
  disputes_open: number;
  clawbacks_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    disputeRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3713_attainment_status_rollup'),
    supabase.rpc('founder_r3713_region_scorecard'),
    supabase.rpc('founder_r3713_plan_class_status_matrix'),
    supabase.rpc('founder_r3713_monthly_attainment_trend'),
    supabase.rpc('founder_r3713_capa_status_board'),
    supabase.rpc('founder_r3713_root_cause_pareto'),
    supabase.rpc('founder_r3713_dispute_clawback_digest'),
    supabase.rpc('founder_r3713_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const disputeRows: DisputeRow[] = (disputeRes.data as DisputeRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'attainment_status', header: 'Attainment Status' },
    { key: 'reps', header: 'Rep-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_reps', header: 'Rep-Months' },
    { key: 'over_achievers', header: 'Over-Achievers' },
    { key: 'on_quota', header: 'On Quota' },
    { key: 'below_quota', header: 'Below Quota' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
    { key: 'total_commission_paid_rupees', header: 'Commission Paid (INR)' },
    { key: 'on_time_payout_pct', header: 'On-Time Payout %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'plan_class', header: 'Plan Class' },
    { key: 'attainment_status', header: 'Attainment Status' },
    { key: 'reps', header: 'Rep-Months' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
    { key: 'total_commission_earned_rupees', header: 'Commission Earned (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'reps', header: 'Rep-Months' },
    { key: 'total_quota_rupees', header: 'Total Quota (INR)' },
    { key: 'total_attainment_rupees', header: 'Total Attainment (INR)' },
    { key: 'avg_attainment_pct', header: 'Avg Attainment %' },
    { key: 'total_commission_paid_rupees', header: 'Commission Paid (INR)' },
    { key: 'late_payouts', header: 'Late Payouts' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Payout Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const disputeCols: Column<DisputeRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'reps', header: 'Rep-Months' },
    { key: 'total_disputes_open', header: 'Disputes Open' },
    { key: 'disputed_reps', header: 'Disputed Reps' },
    { key: 'total_clawbacks_rupees', header: 'Clawbacks (INR)' },
    { key: 'avg_payout_accuracy_pct', header: 'Avg Payout Accuracy %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'rep_code', header: 'Rep Code' },
    { key: 'rep_name', header: 'Rep' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'plan_class', header: 'Plan Class' },
    { key: 'attainment_status', header: 'Status' },
    { key: 'attainment_pct', header: 'Attainment %' },
    { key: 'disputes_open', header: 'Disputes' },
    { key: 'clawbacks_rupees', header: 'Clawbacks (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Sales-Commission Plan / Attainment &amp; Payout Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Sales incentive-comp board — rep &times; region &times; period &times; quota vs attainment
        &times; commission earned/paid &times; payout accuracy &amp; timeliness &times; open
        disputes &times; accelerator triggers &times; clawbacks &amp; CAPA closure. Founder-gated
        view: attainment-status mix, region scorecards, plan-class matrix, monthly attainment
        trend, root-cause pareto, and the disputed / at-risk payout queue across Mumbai, Chennai,
        Delhi NCR, Bengaluru, Hyderabad &amp; Pune sales teams.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Attainment-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No commission records logged yet."
          rowKey={(r, i) => String(r.attainment_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region attainment scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Plan class &times; attainment-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No plan-class rollups."
          rowKey={(r, i) => `${r.plan_class}-${r.attainment_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly attainment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Dispute &amp; clawback digest</h2>
        <DataTable
          rows={disputeRows}
          columns={disputeCols}
          emptyMessage="No dispute/clawback rollups."
          rowKey={(r, i) => `${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk payout queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk payout rows."
          rowKey={(r, i) => `${r.rep_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
