import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { payout_status: string; campaigns: number; pct: number };
type EngineerRow = {
  engineer_name: string;
  campaigns: number;
  paid_on_time: number;
  paid_late: number;
  disputed: number;
  clawback_applied: number;
  avg_achievement_pct: number;
  total_spiff_amount_rupees: number;
  total_payout_amount_rupees: number;
};
type MatrixRow = {
  campaign_class: string;
  payout_status: string;
  campaigns: number;
  avg_achievement_pct: number;
  avg_spiff_amount_rupees: number;
};
type TrendRow = {
  period_month: string;
  campaigns: number;
  avg_achievement_pct: number;
  total_spiff_amount_rupees: number;
  on_time_payouts: number;
  worsening_campaigns: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  closed_count: number;
  overdue_count: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type RoiRow = {
  engineer_name: string;
  campaign_name: string;
  period_month: string;
  campaign_cost_rupees: number | null;
  incremental_revenue_rupees: number | null;
  roi_ratio: number | null;
  spiff_amount_rupees: number | null;
  payout_status: string;
  notes: string | null;
};
type RiskRow = {
  engineer_name: string;
  campaign_name: string;
  period_month: string;
  payout_status: string;
  achievement_pct: number | null;
  spiff_amount_rupees: number | null;
  payout_amount_rupees: number | null;
  campaign_cost_rupees: number | null;
  incremental_revenue_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    engineerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    roiRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3730_payout_status_rollup'),
    supabase.rpc('founder_r3730_engineer_scorecard'),
    supabase.rpc('founder_r3730_campaign_class_status_matrix'),
    supabase.rpc('founder_r3730_monthly_achievement_trend'),
    supabase.rpc('founder_r3730_capa_status_board'),
    supabase.rpc('founder_r3730_root_cause_pareto'),
    supabase.rpc('founder_r3730_campaign_roi_digest'),
    supabase.rpc('founder_r3730_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const engineerRows: EngineerRow[] = (engineerRes.data as EngineerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const roiRows: RoiRow[] = (roiRes.data as RoiRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'payout_status', header: 'Payout Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'pct', header: 'Share %' },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'paid_on_time', header: 'Paid On Time' },
    { key: 'paid_late', header: 'Paid Late' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'clawback_applied', header: 'Clawback Applied' },
    { key: 'avg_achievement_pct', header: 'Avg Achievement %' },
    { key: 'total_spiff_amount_rupees', header: 'Total SPIFF (INR)' },
    { key: 'total_payout_amount_rupees', header: 'Total Payout (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'campaign_class', header: 'Campaign Class' },
    { key: 'payout_status', header: 'Payout Status' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'avg_achievement_pct', header: 'Avg Achievement %' },
    { key: 'avg_spiff_amount_rupees', header: 'Avg SPIFF (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'campaigns', header: 'Campaigns' },
    { key: 'avg_achievement_pct', header: 'Avg Achievement %' },
    { key: 'total_spiff_amount_rupees', header: 'Total SPIFF (INR)' },
    { key: 'on_time_payouts', header: 'On-Time Payouts' },
    { key: 'worsening_campaigns', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'overdue_count', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const roiCols: Column<RoiRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'campaign_name', header: 'Campaign' },
    { key: 'period_month', header: 'Month' },
    { key: 'campaign_cost_rupees', header: 'Campaign Cost (INR)' },
    { key: 'incremental_revenue_rupees', header: 'Incremental Revenue (INR)' },
    { key: 'roi_ratio', header: 'ROI Ratio' },
    { key: 'spiff_amount_rupees', header: 'SPIFF Amount (INR)' },
    { key: 'payout_status', header: 'Payout Status' },
    { key: 'notes', header: 'Notes' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'campaign_name', header: 'Campaign' },
    { key: 'period_month', header: 'Month' },
    { key: 'payout_status', header: 'Payout Status' },
    { key: 'achievement_pct', header: 'Achievement %' },
    { key: 'spiff_amount_rupees', header: 'SPIFF Amount (INR)' },
    { key: 'payout_amount_rupees', header: 'Payout Amount (INR)' },
    { key: 'campaign_cost_rupees', header: 'Campaign Cost (INR)' },
    { key: 'incremental_revenue_rupees', header: 'Incremental Revenue (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer SPIFF / Incentive-Campaign Bonus Tracking Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer SPIFF/incentive-campaign bonus log &mdash; time-boxed campaigns (e.g. AMC-attach
        drive, spare-parts push, new-lead referral, upsell bundle, reactivation drive) &times; target
        vs achieved units &times; achievement % &times; SPIFF and payout amounts &times; payout
        timeliness &times; campaign cost vs incremental revenue &amp; CAPA closure. Distinct from any
        sales-commission-attainment-payout page, which tracks the STANDING sales-team commission plan,
        not engineer-side time-boxed campaigns. Founder-gated view: payout-status distribution, engineer
        scorecards, campaign-class matrix, monthly achievement trend, CAPA closure, root-cause pareto,
        a weak-campaign-ROI digest, and a high-risk queue of disputed &amp; clawback-applied payouts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Payout-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No SPIFF campaign rows logged yet."
          rowKey={(r, i) => String(r.payout_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer scorecard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Campaign class &times; payout status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No campaign-class rollups."
          rowKey={(r, i) => `${r.campaign_class}-${r.payout_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly achievement trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Weak campaign-ROI digest</h2>
        <DataTable
          rows={roiRows}
          columns={roiCols}
          emptyMessage="No weak-ROI campaigns."
          rowKey={(r, i) => `${r.engineer_name}-${r.campaign_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk payout queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk payouts."
          rowKey={(r, i) => `${r.engineer_name}-${r.campaign_name}-${i}`}
        />
      </section>
    </main>
  );
}
